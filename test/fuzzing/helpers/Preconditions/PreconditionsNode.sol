// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {ERC20Mock} from "../../../mocks/ERC20Mock.sol";
import {ERC7540Mock} from "../../../mocks/ERC7540Mock.sol";
import {ERC7540StaticVault} from "../../../mocks/vaults/ERC7540StaticVault.sol";
import {ERC7540LinearYieldVault} from "../../../mocks/vaults/ERC7540LinearYieldVault.sol";
import {ERC7540NegativeYieldVault} from "../../../mocks/vaults/ERC7540NegativeYieldVault.sol";
import {Node} from "../../../../src/Node.sol";
import {RegistryType} from "../../../../src/interfaces/INodeRegistry.sol";
import {INode, ComponentAllocation} from "../../../../src/interfaces/INode.sol";
import {IRouter} from "../../../../src/interfaces/IRouter.sol";
import {ERC4626Router} from "../../../../src/routers/ERC4626Router.sol";
import {ERC7540Router} from "../../../../src/routers/ERC7540Router.sol";
import {ERC4626StaticVault} from "../../../mocks/vaults/ERC4626StaticVault.sol";
import {ERC4626LinearYieldVault} from "../../../mocks/vaults/ERC4626LinearYieldVault.sol";
import {ERC4626NegativeYieldVault} from "../../../mocks/vaults/ERC4626NegativeYieldVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC7540Deposit, IERC7540Redeem} from "../../../../src/interfaces/IERC7540.sol";
import {IERC7575} from "../../../../src/interfaces/IERC7575.sol";

