// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {ERC20Mock} from "../../../mocks/ERC20Mock.sol";
import {ERC7540Mock} from "../../../mocks/ERC7540Mock.sol";
import {Node} from "../../../../src/Node.sol";
import {RegistryType} from "../../../../src/interfaces/INodeRegistry.sol";
import {INode, ComponentAllocation} from "../../../../src/interfaces/INode.sol";
import {IRouter} from "../../../../src/interfaces/IRouter.sol";
import {ERC4626Router} from "../../../../src/routers/ERC4626Router.sol";
import {ERC7540Router} from "../../../../src/routers/ERC7540Router.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PreconditionsNode is PreconditionsBase {
    function depositPreconditions(uint256 amountSeed) internal returns (DepositParams memory params) {
        params.receiver = currentActor;
        params.maxDeposit = node.maxDeposit(currentActor);

        uint256 userBalance = asset.balanceOf(currentActor);
        uint256 cap = _min(params.maxDeposit, userBalance);

        if (cap == 0) {
            params.assets = 0;
            params.shouldSucceed = false;
            return params;
        }

        params.assets = fl.clamp(amountSeed, 1, cap);
        params.shouldSucceed = params.assets > 0;
    }

    function mintPreconditions(uint256 sharesSeed) internal returns (MintParams memory params) {
        params.receiver = currentActor;
        params.maxMint = node.maxMint(currentActor);

        uint256 userBalance = asset.balanceOf(currentActor);
        uint256 balanceLimitedShares = node.convertToShares(userBalance);
        uint256 cap = _min(params.maxMint, balanceLimitedShares);

        if (cap == 0) {
            params.shares = 0;
            params.shouldSucceed = false;
            return params;
        }

        params.shares = fl.clamp(sharesSeed, 1, cap);
        params.shouldSucceed = params.shares > 0;
    }

    function requestRedeemPreconditions(uint256 sharesSeed) internal returns (RequestRedeemParams memory params) {
        params.controller = currentActor;
        params.owner = currentActor;

        uint256 shareBalance = node.balanceOf(currentActor);
        if (shareBalance == 0) {
            params.shares = 0;
            params.shouldSucceed = false;
            params.pendingBefore = 0;
            return params;
        }

        params.shares = fl.clamp(sharesSeed, 1, shareBalance);
        params.shouldSucceed = params.shares > 0;
        (params.pendingBefore,,,) = node.requests(currentActor);
    }

    function fulfillRedeemPreconditions(uint256 controllerSeed) internal returns (FulfillRedeemParams memory params) {
        _ensureRebalancing();

        uint256 userCount = USERS.length;
        address controller = USERS[controllerSeed % userCount];

        (uint256 pendingRedeem,,,) = node.requests(controller);
        if (pendingRedeem == 0) {
            uint256 depositAssets = _clampValue(controllerSeed + 13, 1e15, 1e21);
            assetToken.mint(controller, depositAssets);

            vm.startPrank(controller);
            asset.approve(address(node), type(uint256).max);
            node.deposit(depositAssets, controller);
            uint256 shares = node.convertToShares(depositAssets);
            uint256 redeemShares = shares == 0 ? 0 : (shares / 2 == 0 ? shares : shares / 2);
            if (redeemShares == 0) {
                redeemShares = 1;
            }
            node.requestRedeem(redeemShares, controller, controller);
            vm.stopPrank();

            _ensureRebalancing();
            (pendingRedeem,,,) = node.requests(controller);
        }

        params.controller = controller;
        params.pendingBefore = pendingRedeem;
        params.shouldSucceed = pendingRedeem > 0;
    }

    function withdrawPreconditions(uint256 controllerSeed, uint256 assetsSeed)
        internal
        returns (WithdrawParams memory params)
    {
        uint256 userCount = USERS.length;
        address candidate;

        for (uint256 i = 0; i < userCount; i++) {
            candidate = USERS[(controllerSeed + i) % userCount];
            (
                ,
                uint256 claimableRedeemRequest,
                uint256 claimableAssets,
                /* sharesAdjusted */
            ) = node.requests(candidate);

            if (claimableAssets > 0) {
                params.controller = candidate;
                params.receiver = candidate;
                params.claimableAssetsBefore = claimableAssets;
                params.claimableSharesBefore = claimableRedeemRequest;
                params.assets = fl.clamp(assetsSeed, 1, claimableAssets);
                params.shouldSucceed = params.assets > 0;
                return params;
            }
        }

        params.controller = USERS[controllerSeed % userCount];
        params.receiver = params.controller;
        params.assets = 0;
        params.shouldSucceed = false;
        params.claimableAssetsBefore = 0;
        params.claimableSharesBefore = 0;
    }

    function setOperatorPreconditions(uint256 operatorSeed, bool approvalSeed)
        internal
        returns (SetOperatorParams memory params)
    {
        params.controller = currentActor;
        if (USERS.length == 0) {
            params.operator = address(0);
            params.shouldSucceed = false;
            params.approved = approvalSeed;
            return params;
        }

        params.operator = USERS[operatorSeed % USERS.length];
        if (params.operator == params.controller) {
            params.shouldSucceed = false;
            params.approved = approvalSeed;
            return params;
        }

        params.approved = approvalSeed;
        params.shouldSucceed = true;
    }

    function nodeApprovePreconditions(uint256 spenderSeed, uint256 amountSeed)
        internal
        returns (NodeApproveParams memory params)
    {
        address spender = USERS[spenderSeed % USERS.length];
        if (spender == currentActor) {
            spender = spenderSeed % 2 == 0 ? owner : randomUser;
        }
        if (spender == address(0)) {
            spender = owner;
        }

        params.spender = spender;
        params.amount = fl.clamp(amountSeed, 0, 1e36);
        params.allowanceBefore = node.allowance(currentActor, spender);
        params.shouldSucceed = spender != address(0);
    }

    function nodeTransferPreconditions(uint256 receiverSeed, uint256 amountSeed)
        internal
        returns (NodeTransferParams memory params)
    {
        address sender = currentActor;
        address receiver = USERS[receiverSeed % USERS.length];
        if (receiver == sender) {
            receiver = receiverSeed % 2 == 0 ? owner : randomUser;
        }
        if (receiver == sender) {
            receiver = protocolFeesAddress;
        }

        _ensureNodeShares(sender, 5e16);
        uint256 senderBalance = node.balanceOf(sender);

        if (senderBalance == 0 || receiver == address(0) || receiver == sender) {
            params.receiver = receiver;
            params.amount = 0;
            params.shouldSucceed = false;
            return params;
        }

        params.receiver = receiver;
        params.amount = fl.clamp(amountSeed + 1, 1, senderBalance);
        params.shouldSucceed = params.amount > 0 && receiver != address(0) && receiver != sender;
    }

    function nodeTransferFromPreconditions(uint256 ownerSeed, uint256 amountSeed)
        internal
        returns (NodeTransferFromParams memory params)
    {
        bool attemptSuccess = ownerSeed % 5 != 0;
        address ownerCandidate = USERS[ownerSeed % USERS.length];
        if (!attemptSuccess) {
            params.owner = ownerCandidate;
            params.receiver = address(0);
            params.amount = 0;
            params.allowanceBefore = node.allowance(ownerCandidate, currentActor);
            params.shouldSucceed = false;
            return params;
        }

        if (ownerCandidate == currentActor) {
            ownerCandidate = USERS[(ownerSeed + 1) % USERS.length];
        }

        _ensureNodeShares(ownerCandidate, 1e17);

        uint256 ownerBalance = node.balanceOf(ownerCandidate);
        if (ownerBalance == 0) {
            params.owner = ownerCandidate;
            params.receiver = USERS[(ownerSeed + 2) % USERS.length];
            params.amount = 0;
            params.allowanceBefore = node.allowance(ownerCandidate, currentActor);
            params.shouldSucceed = false;
            return params;
        }

        address receiver = USERS[(ownerSeed + 3) % USERS.length];
        if (receiver == ownerCandidate) {
            receiver = owner;
        }
        if (receiver == currentActor) {
            receiver = protocolFeesAddress;
        }

        uint256 amount = fl.clamp(amountSeed + 1, 1, ownerBalance);

        vm.startPrank(ownerCandidate);
        node.approve(currentActor, amount);
        vm.stopPrank();

        params.owner = ownerCandidate;
        params.receiver = receiver;
        params.amount = amount;
        params.allowanceBefore = node.allowance(ownerCandidate, currentActor);
        params.shouldSucceed = receiver != address(0) && receiver != ownerCandidate;
    }

    function nodeRedeemPreconditions(uint256 sharesSeed) internal returns (NodeRedeemParams memory params) {
        address controller = USERS[sharesSeed % USERS.length];
        params.controller = controller;
        params.receiver = controller;

        _ensureClaimableRedeem(controller);

        uint256 claimableShares;
        uint256 claimableAssets;
        {
            (, uint256 _claimableShares, uint256 _claimableAssets,) = node.requests(controller);
            claimableShares = _claimableShares;
            claimableAssets = _claimableAssets;
        }
        if (claimableShares == 0) {
            params.shares = 0;
            params.claimableAssetsBefore = claimableAssets;
            params.claimableSharesBefore = claimableShares;
            params.shouldSucceed = false;
            return params;
        }

        params.claimableAssetsBefore = claimableAssets;
        params.claimableSharesBefore = claimableShares;
        params.shares = fl.clamp(sharesSeed + 1, 1, claimableShares);
        params.shouldSucceed = params.shares > 0;
    }

    function nodeRenounceOwnershipPreconditions(uint256 seed)
        internal
        view
        returns (NodeOwnershipParams memory params)
    {
        params.caller = seed % 2 == 0 ? randomUser : USERS[seed % USERS.length];
        params.newOwner = address(0);
        params.shouldSucceed = false;
    }

    function nodeTransferOwnershipPreconditions(uint256 seed)
        internal
        view
        returns (NodeOwnershipParams memory params)
    {
        params.caller = seed % 2 == 0 ? randomUser : owner;
        if (params.caller == owner) {
            params.newOwner = address(0);
        } else {
            params.newOwner = USERS[(seed + 1) % USERS.length];
        }
        params.shouldSucceed = false;
    }

    function nodeInitializePreconditions(uint256 seed) internal returns (NodeInitializeParams memory params) {
        params.initArgs = NodeInitArgs({
            name: string(abi.encodePacked("Init-", seed)),
            symbol: "INIT",
            asset: address(asset),
            owner: owner
        });
        params.escrow = address(escrow);
        params.shouldSucceed = false;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function nodeSetAnnualFeePreconditions(uint256 seed) internal returns (NodeFeeParams memory params) {
        params.fee = uint64(fl.clamp(seed, 0, 1e18 - 1));
        params.shouldSucceed = true;
    }

    function nodeSetMaxDepositPreconditions(uint256 seed) internal returns (NodeUintParams memory params) {
        params.value = fl.clamp(seed, 0, 1e36);
        params.shouldSucceed = true;
    }

    function nodeSetNodeOwnerFeeAddressPreconditions(uint256 seed) internal returns (NodeAddressParams memory params) {
        address current = node.nodeOwnerFeeAddress();
        address candidate = address(uint160(uint256(keccak256(abi.encodePacked(seed, "NODE_FEE_ADDR")))));

        if (candidate == address(0) || candidate == current) {
            candidate = USERS[seed % USERS.length];
        }
        if (candidate == current || candidate == address(0)) {
            candidate = protocolFeesAddress;
        }
        if (candidate == current || candidate == address(0)) {
            candidate = randomUser;
        }

        params.target = candidate;
        params.shouldSucceed = params.target != address(0) && params.target != current;
    }

    function nodeSetQuoterPreconditions() internal view returns (NodeAddressParams memory params) {
        params.target = address(quoter);
        params.shouldSucceed = true;
    }

    function nodeSetRebalanceCooldownPreconditions(uint256 seed) internal returns (NodeFeeParams memory params) {
        params.fee = uint64(fl.clamp(seed, 0, 7 days));
        params.shouldSucceed = true;
    }

    function nodeSetRebalanceWindowPreconditions(uint256 seed) internal returns (NodeFeeParams memory params) {
        params.fee = uint64(fl.clamp(seed, 1 hours, 30 days));
        params.shouldSucceed = true;
    }

    function nodeSetLiquidationQueuePreconditions(uint256 seed) internal view returns (NodeQueueParams memory params) {
        address[] memory existingComponents = node.getComponents();
        uint256 len = existingComponents.length;
        if (len == 0) {
            params.shouldSucceed = false;
            params.queue = new address[](0);
            return params;
        }

        uint256 validCount;
        for (uint256 i = 0; i < len; i++) {
            ComponentAllocation memory allocation = node.getComponentAllocation(existingComponents[i]);
            if (allocation.isComponent) {
                validCount++;
            }
        }

        if (validCount == 0) {
            params.shouldSucceed = false;
            params.queue = new address[](0);
            return params;
        }

        address[] memory validComponents = new address[](validCount);
        uint256 cursor;
        for (uint256 i = 0; i < len; i++) {
            ComponentAllocation memory allocation = node.getComponentAllocation(existingComponents[i]);
            if (allocation.isComponent) {
                validComponents[cursor] = existingComponents[i];
                cursor++;
            }
        }

        bool attemptSuccess = seed % 5 != 0;
        if (!attemptSuccess) {
            params.queue = new address[](1);
            params.queue[0] = address(0);
            params.shouldSucceed = false;
            return params;
        }

        uint256 queueLen = 1 + (seed % validCount);
        params.queue = new address[](queueLen);

        uint256 start = seed % validCount;
        for (uint256 i = 0; i < queueLen; i++) {
            params.queue[i] = validComponents[(start + i) % validCount];
        }

        params.shouldSucceed = true;
    }

    function nodeRescueTokensPreconditions(uint256 amountSeed) internal returns (NodeRescueParams memory params) {
        ERC20Mock token = new ERC20Mock("RescueToken", "RSQ");
        uint256 mintAmount = fl.clamp(amountSeed + 1, 1e16, 1_000_000e18);
        token.mint(address(node), mintAmount);

        params.token = address(token);
        params.recipient = USERS[amountSeed % USERS.length];
        params.nodeBalanceBefore = token.balanceOf(address(node));
        params.recipientBalanceBefore = token.balanceOf(params.recipient);
        params.amount = fl.clamp((amountSeed % params.nodeBalanceBefore) + 1, 1, params.nodeBalanceBefore);
        params.shouldSucceed = params.amount > 0 && params.recipient != address(0);
    }

    function nodeAddComponentPreconditions(uint256 seed)
        internal
        returns (NodeComponentAllocationParams memory params)
    {
        _ensureNotRebalancing();

        uint256 weightMin = 0.05 ether;
        uint256 weightMax = 0.3 ether;
        uint256 deltaMin = 0.001 ether;
        uint256 deltaMax = 0.05 ether;

        uint256 reserveRatio = uint256(Node(address(node)).targetReserveRatio());
        if (reserveRatio <= weightMin) {
            params.component = address(0);
            params.router = address(0);
            params.shouldSucceed = false;
            return params;
        }

        uint256 upperBound = reserveRatio < weightMax ? reserveRatio : weightMax;
        if (upperBound < weightMin) {
            params.component = address(0);
            params.router = address(0);
            params.shouldSucceed = false;
            return params;
        }

        params.targetWeight = _clampValue(seed + 1, weightMin, upperBound);
        params.maxDelta = _clampValue((seed >> 1) + 1, deltaMin, deltaMax);

        bool attemptSuccess = seed % 5 != 0;

        if (!attemptSuccess) {
            if (COMPONENTS.length == 0) {
                params.component = address(0);
                params.router = address(0);
                params.shouldSucceed = false;
                return params;
            }

            params.component = COMPONENTS[seed % COMPONENTS.length];
            ComponentAllocation memory allocation = node.getComponentAllocation(params.component);
            params.router = allocation.router;
            params.shouldSucceed = false;
            return params;
        }

        if (seed % 2 == 0) {
            ERC4626Mock newVault = new ERC4626Mock(address(asset));
            params.component = address(newVault);
            params.router = address(router4626);

            vm.startPrank(owner);
            router4626.setWhitelistStatus(params.component, true);
            vm.stopPrank();
        } else {
            ERC7540Mock newPool = new ERC7540Mock(IERC20(address(asset)), "Dynamic Pool", "dPOOL", poolManager);
            params.component = address(newPool);
            params.router = address(router7540);

            vm.startPrank(owner);
            router7540.setWhitelistStatus(params.component, true);
            vm.stopPrank();
        }

        params.shouldSucceed = true;
    }

    function nodeRemoveComponentPreconditions(uint256 seed, bool forceFlag)
        internal
        returns (NodeRemoveComponentParams memory params)
    {
        _ensureNotRebalancing();

        address[] memory snapshot = node.getComponents();
        params.force = forceFlag;

        if (snapshot.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        // Prefer components we explicitly added (likely to have zero balances)
        uint256 removableLen = REMOVABLE_COMPONENTS.length;
        if (removableLen > 0) {
            for (uint256 i = 0; i < removableLen; i++) {
                address candidate = REMOVABLE_COMPONENTS[(seed + i) % removableLen];
                if (_prepareRemovalCandidate(candidate, forceFlag, params)) {
                    return params;
                }
            }
        }

        // Fallback to any registered component
        uint256 total = snapshot.length;
        for (uint256 i = 0; i < total; i++) {
            address candidate = snapshot[(seed + i) % total];
            if (_prepareRemovalCandidate(candidate, forceFlag, params)) {
                return params;
            }
        }

        params.component = address(uint160(uint256(keccak256(abi.encodePacked(seed, "NODE_REMOVE_COMPONENT")))));
        params.router = address(0);
        params.componentAssetsBefore = 0;
        params.routerBlacklistedBefore = false;
        params.shouldSucceed = false;
    }

    function nodeUpdateComponentAllocationPreconditions(uint256 seed)
        internal
        returns (NodeComponentAllocationParams memory params)
    {
        _ensureNotRebalancing();

        address[] memory components = node.getComponents();
        if (components.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = components[seed % components.length];
        ComponentAllocation memory allocation = node.getComponentAllocation(params.component);
        params.router = allocation.router;

        uint256 weightMin = 0.05 ether;
        uint256 weightMax = 0.95 ether;
        uint256 deltaMin = 0.001 ether;
        uint256 deltaMax = 0.08 ether;

        params.targetWeight = _clampValue(seed + 3, weightMin, weightMax);
        params.maxDelta = _clampValue((seed >> 1) + 3, deltaMin, deltaMax);

        bool attemptSuccess = seed % 6 != 0;
        if (!attemptSuccess) {
            params.router = address(0);
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function nodeUpdateTargetReserveRatioPreconditions(uint256 seed)
        internal
        returns (NodeTargetReserveParams memory params)
    {
        bool attemptSuccess = seed % 4 != 0;

        _ensureNotRebalancing();

        if (attemptSuccess) {
            params.target = uint64(_clampUint64(seed + 11, 0, 0.95 ether));
            params.shouldSucceed = true;
        } else {
            params.target = uint64(1e18);
            params.shouldSucceed = false;
        }
    }

    function nodeEnableSwingPricingPreconditions(uint256 seed, bool statusSeed)
        internal
        view
        returns (NodeSwingPricingParams memory params)
    {
        uint64 maxAllowed = registry.protocolMaxSwingFactor();
        uint64 minAllowed = maxAllowed / 10;
        if (minAllowed == 0) {
            minAllowed = 1;
        }

        params.status = statusSeed;

        bool attemptSuccess = seed % 5 != 0;
        if (attemptSuccess) {
            params.maxSwingFactor = uint64(_clampUint64(seed + 9, minAllowed, maxAllowed));
            params.shouldSucceed = true;
        } else {
            params.maxSwingFactor = maxAllowed + 1;
            params.shouldSucceed = false;
        }
    }

    function nodeAddPoliciesPreconditions(uint256 seed) internal returns (NodePoliciesParams memory params) {
        params.selectors = new bytes4[](1);
        params.policies = new address[](1);
        params.proof = new bytes32[](0);
        params.proofFlags = new bool[](0);

        (bytes4 selector, address policy) = _selectPolicyBinding(seed);
        params.selectors[0] = selector;
        params.policies[0] = policy;

        bytes32 leaf = _policyLeaf(selector, policy);
        bool alreadyRegistered = node.isSigPolicy(selector, policy);
        bool attemptSuccess = seed % 3 != 0;

        if (attemptSuccess && !alreadyRegistered) {
            vm.startPrank(owner);
            registry.setPoliciesRoot(leaf);
            vm.stopPrank();
            params.shouldSucceed = true;
        } else {
            vm.startPrank(owner);
            registry.setPoliciesRoot(bytes32(uint256(seed)));
            vm.stopPrank();
            params.shouldSucceed = false;
        }
    }

    function nodeRemovePoliciesPreconditions(uint256 seed) internal returns (NodePoliciesRemovalParams memory params) {
        params.selectors = new bytes4[](1);
        params.policies = new address[](1);

        uint256 len = REGISTERED_POLICY_SELECTORS.length;
        if (len == 0) {
            params.selectors[0] = _policySelectorPool(seed);
            params.policies[0] = POLICIES.length > 0 ? POLICIES[seed % POLICIES.length] : address(0);
            params.shouldSucceed = false;
            return params;
        }

        uint256 index = seed % len;
        bytes4 selector = REGISTERED_POLICY_SELECTORS[index];
        address policy = REGISTERED_POLICY_ADDRESSES[index];

        params.selectors[0] = selector;
        params.policies[0] = policy;
        params.shouldSucceed = node.isSigPolicy(selector, policy);

        if (!params.shouldSucceed) {
            params.selectors[0] = _policySelectorPool(seed + 1);
            params.policies[0] = POLICIES.length > 0 ? POLICIES[(seed + 1) % POLICIES.length] : address(0);
        }
    }

    function nodeAddRebalancerPreconditions(uint256 seed) internal returns (NodeAddressParams memory params) {
        bool attemptSuccess = seed % 5 != 0;

        if (!attemptSuccess) {
            params.target = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        address candidate = address(uint160(uint256(keccak256(abi.encodePacked(seed, address(this), "REBALANCER")))));
        uint256 guard;
        while ((candidate == address(0) || node.isRebalancer(candidate)) && guard < 6) {
            seed = uint256(keccak256(abi.encodePacked(seed, candidate, guard)));
            candidate = address(uint160(uint256(keccak256(abi.encodePacked(seed, "REBALANCER_ALT")))));
            guard++;
        }

        if (candidate == address(0) || node.isRebalancer(candidate)) {
            candidate = address(uint160(uint256(keccak256(abi.encodePacked(seed, iteration, block.number))))); // best effort
        }

        vm.startPrank(owner);
        registry.setRegistryType(candidate, RegistryType.REBALANCER, true);
        vm.stopPrank();

        params.target = candidate;
        params.shouldSucceed = !node.isRebalancer(candidate);
    }

    function nodeRemoveRebalancerPreconditions(uint256 seed) internal view returns (NodeAddressParams memory params) {
        for (uint256 i = 0; i < REBALANCERS.length; i++) {
            address candidate = REBALANCERS[i];
            if (candidate != address(0) && node.isRebalancer(candidate)) {
                params.target = candidate;
                params.shouldSucceed = true;
                return params;
            }
        }

        address fallbackCandidate = address(uint160(uint256(keccak256(abi.encodePacked(seed, "NO_REBALANCER")))));
        if (fallbackCandidate == address(0) || node.isRebalancer(fallbackCandidate)) {
            fallbackCandidate = randomUser;
        }
        params.target = fallbackCandidate;
        params.shouldSucceed = false;
    }

    function nodeAddRouterPreconditions(uint256 seed) internal returns (NodeAddressParams memory params) {
        bool attemptSuccess = seed % 5 != 0;
        if (!attemptSuccess) {
            address existing = ROUTERS[seed % ROUTERS.length];
            params.target = existing;
            params.shouldSucceed = false;
            return params;
        }

        address newRouter;
        if (seed % 2 == 0) {
            newRouter = address(new ERC4626Router(address(registry)));
        } else {
            newRouter = address(new ERC7540Router(address(registry)));
        }

        vm.startPrank(owner);
        registry.setRegistryType(newRouter, RegistryType.ROUTER, true);
        vm.stopPrank();

        params.target = newRouter;
        params.shouldSucceed = !node.isRouter(newRouter);
    }

    function nodeRemoveRouterPreconditions(uint256 seed) internal view returns (NodeAddressParams memory params) {
        for (uint256 i = 0; i < ROUTERS.length; i++) {
            address candidate = ROUTERS[i];
            if (candidate != address(0) && node.isRouter(candidate)) {
                params.target = candidate;
                params.shouldSucceed = true;
                return params;
            }
        }

        address fallbackCandidate =
            address(uint160(uint256(keccak256(abi.encodePacked(seed, address(this), "NO_ROUTER")))));
        if (fallbackCandidate == address(0) || node.isRouter(fallbackCandidate)) {
            fallbackCandidate = randomUser;
        }
        params.target = fallbackCandidate;
        params.shouldSucceed = false;
    }

    function _ensureNotRebalancing() internal {
        uint256 window = uint256(Node(address(node)).rebalanceWindow());
        uint256 last = uint256(Node(address(node)).lastRebalance());
        if (block.timestamp < last + window) {
            vm.warp(last + window + 1);
        }
    }

    function _ensureRebalancing() internal {
        uint256 window = uint256(Node(address(node)).rebalanceWindow());
        uint256 cooldown = uint256(Node(address(node)).rebalanceCooldown());
        uint256 last = uint256(Node(address(node)).lastRebalance());

        if (block.timestamp >= last + window) {
            uint256 earliest = last + window + cooldown + 1;
            if (block.timestamp < earliest) {
                vm.warp(earliest);
            }
            vm.startPrank(rebalancer);
            node.startRebalance();
            vm.stopPrank();
            last = uint256(Node(address(node)).lastRebalance());
        }

        uint256 targetTimestamp = last + window - 1;
        if (block.timestamp < targetTimestamp) {
            vm.warp(targetTimestamp);
        }
    }

    function nodeStartRebalancePreconditions(uint256 seed) internal returns (NodeStartRebalanceParams memory params) {
        params.caller = seed % 9 == 0 ? randomUser : rebalancer;

        if (params.caller != rebalancer) {
            params.shouldSucceed = false;
            params.lastRebalanceBefore = Node(address(node)).lastRebalance();
            return params;
        }

        _ensureNotRebalancing();

        if (seed % 7 == 0) {
            vm.startPrank(owner);
            node.updateTargetReserveRatio(0);
            vm.stopPrank();
            params.shouldSucceed = false;
            params.lastRebalanceBefore = Node(address(node)).lastRebalance();
            return params;
        }

        _normalizeTargetReserveRatio();

        params.lastRebalanceBefore = Node(address(node)).lastRebalance();
        params.shouldSucceed = node.validateComponentRatios() && !node.isCacheValid();
        return params;
    }

    function nodePayManagementFeesPreconditions(uint256 seed)
        internal
        returns (NodePayManagementFeesParams memory params)
    {
        _ensureNotRebalancing();

        params.caller = seed % 5 == 0 ? randomUser : (seed % 2 == 0 ? owner : rebalancer);
        params.shouldSucceed = params.caller == owner || params.caller == rebalancer;
        params.lastPaymentBefore = uint256(Node(address(node)).lastPayment());
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.nodeTotalAssetsBefore = node.totalAssets();
        params.protocolFeeBalanceBefore = asset.balanceOf(protocolFeesAddress);
        params.nodeOwnerBalanceBefore = asset.balanceOf(node.nodeOwnerFeeAddress());

        vm.warp(block.timestamp + 1 hours + (seed % 4) * 1 hours);
    }

    function nodeUpdateTotalAssetsPreconditions(uint256 seed)
        internal
        returns (NodeUpdateTotalAssetsParams memory params)
    {
        params.caller = seed % 5 == 0 ? randomUser : (seed % 2 == 0 ? owner : rebalancer);
        params.shouldSucceed = params.caller == owner || params.caller == rebalancer;
        params.nodeTotalAssetsBefore = node.totalAssets();
    }

    function nodeSubtractExecutionFeePreconditions(uint256 seed)
        internal
        returns (NodeSubtractExecutionFeeParams memory params)
    {
        uint256 nodeBalance = asset.balanceOf(address(node));
        if (nodeBalance < 1e15) {
            assetToken.mint(address(node), 1e18);
            nodeBalance = asset.balanceOf(address(node));
        }

        bool attemptSuccess = seed % 6 != 0 && ROUTERS.length > 0;

        if (attemptSuccess) {
            params.caller = ROUTERS[seed % ROUTERS.length];
            params.fee = _clampValue(seed + 1, 1e15, nodeBalance);
            if (node.isRouter(params.caller)) {
                vm.startPrank(owner);
                node.updateTotalAssets();
                vm.stopPrank();
                uint256 cacheAssets = node.totalAssets();
                params.shouldSucceed = params.fee <= nodeBalance && cacheAssets >= params.fee;
            } else {
                params.shouldSucceed = false;
            }
        } else {
            params.caller = randomUser;
            params.fee = nodeBalance + 1;
            params.shouldSucceed = false;
        }

        params.nodeBalanceBefore = asset.balanceOf(address(node));
        params.protocolFeeBalanceBefore = asset.balanceOf(protocolFeesAddress);
    }

    function nodeExecutePreconditions(uint256 seed) internal returns (NodeExecuteParams memory params) {
        bool attemptSuccess = ROUTERS.length > 0 && seed % 5 != 0;

        if (attemptSuccess) {
            _normalizeTargetReserveRatio();
            _ensureNotRebalancing();
            vm.startPrank(rebalancer);
            node.startRebalance();
            vm.stopPrank();

            params.caller = ROUTERS[seed % ROUTERS.length];
            params.target = address(asset);
            params.allowanceSpender = params.caller;
            params.allowance = _clampValue(seed + 1, 1e15, 1e21);
            params.data = abi.encodeWithSelector(IERC20.approve.selector, params.allowanceSpender, params.allowance);
            params.allowanceBefore = asset.allowance(address(node), params.allowanceSpender);
            params.shouldSucceed = node.isRouter(params.caller);
        } else {
            params.caller = randomUser;
            params.target = address(0);
            params.allowanceSpender = randomUser;
            params.allowance = 0;
            params.data = "";
            params.allowanceBefore = asset.allowance(address(node), randomUser);
            params.shouldSucceed = false;
        }
    }

    function nodeSubmitPolicyDataPreconditions(uint256 seed)
        internal
        returns (NodeSubmitPolicyDataParams memory params)
    {
        params.caller = USERS[seed % USERS.length];
        bool attemptSuccess = seed % 4 != 0;

        if (attemptSuccess) {
            params.selector = _policySelectorPool(seed);
            params.policy = address(gatePolicy);
            _ensurePolicyRegistered(params.selector, params.policy);

            bytes32[] memory proof = new bytes32[](1);
            proof[0] = keccak256(abi.encodePacked(seed, params.caller));
            params.data = abi.encode(proof);
            params.expectedProofLength = proof.length;
            params.proofHash = keccak256(abi.encode(proof));
            params.shouldSucceed = true;
        } else {
            params.selector = _policySelectorPool(seed + 1);
            params.policy = randomUser;
            bytes32[] memory proof = new bytes32[](0);
            params.data = abi.encode(proof);
            params.expectedProofLength = 0;
            params.proofHash = keccak256(abi.encode(proof));
            params.shouldSucceed = false;
        }
    }

    function nodeFinalizeRedemptionPreconditions(uint256 seed) internal returns (NodeFinalizeParams memory params) {
        bool attemptSuccess = ROUTERS.length > 0 && seed % 6 != 0;
        params.router = attemptSuccess ? ROUTERS[seed % ROUTERS.length] : randomUser;
        params.controller = USERS[(seed + 1) % USERS.length];

        if (!attemptSuccess || !node.isRouter(params.router)) {
            params.assetsToReturn = 1;
            params.sharesPending = 0;
            params.sharesAdjusted = 0;
            params.shouldSucceed = false;
            return params;
        }

        uint256 depositAssets = _clampValue(seed + 5, 1e15, 1e21);

        assetToken.mint(params.controller, depositAssets);

        vm.startPrank(params.controller);
        asset.approve(address(node), type(uint256).max);
        node.deposit(depositAssets, params.controller);
        uint256 shares = node.convertToShares(depositAssets);
        node.requestRedeem(shares, params.controller, params.controller);
        vm.stopPrank();

        (uint256 pendingRedeem,, uint256 claimableAssets, uint256 sharesAdjusted) = node.requests(params.controller);
        uint256 assetsToReturn = node.convertToAssets(sharesAdjusted);

        params.assetsToReturn = assetsToReturn;
        params.sharesPending = pendingRedeem;
        params.sharesAdjusted = sharesAdjusted;
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.escrowBalanceBefore = asset.balanceOf(address(escrow));
        params.sharesExitingBefore = node.sharesExiting();
        params.shouldSucceed = sharesAdjusted > 0 && assetsToReturn <= params.nodeAssetBalanceBefore;
        return params;
    }

    function nodeMulticallPreconditions(uint256 seed) internal returns (NodeMulticallParams memory params) {
        params.caller = seed % 2 == 0 ? owner : randomUser;
        bool attemptSuccess = params.caller == owner && seed % 3 != 0;

        if (attemptSuccess) {
            _ensureNotRebalancing();
            params.calls = new bytes[](2);
            params.calls[0] = abi.encodeWithSelector(INode.payManagementFees.selector);
            params.calls[1] = abi.encodeWithSelector(INode.setRebalanceWindow.selector, uint64(6 hours));
            params.shouldSucceed = true;
        } else {
            params.calls = new bytes[](1);
            params.calls[0] = abi.encodeWithSelector(INode.startRebalance.selector);
            params.shouldSucceed = false;
        }
    }

    function _ensureNodeShares(address account, uint256 minimumShares) internal {
        uint256 balance = node.balanceOf(account);
        if (balance >= minimumShares) {
            return;
        }

        _ensureNotRebalancing();

        if (!node.isCacheValid()) {
            vm.startPrank(rebalancer);
            node.startRebalance();
            vm.stopPrank();
        }

        uint256 maxDepositAmount = node.maxDeposit(account);
        if (maxDepositAmount < 1e15) {
            maxDepositAmount = 1_000_000e18;
        }

        uint256 assetsToDeposit = _clampValue(minimumShares + 1, 1e15, maxDepositAmount);

        assetToken.mint(account, assetsToDeposit);

        vm.startPrank(account);
        asset.approve(address(node), type(uint256).max);
        node.deposit(assetsToDeposit, account);
        vm.stopPrank();
    }

    function _ensureClaimableRedeem(address controller) internal {
        (, uint256 claimableShares,,) = node.requests(controller);
        if (claimableShares > 0) {
            return;
        }

        _ensureNodeShares(controller, 1e17);

        uint256 balanceBefore = node.balanceOf(controller);
        uint256 depositAssets = _clampValue(uint256(uint160(controller)) + block.number, 1e15, 1_000_000e18);

        assetToken.mint(controller, depositAssets);

        vm.startPrank(controller);
        asset.approve(address(node), type(uint256).max);
        node.deposit(depositAssets, controller);
        uint256 balanceAfter = node.balanceOf(controller);
        uint256 sharesMinted = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : depositAssets;
        if (sharesMinted == 0) {
            sharesMinted = depositAssets;
        }
        node.requestRedeem(sharesMinted, controller, controller);
        vm.stopPrank();

        _ensureRebalancing();

        vm.startPrank(rebalancer);
        node.fulfillRedeemFromReserve(controller);
        vm.stopPrank();

        _ensureNotRebalancing();
    }

    function _normalizeTargetReserveRatio() internal {
        address[] memory componentsList = node.getComponents();
        uint256 total = 0;
        uint256 length = componentsList.length;
        for (uint256 i = 0; i < length; i++) {
            ComponentAllocation memory allocation = node.getComponentAllocation(componentsList[i]);
            total += allocation.targetWeight;
        }

        uint256 reserveRatio = uint256(Node(address(node)).targetReserveRatio());
        total += reserveRatio;

        uint256 target = 1e18;
        if (total == target) {
            return;
        }

        uint256 newReserve;
        if (total > target) {
            uint256 excess = total - target;
            newReserve = reserveRatio > excess ? reserveRatio - excess : 0;
        } else {
            uint256 deficit = target - total;
            newReserve = reserveRatio + deficit;
            if (newReserve >= target) {
                newReserve = target - 1;
            }
        }

        vm.startPrank(owner);
        node.updateTargetReserveRatio(uint64(newReserve));
        vm.stopPrank();
    }

    function _prepareRemovalCandidate(address candidate, bool forceFlag, NodeRemoveComponentParams memory params)
        internal
        returns (bool success)
    {
        if (candidate == address(0) || !node.isComponent(candidate)) {
            return false;
        }

        ComponentAllocation memory allocation = node.getComponentAllocation(candidate);
        uint256 assetsBefore;
        bool routerBlacklisted;

        try IRouter(allocation.router).getComponentAssets(candidate, false) returns (uint256 assets) {
            assetsBefore = assets;
        } catch {
            assetsBefore = 0;
        }

        try IRouter(allocation.router).isBlacklisted(candidate) returns (bool status) {
            routerBlacklisted = status;
        } catch {
            routerBlacklisted = false;
        }

        if (!forceFlag && assetsBefore == 0) {
            params.component = candidate;
            params.router = allocation.router;
            params.componentAssetsBefore = assetsBefore;
            params.routerBlacklistedBefore = routerBlacklisted;
            params.shouldSucceed = true;
            return true;
        }

        if (forceFlag) {
            if (
                !routerBlacklisted
                    && (allocation.router == address(router4626) || allocation.router == address(router7540))
            ) {
                vm.startPrank(owner);
                if (allocation.router == address(router4626)) {
                    router4626.setBlacklistStatus(candidate, true);
                } else {
                    router7540.setBlacklistStatus(candidate, true);
                }
                vm.stopPrank();
                routerBlacklisted = true;
            }

            if (routerBlacklisted) {
                params.component = candidate;
                params.router = allocation.router;
                params.componentAssetsBefore = assetsBefore;
                params.routerBlacklistedBefore = routerBlacklisted;
                params.shouldSucceed = true;
                return true;
            }
        }

        return false;
    }

    function _recordPolicyBinding(bytes4 selector, address policy) internal {
        for (uint256 i = 0; i < REGISTERED_POLICY_SELECTORS.length; i++) {
            if (REGISTERED_POLICY_SELECTORS[i] == selector && REGISTERED_POLICY_ADDRESSES[i] == policy) {
                return;
            }
        }
        REGISTERED_POLICY_SELECTORS.push(selector);
        REGISTERED_POLICY_ADDRESSES.push(policy);
    }

    function _ensurePolicyRegistered(bytes4 selector, address policy) internal {
        if (policy == address(0)) {
            return;
        }

        if (!node.isSigPolicy(selector, policy)) {
            bytes32 leaf = _policyLeaf(selector, policy);
            vm.startPrank(owner);
            registry.setPoliciesRoot(leaf);
            bytes32[] memory proof = new bytes32[](0);
            bool[] memory proofFlags = new bool[](0);
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = selector;
            address[] memory policies = new address[](1);
            policies[0] = policy;
            node.addPolicies(proof, proofFlags, selectors, policies);
            vm.stopPrank();

            _recordPolicyBinding(selector, policy);
        }
    }

    function _selectPolicyBinding(uint256 seed) internal view returns (bytes4 selector, address policy) {
        selector = _policySelectorPool(seed);

        if (POLICIES.length == 0) {
            policy = address(0);
            return (selector, policy);
        }

        policy = POLICIES[seed % POLICIES.length];

        for (uint256 i = 0; i < POLICIES.length; i++) {
            address candidatePolicy = POLICIES[(seed + i) % POLICIES.length];
            if (!node.isSigPolicy(selector, candidatePolicy)) {
                policy = candidatePolicy;
                return (selector, policy);
            }
        }
    }

    function _policyLeaf(bytes4 selector, address policy) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(selector, policy))));
    }

    function _policySelectorPool(uint256 seed) internal pure returns (bytes4) {
        bytes4[6] memory selectors = [
            INode.addComponent.selector,
            INode.removeComponent.selector,
            INode.startRebalance.selector,
            INode.updateTotalAssets.selector,
            INode.payManagementFees.selector,
            INode.subtractProtocolExecutionFee.selector
        ];
        return selectors[seed % selectors.length];
    }

    function _clampUint64(uint256 seed, uint256 minValue, uint256 maxValue) internal pure returns (uint64) {
        uint256 clamped = _clampValue(seed, minValue, maxValue);
        if (clamped > type(uint64).max) {
            clamped = type(uint64).max;
        }
        return uint64(clamped);
    }

    function _clampValue(uint256 seed, uint256 minValue, uint256 maxValue) internal pure returns (uint256) {
        if (maxValue <= minValue) {
            return minValue;
        }
        uint256 range = maxValue - minValue;
        return minValue + (seed % (range + 1));
    }
}