contract PreconditionsNode is PreconditionsBase {
    function _prepareNodeContext(uint256 seed) internal {
        if (_managedNodeCount() == 0) {
            return;
        }

        if (testNodeOverrideEnabled) {
            _setActiveNodeByIndex(testNodeOverrideIndex);
            return;
        }

        uint256 randomSeed = uint256(keccak256(abi.encodePacked(seed, iteration, currentActor, block.timestamp)));
        _setRandomActiveNode(randomSeed);
    }

    function depositPreconditions(uint256 amountSeed) internal returns (DepositParams memory params) {
        _prepareNodeContext(amountSeed);

        params.receiver = currentActor;
        params.maxDeposit = node.maxDeposit(currentActor);

        uint256 userBalance = asset.balanceOf(currentActor);
        uint256 cap = _min(params.maxDeposit, userBalance);

        if (cap == 0) {
            params.assets = 0;
            params.shouldSucceed = false;
            return params;
        }

        // Allow 0 for edge case testing (will fail naturally)
        params.assets = fl.clamp(amountSeed, 0, cap);
        params.shouldSucceed = params.assets > 0;
    }

    function mintPreconditions(uint256 sharesSeed) internal returns (MintParams memory params) {
        _prepareNodeContext(sharesSeed);

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

        // Allow 0 for edge case testing
        params.shares = fl.clamp(sharesSeed, 0, cap);
        params.shouldSucceed = params.shares > 0;
    }

    function requestRedeemPreconditions(uint256 sharesSeed) internal returns (RequestRedeemParams memory params) {
        _prepareNodeContext(sharesSeed);

        params.controller = currentActor;
        params.owner = currentActor;

        uint256 shareBalance = node.balanceOf(currentActor);
        if (shareBalance == 0) {
            params.shares = 0;
            params.shouldSucceed = false;
            params.pendingBefore = 0;
            return params;
        }

        // Allow 0 for edge case testing
        params.shares = fl.clamp(sharesSeed, 0, shareBalance);
        params.shouldSucceed = params.shares > 0;
        (params.pendingBefore,,) = node.requests(currentActor);
    }

    function fulfillRedeemPreconditions(uint256 controllerSeed) internal returns (FulfillRedeemParams memory params) {
        _prepareNodeContext(controllerSeed);

        uint256 userCount = USERS.length;
        address controller = USERS[controllerSeed % userCount];

        // Use fuzzer-controlled amount instead of fixed 1e18
        uint256 desiredShares = node.balanceOf(controller) / 4 + 1;
        if (desiredShares == 0) desiredShares = 1;
        _ensurePendingRedeem(controller, desiredShares);
        _startRebalance();

        (uint256 pendingRedeem,,) = node.requests(controller);
        params.controller = controller;
        params.pendingBefore = pendingRedeem;

        bool authorizedCaller = _rand("NODE_FULFILL_CALLER", controllerSeed) % 19 != 0;
        params.caller = authorizedCaller ? rebalancer : randomUser;

        // Use seed to determine failure (varies from 0-100%)
        bool forceFailure = (controllerSeed % 10) == 0; // 10% failure rate instead of 20%
        if (forceFailure) {
            _drainNodeReserve();
        } else if (asset.balanceOf(address(node)) == 0) {
            // Derive amount from seed instead of fixed 50e18
            uint256 mintAmount = fl.clamp(controllerSeed, 1e18, 100e18);
            assetToken.mint(address(node), mintAmount);
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = !forceFailure && params.caller == rebalancer;
            return params;
        }

        params.shouldSucceed = !forceFailure && authorizedCaller;
    }

    function withdrawPreconditions(uint256 controllerSeed, uint256 assetsSeed)
        internal
        returns (WithdrawParams memory params)
    {
        _prepareNodeContext(controllerSeed);

        uint256 userCount = USERS.length;
        if (userCount == 0) {
            params.shouldSucceed = false;
            return params;
        }

        (bool found, address controllerCandidate, uint256 claimableShares, uint256 claimableAssets) =
            _findClaimableRedeemController(controllerSeed, true);

        if (!found) {
            address fallbackController = USERS[controllerSeed % userCount];
            params.controller = fallbackController;
            params.receiver = fallbackController;
            params.claimableAssetsBefore = 0;
            params.claimableSharesBefore = 0;
            params.assets = 0;
            params.shouldSucceed = false;
            return params;
        }

        params.controller = controllerCandidate;
        params.receiver = controllerCandidate;
        params.claimableAssetsBefore = claimableAssets;
        params.claimableSharesBefore = claimableShares;

        // Only proceed if we actually have claimable assets
        if (claimableAssets == 0) {
            params.assets = 0;
            params.shouldSucceed = false;
            return params;
        }

        // Let fuzzer explore full range of amounts (including edge cases)
        // Use wider distribution instead of fixed 90/10 split
        if (assetsSeed % 100 < 85) {
            // 85% within bounds
            // Happy path: withdraw within claimable range (allow 0)
            uint256 maxAssets = claimableAssets;
            params.assets = fl.clamp(assetsSeed, 0, maxAssets);
            params.shouldSucceed = params.assets > 0 && params.assets <= maxAssets;
        } else {
            // Error path: try to withdraw more than max
            params.assets = claimableAssets + 1;
            params.shouldSucceed = false;
        }
    }

    function setOperatorPreconditions(uint256 operatorSeed, bool approvalSeed)
        internal
        returns (SetOperatorParams memory params)
    {
        _prepareNodeContext(operatorSeed);

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
        _prepareNodeContext(spenderSeed);

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
        _prepareNodeContext(receiverSeed);

        address sender = currentActor;
        address receiver = USERS[receiverSeed % USERS.length];
        if (receiver == sender) {
            receiver = receiverSeed % 2 == 0 ? owner : randomUser;
        }
        if (receiver == sender) {
            receiver = protocolFeesAddress;
        }

        uint256 senderBalance = node.balanceOf(sender);

        if (senderBalance == 0 || receiver == address(0) || receiver == sender) {
            params.receiver = receiver;
            params.amount = 0;
            params.shouldSucceed = false;
            return params;
        }

        params.receiver = receiver;
        // Allow 0 for edge case testing
        params.amount = fl.clamp(amountSeed, 0, senderBalance);
        params.shouldSucceed = params.amount > 0 && receiver != address(0) && receiver != sender;
    }

    function nodeTransferFromPreconditions(uint256 ownerSeed, uint256 amountSeed)
        internal
        returns (NodeTransferFromParams memory params)
    {
        _prepareNodeContext(ownerSeed);

        address ownerCandidate = USERS[ownerSeed % USERS.length];

        // Ensure owner != currentActor to test transferFrom (not direct transfer)
        if (ownerCandidate == currentActor) {
            ownerCandidate = USERS[(ownerSeed + 1) % USERS.length];
        }

        uint256 ownerBalance = node.balanceOf(ownerCandidate);

        // Ensure owner has some balance (derive from seed)
        if (ownerBalance == 0) {
            uint256 depositAmount = fl.clamp(ownerSeed, 1e18, 20e18);
            _userDeposits(ownerCandidate, depositAmount);
            ownerBalance = node.balanceOf(ownerCandidate);
        }

        address receiver = USERS[(ownerSeed + 3) % USERS.length];
        if (receiver == ownerCandidate || receiver == currentActor) {
            receiver = owner;
        }

        // Explore 3 branches with fuzzer-controlled distribution
        // Use 100-based distribution for finer control
        uint256 branchSelector = amountSeed % 100;

        if (branchSelector < 75) {
            // 75% success path (was 70%)
            // Happy path: Ensure allowance exists and transfer within it
            uint256 currentAllowance = node.allowance(ownerCandidate, currentActor);
            if (currentAllowance == 0) {
                // Grant allowance from owner to currentActor
                vm.prank(ownerCandidate);
                node.approve(currentActor, type(uint256).max);
                currentAllowance = type(uint256).max;
            }

            uint256 maxTransferable = ownerBalance < currentAllowance ? ownerBalance : currentAllowance;
            params.owner = ownerCandidate;
            params.receiver = receiver;
            // Allow 0 for edge testing
            params.amount = fl.clamp(amountSeed, 0, maxTransferable);
            params.allowanceBefore = node.allowance(ownerCandidate, currentActor);
            params.shouldSucceed = params.amount > 0;
        } else if (branchSelector < 92) {
            // 17% exceed allowance (was 20%)
            // Error path: Has allowance but tries to exceed it
            uint256 currentAllowance = node.allowance(ownerCandidate, currentActor);
            if (currentAllowance == 0) {
                vm.prank(ownerCandidate);
                node.approve(currentActor, ownerBalance / 2);
                currentAllowance = ownerBalance / 2;
            }

            params.owner = ownerCandidate;
            params.receiver = receiver;
            params.amount = currentAllowance + 1; // Exceed allowance
            params.allowanceBefore = currentAllowance;
            params.shouldSucceed = false;
        } else {
            // 8% no allowance (was 10%)
            // Error path: No allowance/approval → InvalidOwner
            params.owner = ownerCandidate;
            params.receiver = receiver;
            params.amount = 1;
            params.allowanceBefore = 0; // Explicitly no allowance
            params.shouldSucceed = false;
        }
    }

    function nodeRedeemPreconditions(uint256 sharesSeed) internal returns (NodeRedeemParams memory params) {
        uint256 userCount = USERS.length;
        if (userCount == 0) {
            params.shouldSucceed = false;
            return params;
        }

        address controllerOverride;
        if (_hasPreferredAdminActor) {
            controllerOverride = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
        }

        if (controllerOverride != address(0)) {
            params.controller = controllerOverride;
            params.receiver = controllerOverride;
        } else {
            (bool found, address controller, uint256 claimableSharesExisting, uint256 claimableAssetsExisting) =
                _findClaimableRedeemController(sharesSeed, false);

            if (found) {
                params.controller = controller;
                params.receiver = controller;
                params.claimableSharesBefore = claimableSharesExisting;
                params.claimableAssetsBefore = claimableAssetsExisting;
            } else {
                address fallbackController = USERS[sharesSeed % userCount];
                params.controller = fallbackController;
                params.receiver = fallbackController;
            }
        }

        (params.claimableSharesBefore, params.claimableAssetsBefore) =
            _ensureClaimableRedeemState(params.controller, sharesSeed);

        if (params.claimableSharesBefore == 0) {
            params.shares = 0;
            params.shouldSucceed = false;
            return params;
        }

        if (sharesSeed % 100 < 85) {
            uint256 maxShares = params.claimableSharesBefore;
            params.shares = fl.clamp(sharesSeed, 1, maxShares);
            params.shouldSucceed = params.shares > 0 && params.shares <= maxShares;
        } else {
            params.shares = params.claimableSharesBefore + 1;
            params.shouldSucceed = false;
        }
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

    // NOTE: setQuoter has been removed in the remediation commit
    // function nodeSetQuoterPreconditions() internal view returns (NodeAddressParams memory params) {
    //     params.target = address(quoter);
    //     params.shouldSucceed = true;
    // }

    function nodeSetRebalanceCooldownPreconditions(uint256 seed) internal returns (NodeFeeParams memory params) {
        params.fee = uint64(fl.clamp(seed, 0, 7 days));
        params.shouldSucceed = true;
    }

    function nodeSetRebalanceWindowPreconditions(uint256 seed) internal returns (NodeFeeParams memory params) {
        params.fee = uint64(fl.clamp(seed, 1 hours, 30 days));
        params.shouldSucceed = true;
    }

    // NOTE: setLiquidationQueue has been removed in the remediation commit
    // function nodeSetLiquidationQueuePreconditions(uint256 seed) internal view returns (NodeQueueParams memory params) {
    //     ... removed ...
    // }

    function nodeRescueTokensPreconditions(uint256 amountSeed) internal returns (NodeRescueParams memory params) {
        ERC20Mock token = new ERC20Mock("RescueToken", "RSQ");
        // Expand mint range to explore wider amounts
        uint256 mintAmount = fl.clamp(amountSeed, 1e15, 10_000_000e18);
        token.mint(address(node), mintAmount);

        params.token = address(token);
        params.recipient = USERS[amountSeed % USERS.length];
        params.nodeBalanceBefore = token.balanceOf(address(node));
        params.recipientBalanceBefore = token.balanceOf(params.recipient);
        // Allow 0 for edge testing
        params.amount = fl.clamp(amountSeed % (params.nodeBalanceBefore + 1), 0, params.nodeBalanceBefore);
        params.shouldSucceed = params.amount > 0 && params.recipient != address(0);
    }

    function nodeAddComponentPreconditions(uint256 seed)
        internal
        returns (NodeComponentAllocationParams memory params)
    {
        _ensureNotRebalancing();

        // Expand ranges to explore wider allocation strategies
        uint256 weightMin = 0.01 ether; // Allow smaller weights (1%)
        uint256 weightMax = 0.5 ether; // Allow larger weights (50%)
        uint256 deltaMin = 0.0001 ether; // Allow smaller deltas (0.01%)
        uint256 deltaMax = 0.1 ether; // Allow larger deltas (10%)

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

        params.targetWeight = _clampValue(seed, weightMin, upperBound);
        params.maxDelta = _clampValue(seed >> 1, deltaMin, deltaMax);

        // Use percentage-based approach (20% failure instead of fixed modulo)
        bool attemptSuccess = (seed % 100) >= 20;

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

        uint256 selector = seed % 5;
        if (selector == 0) {
            ERC4626StaticVault newVault = new ERC4626StaticVault(address(asset), "Dynamic Static Vault", "dSV");
            params.component = address(newVault);
            params.router = address(router4626);

            vm.startPrank(owner);
            router4626.setWhitelistStatus(params.component, true);
            vm.stopPrank();
        } else if (selector == 1) {
            // Expand yield range: 0-10% APY instead of 3-4%
            uint256 yieldRate = seed % 1e17; // 0-10%
            ERC4626LinearYieldVault newVault =
                new ERC4626LinearYieldVault(address(asset), "Dynamic Linear Vault", "dLV", yieldRate);
            params.component = address(newVault);
            params.router = address(router4626);

            vm.startPrank(owner);
            router4626.setWhitelistStatus(params.component, true);
            vm.stopPrank();
        } else if (selector == 2) {
            // Expand negative yield range: 0-10% instead of 2-3%
            uint256 yieldRate = seed % 1e17; // 0-10%
            ERC4626NegativeYieldVault newVault =
                new ERC4626NegativeYieldVault(address(asset), "Dynamic Negative Vault", "dNV", yieldRate);
            params.component = address(newVault);
            params.router = address(router4626);

            vm.startPrank(owner);
            router4626.setWhitelistStatus(params.component, true);
            vm.stopPrank();
        } else if (selector == 3) {
            // Expand yield range: 0-10% APY instead of 2-3%
            uint256 yieldRate = seed % 1e17; // 0-10%
            ERC7540LinearYieldVault newPool = new ERC7540LinearYieldVault(
                IERC20(address(asset)), "Dynamic Async Vault", "dAV", poolManager, yieldRate
            );
            params.component = address(newPool);
            params.router = address(router7540);

            vm.startPrank(owner);
            router7540.setWhitelistStatus(params.component, true);
            vm.stopPrank();
        } else {
            // Expand negative yield range: 0-10% instead of 1-2%
            uint256 yieldRate = seed % 1e17; // 0-10%
            ERC7540NegativeYieldVault newPool = new ERC7540NegativeYieldVault(
                IERC20(address(asset)), "Dynamic Negative Async Vault", "dnAV", poolManager, yieldRate
            );
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

        // Expand ranges for update operations
        uint256 weightMin = 0.01 ether; // Allow 1%
        uint256 weightMax = 0.98 ether; // Allow up to 98%
        uint256 deltaMin = 0.0001 ether; // Allow 0.01%
        uint256 deltaMax = 0.15 ether; // Allow 15%

        params.targetWeight = _clampValue(seed, weightMin, weightMax);
        params.maxDelta = _clampValue(seed >> 1, deltaMin, deltaMax);

        // Use percentage-based approach (17% failure)
        bool attemptSuccess = (seed % 100) >= 17;
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
        // Use percentage-based approach (25% failure)
        bool attemptSuccess = (seed % 100) >= 25;

        _ensureNotRebalancing();

        if (attemptSuccess) {
            // Allow wider range: 0-99%
            params.target = uint64(_clampUint64(seed, 0, 0.99 ether));
            params.shouldSucceed = true;
        } else {
            params.target = uint64(1e18);
            params.shouldSucceed = false;
        }
    }

    // NOTE: enableSwingPricing has been removed in the remediation commit
    // function nodeEnableSwingPricingPreconditions(uint256 seed, bool statusSeed)
    //     internal
    //     view
    //     returns (NodeSwingPricingParams memory params)
    // {
    //     ... removed ...
    // }

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
        // Use percentage-based approach (33% failure)
        bool attemptSuccess = (seed % 100) >= 33;

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
        // Use percentage-based approach (20% failure)
        bool attemptSuccess = (seed % 100) >= 20;

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
        // Use percentage-based approach (20% failure)
        bool attemptSuccess = (seed % 100) >= 20;
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
        // Use percentage-based approach (11% use randomUser)
        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
        } else {
            params.caller = (seed % 100) < 11 ? randomUser : rebalancer;
        }

        if (params.caller != rebalancer) {
            params.shouldSucceed = false;
            params.lastRebalanceBefore = Node(address(node)).lastRebalance();
            return params;
        }

        params.lastRebalanceBefore = Node(address(node)).lastRebalance();
        uint256 window = uint256(Node(address(node)).rebalanceWindow());
        bool cooldownSatisfied = block.timestamp >= params.lastRebalanceBefore + window;
        bool ratiosValid = node.validateComponentRatios();
        bool cacheStale = !node.isCacheValid();
        params.shouldSucceed = cooldownSatisfied && ratiosValid && cacheStale;
        return params;
    }

    function nodePayManagementFeesPreconditions(uint256 seed)
        internal
        returns (NodePayManagementFeesParams memory params)
    {
        _ensureNotRebalancing();

        // Use percentage-based caller selection (20% randomUser, 40% owner, 40% rebalancer)
        uint256 callerSelector = seed % 100;
        params.caller = callerSelector < 20 ? randomUser : (callerSelector < 60 ? owner : rebalancer);
        params.shouldSucceed = params.caller == owner || params.caller == rebalancer;
        params.lastPaymentBefore = uint256(Node(address(node)).lastPayment());
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.nodeTotalAssetsBefore = node.totalAssets();
        params.protocolFeeBalanceBefore = asset.balanceOf(protocolFeesAddress);
        params.nodeOwnerBalanceBefore = asset.balanceOf(node.nodeOwnerFeeAddress());

        // Expand time warp range: 1-10 hours instead of 1-4
        vm.warp(block.timestamp + 1 hours + (seed % 10) * 1 hours);
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
        // Expand low balance threshold and top-up amount
        if (nodeBalance < 1e14) {
            // Lower threshold (0.0001 instead of 0.001)
            uint256 topUp = fl.clamp(seed, 1e17, 10e18); // Variable top-up
            assetToken.mint(address(node), topUp);
            nodeBalance = asset.balanceOf(address(node));
        }

        // Use percentage-based approach (17% failure)
        bool attemptSuccess = (seed % 100) >= 17 && ROUTERS.length > 0;

        if (attemptSuccess) {
            params.caller = ROUTERS[seed % ROUTERS.length];
            // Allow smaller fees, remove +1 offset
            params.fee = _clampValue(seed, 1e14, nodeBalance);
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
        // Use percentage-based approach (20% failure)
        bool attemptSuccess = ROUTERS.length > 0 && (seed % 100) >= 20;

        if (attemptSuccess) {
            _normalizeTargetReserveRatio();
            _ensureNotRebalancing();
            vm.startPrank(rebalancer);
            node.startRebalance();
            vm.stopPrank();

            params.caller = ROUTERS[seed % ROUTERS.length];
            params.target = address(asset);
            params.allowanceSpender = params.caller;
            // Expand allowance range, remove +1 offset
            params.allowance = _clampValue(seed, 1e14, 1e22);
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
        _prepareNodeContext(seed);

        params.caller = USERS[seed % USERS.length];
        bool attemptSuccess = seed % 4 != 0;

        if (attemptSuccess) {
            params.selector = _policySelectorPool(seed);
            params.policy = POLICIES.length > 0 ? POLICIES[seed % POLICIES.length] : address(0);

            bytes32[] memory proof = new bytes32[](1);
            proof[0] = keccak256(abi.encodePacked(seed, params.caller));
            params.data = abi.encode(proof);
            params.expectedProofLength = proof.length;
            params.proofHash = keccak256(abi.encode(proof));
            params.shouldSucceed = params.policy != address(0) && node.isSigPolicy(params.selector, params.policy);
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
        _prepareNodeContext(seed);

        // Use percentage-based approach (17% failure)
        bool attemptSuccess = ROUTERS.length > 0 && (seed % 100) >= 17;
        params.router = attemptSuccess ? ROUTERS[seed % ROUTERS.length] : randomUser;
        params.controller = USERS[(seed + 1) % USERS.length];

        if (!attemptSuccess || !node.isRouter(params.router)) {
            params.assetsToReturn = 1;
            params.sharesPending = 0;
            params.sharesAdjusted = 0;
            params.shouldSucceed = false;
            return params;
        }

        // Expand deposit range, remove +5 offset
        uint256 depositAssets = _clampValue(seed, 1e14, 1e22);

        assetToken.mint(params.controller, depositAssets);

        vm.startPrank(params.controller);
        asset.approve(address(node), type(uint256).max);
        node.deposit(depositAssets, params.controller);
        uint256 shares = node.convertToShares(depositAssets);
        node.requestRedeem(shares, params.controller, params.controller);
        vm.stopPrank();

        // NOTE: requests() now returns 3 values (pendingRedeemRequest, claimableRedeemRequest, claimableAssets)
        // sharesAdjusted was removed in remediation commit - using pendingRedeem instead
        (uint256 pendingRedeem,, uint256 claimableAssets) = node.requests(params.controller);
        uint256 assetsToReturn = node.convertToAssets(pendingRedeem);

        params.assetsToReturn = assetsToReturn;
        params.sharesPending = pendingRedeem;
        params.sharesAdjusted = pendingRedeem;
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.escrowBalanceBefore = asset.balanceOf(address(escrow));
        params.sharesExitingBefore = node.sharesExiting();
        params.shouldSucceed = pendingRedeem > 0 && assetsToReturn <= params.nodeAssetBalanceBefore;
        return params;
    }

    function nodeMulticallPreconditions(uint256 seed) internal returns (NodeMulticallParams memory params) {
        _prepareNodeContext(seed);

        params.caller = seed % 2 == 0 ? owner : randomUser;
        bool attemptSuccess = params.caller == owner && seed % 3 != 0;

        if (attemptSuccess) {
            params.calls = new bytes[](2);
            params.calls[0] = abi.encodeWithSelector(INode.payManagementFees.selector);
            params.calls[1] = abi.encodeWithSelector(INode.setRebalanceWindow.selector, uint64(6 hours));
            uint256 window = uint256(Node(address(node)).rebalanceWindow());
            uint256 last = uint256(Node(address(node)).lastRebalance());
            // Sanity check: skip if asset balance is corrupted (would cause overflow in fee calculation)
            uint256 nodeAssetBalance = asset.balanceOf(address(node));
            bool balanceSane = nodeAssetBalance < type(uint128).max;
            params.shouldSucceed = block.timestamp >= last + window && balanceSane;
        } else {
            params.calls = new bytes[](1);
            params.calls[0] = abi.encodeWithSelector(INode.startRebalance.selector);
            params.shouldSucceed = false;
        }
    }

    function nodeGainBackingPreconditions(uint256 componentSeed, uint256 amountSeed)
        internal
        returns (NodeYieldParams memory params)
    {
        return _nodeBackingAdjustmentPreconditions(componentSeed, amountSeed, true);
    }

    function nodeLoseBackingPreconditions(uint256 componentSeed, uint256 amountSeed)
        internal
        returns (NodeYieldParams memory params)
    {
        return _nodeBackingAdjustmentPreconditions(componentSeed, amountSeed, false);
    }

    function _nodeBackingAdjustmentPreconditions(uint256 componentSeed, uint256 amountSeed, bool increase)
        internal
        returns (NodeYieldParams memory params)
    {
        params.caller = componentSeed % 3 == 0 ? rebalancer : owner;
        if (componentSeed % 7 == 0) {
            params.caller = randomUser;
        }

        params.component = _selectYieldComponent(componentSeed);
        if (params.component == address(0)) {
            params.component = address(node);
        }

        params.backingToken = address(assetToken);
        params.currentBacking = asset.balanceOf(params.component);
        params.increase = increase;

        if (increase) {
            uint256 maxDelta = INITIAL_USER_BALANCE;
            params.delta = fl.clamp(amountSeed + 1, 1, maxDelta);
            params.shouldSucceed = true;
        } else {
            uint256 maxDelta = params.currentBacking;
            if (maxDelta == 0) {
                params.delta = 0;
                params.shouldSucceed = true;
                return params;
            }

            uint256 minDelta = maxDelta > 1 ? 1 : maxDelta;
            params.delta = fl.clamp(amountSeed + 1, minDelta, maxDelta);
            params.shouldSucceed = true;
        }
    }

    function _selectYieldComponent(uint256 seed) internal view returns (address component) {
        address[] memory syncComponents = _componentsByRouter(address(router4626));
        address[] memory asyncComponents = _componentsByRouter(address(router7540));

        uint256 total = syncComponents.length + asyncComponents.length;
        if (total == 0) {
            return address(0);
        }

        uint256 index = seed % total;
        if (index < syncComponents.length) {
            component = syncComponents[index];
        } else {
            component = asyncComponents[index - syncComponents.length];
        }
    }

    function router4626InvestPreconditions(uint256 componentSeed, uint256 minSharesSeed)
        internal
        returns (RouterInvestParams memory params)
    {
        _prepareNodeContext(uint256(keccak256(abi.encodePacked(componentSeed, minSharesSeed))));

        address[] memory syncComponents = _componentsByRouter(address(router4626));
        if (syncComponents.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = syncComponents[componentSeed % syncComponents.length];
        ComponentAllocation memory allocation = node.getComponentAllocation(params.component);

        uint256 totalAssets = node.totalAssets();
        uint256 currentComponentAssets =
            IERC4626(params.component).convertToAssets(IERC20(params.component).balanceOf(address(node)));
        uint256 targetHoldings = Math.mulDiv(totalAssets, allocation.targetWeight, 1e18);

        params.expectedDeposit = targetHoldings > currentComponentAssets ? targetHoldings - currentComponentAssets : 0;
        params.minSharesOut = 0;
        params.sharesBefore = IERC20(params.component).balanceOf(address(node));
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));

        uint256 idealCashReserve = Math.mulDiv(totalAssets, node.targetReserveRatio(), 1e18);
        uint256 currentCash = node.getCashAfterRedemptions();

        if (
            currentCash <= idealCashReserve || params.expectedDeposit == 0 || router4626.isBlacklisted(params.component)
        ) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        params.caller = rebalancer;
        if (_rand("R4626_INVEST_CALLER", componentSeed, minSharesSeed) % 23 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function router4626FulfillPreconditions(uint256 controllerSeed, uint256 componentSeed)
        internal
        returns (RouterFulfillParams memory params)
    {
        _prepareNodeContext(uint256(keccak256(abi.encodePacked(controllerSeed, componentSeed))));

        // NOTE: getLiquidationsQueue has been removed in remediation; use getComponents instead
        address[] memory components = node.getComponents();
        if (components.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.controller = USERS[controllerSeed % USERS.length];
        params.component = components[componentSeed % components.length];
        params.minAssetsOut = 0;

        (params.pendingBefore,,) = node.requests(params.controller);
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.escrowBalanceBefore = asset.balanceOf(address(escrow));

        if (params.pendingBefore == 0 || router4626.isBlacklisted(params.component)) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        params.caller = rebalancer;
        if (_rand("R4626_FULFILL_CALLER", controllerSeed, componentSeed) % 23 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function router4626LiquidatePreconditions(uint256 componentSeed, uint256 sharesSeed)
        internal
        returns (RouterLiquidateParams memory params)
    {
        _prepareNodeContext(uint256(keccak256(abi.encodePacked(componentSeed, sharesSeed))));

        address[] memory syncComponents = _componentsByRouter(address(router4626));
        if (syncComponents.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = syncComponents[componentSeed % syncComponents.length];

        _ensureRouter4626Position(params.component);

        params.sharesBefore = IERC20(params.component).balanceOf(address(node));
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));

        if (params.sharesBefore == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.shares = fl.clamp(sharesSeed + 1, 1, params.sharesBefore);
        params.minAssetsOut = 0;

        if (params.shares == 0 || router4626.isBlacklisted(params.component)) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        // Check if redeeming these shares would produce 0 assets (rounding to zero)
        uint256 expectedAssets = IERC4626(params.component).previewRedeem(params.shares);
        if (expectedAssets == 0) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        params.caller = rebalancer;
        if (_rand("R4626_LIQUIDATE_CALLER", componentSeed, sharesSeed) % 23 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function router7540InvestPreconditions(uint256 componentSeed)
        internal
        returns (RouterAsyncInvestParams memory params)
    {
        _prepareNodeContext(componentSeed);

        address[] memory pools = _componentsByRouter(address(router7540));
        if (pools.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = pools[componentSeed % pools.length];

        ComponentAllocation memory allocation = node.getComponentAllocation(params.component);
        uint256 totalAssets = node.totalAssets();
        uint256 componentBalance = IERC20(params.component).balanceOf(address(node));
        uint256 componentAssets = IERC7575(params.component).convertToAssets(componentBalance);
        uint256 targetHoldings = Math.mulDiv(totalAssets, allocation.targetWeight, 1e18);

        uint256 pendingAssets = IERC7540Deposit(params.component).pendingDepositRequest(0, address(node));

        params.pendingDepositBefore = pendingAssets;
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));

        uint256 idealCashReserve = Math.mulDiv(totalAssets, node.targetReserveRatio(), 1e18);
        uint256 currentCash = node.getCashAfterRedemptions();

        if (
            currentCash <= idealCashReserve || componentAssets >= targetHoldings
                || router7540.isBlacklisted(params.component)
        ) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        params.caller = rebalancer;
        if (_rand("R7540_INVEST_CALLER", componentSeed) % 29 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function router7540MintClaimablePreconditions(uint256 componentSeed)
        internal
        returns (RouterMintClaimableParams memory params)
    {
        _prepareNodeContext(componentSeed);

        address[] memory pools = _componentsByRouter(address(router7540));
        if (pools.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = pools[componentSeed % pools.length];
        params.claimableAssetsBefore = IERC7540Deposit(params.component).claimableDepositRequest(0, address(node));
        params.shareBalanceBefore = IERC20(params.component).balanceOf(address(node));

        if (params.claimableAssetsBefore == 0 || router7540.isBlacklisted(params.component)) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        params.caller = rebalancer;
        if (_rand("R7540_MINT_CALLER", componentSeed) % 29 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function router7540RequestWithdrawalPreconditions(uint256 componentSeed, uint256 sharesSeed)
        internal
        returns (RouterRequestAsyncWithdrawalParams memory params)
    {
        _prepareNodeContext(uint256(keccak256(abi.encodePacked(componentSeed, sharesSeed))));

        address[] memory pools = _componentsByRouter(address(router7540));
        if (pools.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = pools[componentSeed % pools.length];
        params.shareBalanceBefore = IERC20(params.component).balanceOf(address(node));
        params.pendingRedeemBefore = IERC7540Redeem(params.component).pendingRedeemRequest(0, address(node));

        if (params.shareBalanceBefore == 0) {
            params.shouldSucceed = false;
            return params;
        }

        // Check if component has a minimum redeem amount requirement
        uint256 minShares = 1;
        if (params.component == address(digiftAdapter)) {
            minShares = digiftAdapter.minRedeemAmount();
        }

        // Ensure we have enough balance to meet the minimum
        if (params.shareBalanceBefore < minShares) {
            params.shouldSucceed = false;
            return params;
        }

        params.shares = fl.clamp(sharesSeed + 1, minShares, params.shareBalanceBefore);

        if (params.shares == 0 || router7540.isBlacklisted(params.component)) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        params.caller = rebalancer;
        if (_rand("R7540_REQUEST_CALLER", componentSeed, sharesSeed) % 29 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function router7540ExecuteWithdrawalPreconditions(uint256 componentSeed, uint256 assetsSeed)
        internal
        returns (RouterExecuteAsyncWithdrawalParams memory params)
    {
        assetsSeed;
        _prepareNodeContext(uint256(keccak256(abi.encodePacked(componentSeed, assetsSeed))));

        address[] memory pools = _componentsByRouter(address(router7540));
        if (pools.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = pools[componentSeed % pools.length];
        params.claimableAssetsBefore = IERC7540Redeem(params.component).claimableRedeemRequest(0, address(node));
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));

        params.maxWithdrawBefore = IERC7575(params.component).maxWithdraw(address(node));

        if (params.maxWithdrawBefore == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.assets = params.maxWithdrawBefore;

        if (params.assets == 0 || router7540.isBlacklisted(params.component)) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        params.caller = rebalancer;
        if (_rand("R7540_EXECUTE_CALLER", componentSeed, assetsSeed) % 29 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function router7540FulfillRedeemPreconditions(uint256 controllerSeed, uint256 componentSeed)
        internal
        returns (RouterFulfillAsyncRedeemParams memory params)
    {
        _prepareNodeContext(uint256(keccak256(abi.encodePacked(controllerSeed, componentSeed))));

        address[] memory controllers = _getControllersWithPendingRedeems();
        if (controllers.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.controller = controllers[controllerSeed % controllers.length];

        address[] memory pools = _componentsByRouter(address(router7540));
        if (pools.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = pools[componentSeed % pools.length];

        (uint256 pendingRedeem,,) = node.requests(params.controller);
        uint256 componentClaimable = IERC7540Redeem(params.component).claimableRedeemRequest(0, address(node));

        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.escrowBalanceBefore = asset.balanceOf(address(escrow));
        params.componentSharesBefore = IERC20(params.component).balanceOf(address(node));

        if (
            pendingRedeem == 0 || componentClaimable == 0 || router7540.isBlacklisted(params.component)
                || params.componentSharesBefore == 0
        ) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        params.caller = rebalancer;
        if (_rand("R7540_FULFILL_CALLER", controllerSeed, componentSeed) % 29 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = true;
    }

    function poolProcessPendingDepositsPreconditions(uint256 poolSeed)
        internal
        returns (PoolProcessParams memory params)
    {
        _prepareNodeContext(poolSeed);

        address[] memory pools = _componentsByRouter(address(router7540));
        if (pools.length == 0) {
            params.pool = address(liquidityPool);
            params.shouldSucceed = false;
            return params;
        }

        params.pool = pools[poolSeed % pools.length];
        params.pendingBefore = ERC7540Mock(params.pool).pendingAssets();

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.pendingBefore > 0 && params.caller == poolManager;
            return params;
        }

        params.caller = poolManager;
        if (_rand("POOL_PROCESS_CALLER", poolSeed) % 23 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = params.pendingBefore > 0;
    }

    function routerSetBlacklistPreconditions(uint256 routerSeed, uint256 componentSeed, bool statusSeed)
        internal
        returns (RouterSingleStatusParams memory params)
    {
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(routerSeed, componentSeed)));
        _prepareNodeContext(combinedSeed);

        params.router = _selectBaseComponentRouter(routerSeed);
        params.caller = owner;

        address[] memory components = _componentsByRouter(params.router);
        if (components.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        params.component = components[componentSeed % components.length];
        params.status = statusSeed;
        params.shouldSucceed = true;

        if (_rand("ROUTER_BLACKLIST_CALLER", routerSeed, componentSeed) % 19 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        if (_rand("ROUTER_BLACKLIST_ZERO", routerSeed, componentSeed) % 23 == 0) {
            params.component = address(0);
            params.shouldSucceed = false;
            return params;
        }
    }

    function routerBatchWhitelistPreconditions(uint256 routerSeed, uint256 batchSeed)
        internal
        returns (RouterBatchWhitelistParams memory params)
    {
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(routerSeed, batchSeed)));
        _prepareNodeContext(combinedSeed);

        params.router = _selectBaseComponentRouter(routerSeed);
        params.caller = owner;

        address[] memory components = _componentsByRouter(params.router);
        if (components.length == 0) {
            params.shouldSucceed = false;
            return params;
        }

        uint256 count = 1 + (batchSeed % components.length);
        params.components = new address[](count);
        params.statuses = new bool[](count);
        for (uint256 i; i < count; ++i) {
            params.components[i] = components[(batchSeed + i) % components.length];
            params.statuses[i] = (_rand("ROUTER_WHITELIST_STATUS", batchSeed, i) & 1) == 1;
        }

        params.shouldSucceed = true;

        if (count > 1 && _rand("ROUTER_WHITELIST_LENGTH", routerSeed, batchSeed) % 23 == 0) {
            bool[] memory shorter = new bool[](count - 1);
            for (uint256 i; i < shorter.length; ++i) {
                shorter[i] = params.statuses[i];
            }
            params.statuses = shorter;
            params.shouldSucceed = false;
            return params;
        }

        if (_rand("ROUTER_WHITELIST_ZERO", routerSeed, batchSeed) % 29 == 0) {
            params.components[0] = address(0);
            params.shouldSucceed = false;
            return params;
        }

        if (_rand("ROUTER_WHITELIST_CALLER", routerSeed, batchSeed) % 31 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }
    }

    function routerTolerancePreconditions(uint256 routerSeed, uint256 toleranceSeed)
        internal
        returns (RouterToleranceParams memory params)
    {
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(routerSeed, toleranceSeed)));
        _prepareNodeContext(combinedSeed);

        params.router = _selectBaseComponentRouter(routerSeed);
        params.caller = owner;
        params.newTolerance = toleranceSeed % 1e18;
        params.shouldSucceed = true;

        if (_rand("ROUTER_TOLERANCE_CALLER", routerSeed, toleranceSeed) % 17 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }
    }

    function poolProcessPendingRedemptionsPreconditions(uint256 poolSeed)
        internal
        returns (PoolProcessRedemptionsParams memory params)
    {
        _prepareNodeContext(poolSeed);

        address[] memory pools = _componentsByRouter(address(router7540));
        if (pools.length == 0) {
            params.pool = address(liquidityPool);
            params.shouldSucceed = false;
            return params;
        }

        params.pool = pools[poolSeed % pools.length];
        params.pendingBefore = IERC7540Redeem(params.pool).pendingRedeemRequest(0, address(node));

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.pendingBefore > 0 && params.caller == poolManager;
            return params;
        }

        params.caller = poolManager;
        if (_rand("POOL_PROCESS_REDEEM_CALLER", poolSeed) % 23 == 0) {
            params.caller = randomUser;
            params.shouldSucceed = false;
            return params;
        }

        params.shouldSucceed = params.pendingBefore > 0;
    }

    function _selectBaseComponentRouter(uint256 seed) internal view returns (address router) {
        router = seed % 2 == 0 ? address(router4626) : address(router7540);
    }

    function _componentsByRouter(address targetRouter) internal view returns (address[] memory matches) {
        address[] memory nodeComponents = node.getComponents();
        uint256 count;
        for (uint256 i = 0; i < nodeComponents.length; i++) {
            address component = nodeComponents[i];
            ComponentAllocation memory allocation = node.getComponentAllocation(component);
            if (allocation.isComponent && allocation.router == targetRouter) {
                count++;
            }
        }

        matches = new address[](count);
        uint256 cursor;
        for (uint256 i = 0; i < nodeComponents.length; i++) {
            address component = nodeComponents[i];
            ComponentAllocation memory allocation = node.getComponentAllocation(component);
            if (allocation.isComponent && allocation.router == targetRouter) {
                matches[cursor] = component;
                cursor++;
            }
        }
    }

    function _getControllersWithPendingRedeems() internal view returns (address[] memory controllers) {
        uint256 count;
        for (uint256 i = 0; i < USERS.length; i++) {
            (uint256 pendingRedeem,, uint256 claimableAssets) = node.requests(USERS[i]);
            if (pendingRedeem > 0 || claimableAssets > 0) {
                count++;
            }
        }

        controllers = new address[](count);
        uint256 cursor;
        for (uint256 i = 0; i < USERS.length; i++) {
            (uint256 pendingRedeem,, uint256 claimableAssets) = node.requests(USERS[i]);
            if (pendingRedeem > 0 || claimableAssets > 0) {
                controllers[cursor] = USERS[i];
                cursor++;
            }
        }
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

        try IRouter(allocation.router).getComponentAssets(address(node), candidate, false) returns (uint256 assets) {
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

    function _findClaimableRedeemController(uint256 seed, bool requireAssets)
        internal
        view
        returns (bool found, address controller, uint256 claimableShares, uint256 claimableAssets)
    {
        uint256 userCount = USERS.length;
        if (userCount == 0) {
            return (false, address(0), 0, 0);
        }

        for (uint256 i = 0; i < userCount; i++) {
            address candidate = USERS[(seed + i) % userCount];
            (, uint256 foundClaimableShares, uint256 foundClaimableAssets) = node.requests(candidate);

            if (foundClaimableShares == 0) {
                continue;
            }

            if (requireAssets && foundClaimableAssets == 0) {
                continue;
            }

            return (true, candidate, foundClaimableShares, foundClaimableAssets);
        }

        return (false, address(0), 0, 0);
    }

    function _ensureClaimableRedeemState(address controller, uint256 seed)
        internal
        returns (uint256 claimableShares, uint256 claimableAssets)
    {
        (, uint256 existingClaimableShares, uint256 existingClaimableAssets) = node.requests(controller);
        if (existingClaimableShares > 0 && existingClaimableAssets > 0) {
            return (existingClaimableShares, existingClaimableAssets);
        }

        uint256 desiredShares = fl.clamp(seed, 1e16, 50e18);
        if (desiredShares == 0) {
            desiredShares = 1e16;
        }

        _ensurePendingRedeem(controller, desiredShares);

        uint256 assetsNeeded = node.convertToAssets(desiredShares);
        uint256 reserveBalance = asset.balanceOf(address(node));
        if (assetsNeeded > 0 && reserveBalance < assetsNeeded) {
            uint256 shortfall = assetsNeeded - reserveBalance;
            assetToken.mint(address(node), shortfall + 1e18);
        }

        _startRebalance();

        vm.startPrank(rebalancer);
        try node.fulfillRedeemFromReserve(controller) {} catch {}
        vm.stopPrank();

        (, claimableShares, claimableAssets) = node.requests(controller);
    }

    function _ensurePendingRedeem(address controller, uint256 shares) internal {
        (uint256 pending,,) = node.requests(controller);
        if (pending > 0) {
            return;
        }

        if (node.balanceOf(controller) < shares) {
            _userDeposits(controller, shares + 5e18);
        }

        vm.startPrank(controller);
        try node.requestRedeem(shares, controller, controller) {} catch {}
        vm.stopPrank();
    }

    function _startRebalance() internal {
        _openRebalanceWindow();
        vm.startPrank(rebalancer);
        try node.startRebalance() {} catch {}
        vm.stopPrank();
    }

    function _openRebalanceWindow() internal {
        uint256 window = uint256(Node(address(node)).rebalanceWindow());
        uint256 cooldown = uint256(Node(address(node)).rebalanceCooldown());
        uint256 last = uint256(Node(address(node)).lastRebalance());

        uint256 target = last + window + cooldown + 1;
        if (block.timestamp < target) {
            vm.warp(target);
        }
    }

    function _drainNodeReserve() internal {
        uint256 balance = asset.balanceOf(address(node));
        if (balance == 0) {
            return;
        }

        vm.startPrank(address(node));
        asset.transfer(owner, balance);
        vm.stopPrank();
    }

    function _ensureRouter4626Position(address component) internal {
        if (IERC20(component).balanceOf(address(node)) > 0) {
            return;
        }

        address depositor = USERS.length > 0 ? USERS[0] : owner;
        uint256 depositAmount = 1_000 ether;

        vm.startPrank(depositor);
        asset.approve(address(node), type(uint256).max);
        try node.deposit(depositAmount, depositor) {} catch {}
        vm.stopPrank();

        vm.startPrank(rebalancer);
        try router4626.invest(address(node), component, 0) {} catch {}
        vm.stopPrank();
    }

    /**
     * @notice Preconditions for OneInch swap operation
     * @dev Sets up:
     *      1. Whitelists incentive token and executor
     *      2. Mints incentive tokens to node
     *      3. Encodes expected return in swapCalldata
     *      4. Ensures minAssetsOut is reasonable
     */
    function oneInchSwapPreconditions(uint256 seed) internal returns (OneInchSwapParams memory params) {
        // Create or use existing incentive token
        // For simplicity, create a new mock token as "incentive"
        ERC20Mock incentiveToken = new ERC20Mock("Incentive Token", "INCENT");
        params.incentive = address(incentiveToken);

        // Select executor from USERS
        params.executor = USERS[seed % USERS.length];
        if (params.executor == address(node) || params.executor == address(0)) {
            params.executor = rebalancer;
        }

        // Whitelist incentive and executor
        vm.startPrank(owner);
        routerOneInch.setIncentiveWhitelistStatus(params.incentive, true);
        routerOneInch.setExecutorWhitelistStatus(params.executor, true);
        vm.stopPrank();

        // Expand incentive amount range
        params.incentiveAmount = fl.clamp(seed, 1e17, 10_000e18); // 0.1 to 10,000
        incentiveToken.mint(address(node), params.incentiveAmount);

        params.incentiveBalanceBefore = incentiveToken.balanceOf(address(node));
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));

        // Calculate expected return (simulate 1:1 swap with variable slippage)
        params.expectedReturn = params.incentiveAmount; // 1:1 for simplicity
        // Variable slippage: 0-15% based on seed
        uint256 slippagePercent = (seed % 16); // 0-15%
        params.minAssetsOut = (params.expectedReturn * (100 - slippagePercent)) / 100;

        // Encode expected return in swapCalldata (mock expects this format)
        params.swapCalldata = abi.encode(params.expectedReturn);

        // Skip if cacheTotalAssets is 0 (execution fee would underflow)
        if (node.totalAssets() == 0) {
            params.caller = rebalancer;
            params.shouldSucceed = false;
            return params;
        }

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("ONEINCH_CALLER", seed) % 17 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;
    }
}
