// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title FuzzAdminNode
 * @notice Contains Admin/Owner functions (Category 2) for Node fuzzing
 * @dev All handler functions are currently commented out.
 *      These functions require owner privileges or special roles (onlyOwner, onlyRebalancer).
 *      Inherits from FuzzNode for access to base fuzzing infrastructure.
 */
import "../FuzzNode.sol";

import {INode} from "../../../src/interfaces/INode.sol";
import {Node} from "../../../src/Node.sol";
import {ERC7540Mock} from "../../mocks/ERC7540Mock.sol";
import {ERC4626Router} from "../../../src/routers/ERC4626Router.sol";
import {ERC7540Router} from "../../../src/routers/ERC7540Router.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7540Deposit, IERC7540Redeem} from "../../../src/interfaces/IERC7540.sol";
import {IERC7575} from "../../../src/interfaces/IERC7575.sol";

contract FuzzAdminNode is FuzzNode {
    function fuzz_admin_node_startRebalance(uint256 seed) public {
        NodeStartRebalanceParams memory params = nodeStartRebalancePreconditions(seed);

        _before();

        (bool success, bytes memory returnData) =
            fl.doFunctionCall(address(node), abi.encodeWithSelector(INode.startRebalance.selector), params.caller);

        nodeStartRebalancePostconditions(success, returnData, params);
    }

    function fuzz_admin_node_fulfillRedeem(uint256 controllerSeed) public {
        FulfillRedeemParams memory params = fulfillRedeemPreconditions(controllerSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(node),
            abi.encodeWithSelector(INode.fulfillRedeemFromReserve.selector, params.controller),
            params.caller
        );

        fulfillRedeemPostconditions(success, returnData, params);
    }

    function fuzz_admin_node_updateTotalAssets(uint256 seed) public {
        NodeUpdateTotalAssetsParams memory params = nodeUpdateTotalAssetsPreconditions(seed);

        _before();

        (bool success, bytes memory returnData) =
            fl.doFunctionCall(address(node), abi.encodeWithSelector(INode.updateTotalAssets.selector), params.caller);

        nodeUpdateTotalAssetsPostconditions(success, returnData, params);
    }

    function fuzz_admin_router4626_invest(uint256 componentSeed, uint256 minOutSeed) public {
        RouterInvestParams memory params = router4626InvestPreconditions(componentSeed, minOutSeed);

        params.sharesBefore = IERC20(params.component).balanceOf(address(node));
        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(ERC4626Router.invest.selector, address(node), params.component, params.minSharesOut),
            params.caller
        );

        router4626InvestPostconditions(success, returnData, params);
    }

    function fuzz_admin_router4626_liquidate(uint256 componentSeed, uint256 sharesSeed) public {
        RouterLiquidateParams memory params = router4626LiquidatePreconditions(componentSeed, sharesSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(
                ERC4626Router.liquidate.selector, address(node), params.component, params.shares, params.minAssetsOut
            ),
            params.caller
        );

        router4626LiquidatePostconditions(success, returnData, params);
    }

    function fuzz_admin_router4626_fulfillRedeem(uint256 controllerSeed, uint256 componentSeed) public {
        RouterFulfillParams memory params = router4626FulfillPreconditions(controllerSeed, componentSeed);

        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.escrowBalanceBefore = asset.balanceOf(address(escrow));

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(
                ERC4626Router.fulfillRedeemRequest.selector,
                address(node),
                params.controller,
                params.component,
                params.minAssetsOut
            ),
            params.caller
        );

        router4626FulfillPostconditions(success, returnData, params);
    }

    function fuzz_admin_router7540_invest(uint256 componentSeed) public {
        RouterAsyncInvestParams memory params = router7540InvestPreconditions(componentSeed);

        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(ERC7540Router.investInAsyncComponent.selector, address(node), params.component),
            params.caller
        );

        router7540InvestPostconditions(success, returnData, params);
    }

    function fuzz_admin_router7540_mintClaimable(uint256 componentSeed) public {
        RouterMintClaimableParams memory params = router7540MintClaimablePreconditions(componentSeed);

        params.claimableAssetsBefore = IERC7540Deposit(params.component).claimableDepositRequest(0, address(node));
        params.shareBalanceBefore = IERC20(params.component).balanceOf(address(node));

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(ERC7540Router.mintClaimableShares.selector, address(node), params.component),
            params.caller
        );

        router7540MintClaimablePostconditions(success, returnData, params);
    }

    function fuzz_admin_router7540_requestAsyncWithdrawal(uint256 componentSeed, uint256 sharesSeed) public {
        RouterRequestAsyncWithdrawalParams memory params =
            router7540RequestWithdrawalPreconditions(componentSeed, sharesSeed);

        params.shareBalanceBefore = IERC20(params.component).balanceOf(address(node));
        params.pendingRedeemBefore = IERC7540Redeem(params.component).pendingRedeemRequest(0, address(node));

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(
                ERC7540Router.requestAsyncWithdrawal.selector, address(node), params.component, params.shares
            ),
            params.caller
        );

        router7540RequestWithdrawalPostconditions(success, returnData, params);
    }

    function fuzz_admin_router7540_executeAsyncWithdrawal(uint256 componentSeed, uint256 assetsSeed) public {
        RouterExecuteAsyncWithdrawalParams memory params =
            router7540ExecuteWithdrawalPreconditions(componentSeed, assetsSeed);

        if (!params.shouldSucceed) {
            return;
        }

        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.claimableAssetsBefore = IERC7540Redeem(params.component).claimableRedeemRequest(0, address(node));
        params.maxWithdrawBefore = IERC7575(params.component).maxWithdraw(address(node));
        params.assets = params.maxWithdrawBefore;

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(
                ERC7540Router.executeAsyncWithdrawal.selector, address(node), params.component, params.assets
            ),
            params.caller
        );

        router7540ExecuteWithdrawalPostconditions(success, returnData, params);
    }

    function fuzz_admin_router7540_fulfillRedeemRequest(uint256 controllerSeed, uint256 componentSeed) public {
        RouterFulfillAsyncRedeemParams memory params =
            router7540FulfillRedeemPreconditions(controllerSeed, componentSeed);

        params.nodeAssetBalanceBefore = asset.balanceOf(address(node));
        params.escrowBalanceBefore = asset.balanceOf(address(escrow));
        params.componentSharesBefore = IERC20(params.component).balanceOf(address(node));

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(
                ERC7540Router.fulfillRedeemRequest.selector, address(node), params.controller, params.component
            ),
            params.caller
        );

        router7540FulfillRedeemPostconditions(success, returnData, params);
    }

    function fuzz_admin_pool_processPendingDeposits(uint256 poolSeed) public {
        PoolProcessParams memory params = poolProcessPendingDepositsPreconditions(poolSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            params.pool, abi.encodeWithSelector(ERC7540Mock.processPendingDeposits.selector), params.caller
        );

        poolProcessPendingDepositsPostconditions(success, returnData, params);
    }

    function fuzz_admin_pool_processPendingRedemptions(uint256 poolSeed) public {
        PoolProcessRedemptionsParams memory params = poolProcessPendingRedemptionsPreconditions(poolSeed);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            params.pool, abi.encodeWithSelector(ERC7540Mock.processPendingRedemptions.selector), params.caller
        );

        poolProcessPendingRedemptionsPostconditions(success, returnData, params);
    }
    // function fuzz_admin_node_setAnnualManagementFee(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeFeeParams memory params = nodeSetAnnualFeePreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.setAnnualManagementFee.selector, params.fee), currentActor
    //     );
    //
    //     nodeSetAnnualFeePostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_setMaxDepositSize(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeUintParams memory params = nodeSetMaxDepositPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.setMaxDepositSize.selector, params.value), currentActor
    //     );
    //
    //     nodeSetMaxDepositPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_setNodeOwnerFeeAddress(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeAddressParams memory params = nodeSetNodeOwnerFeeAddressPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.setNodeOwnerFeeAddress.selector, params.target), currentActor
    //     );
    //
    //     nodeSetNodeOwnerFeeAddressPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_setQuoter() public {
    //     // Actor selection handled in preconditions
    //     NodeAddressParams memory params = nodeSetQuoterPreconditions();
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.setQuoter.selector, params.target), currentActor
    //     );
    //
    //     nodeSetQuoterPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_setRebalanceCooldown(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeFeeParams memory params = nodeSetRebalanceCooldownPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.setRebalanceCooldown.selector, params.fee), currentActor
    //     );
    //
    //     nodeSetRebalanceCooldownPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_setRebalanceWindow(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeFeeParams memory params = nodeSetRebalanceWindowPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.setRebalanceWindow.selector, params.fee), currentActor
    //     );
    //
    //     nodeSetRebalanceWindowPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_setLiquidationQueue(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeQueueParams memory params = nodeSetLiquidationQueuePreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.setLiquidationQueue.selector, params.queue), currentActor
    //     );
    //
    //     nodeSetLiquidationQueuePostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_rescueTokens(uint256 amountSeed) public {
    //     // Actor selection handled in preconditions
    //     NodeRescueParams memory params = nodeRescueTokensPreconditions(amountSeed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node),
    //         abi.encodeWithSelector(INode.rescueTokens.selector, params.token, params.recipient, params.amount),
    //         currentActor
    //     );
    //
    //     nodeRescueTokensPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_addComponent(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeComponentAllocationParams memory params = nodeAddComponentPreconditions(seed);
    //
    //     uint64 targetWeight = uint64(params.targetWeight);
    //     uint64 maxDelta = uint64(params.maxDelta);
    //     params.targetWeight = targetWeight;
    //     params.maxDelta = maxDelta;
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node),
    //         abi.encodeWithSelector(INode.addComponent.selector, params.component, targetWeight, maxDelta, params.router),
    //         currentActor
    //     );
    //
    //     nodeAddComponentPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_removeComponent(uint256 seed, bool forceFlag) public {
    //     // Actor selection handled in preconditions
    //     NodeRemoveComponentParams memory params = nodeRemoveComponentPreconditions(seed, forceFlag);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node),
    //         abi.encodeWithSelector(INode.removeComponent.selector, params.component, params.force),
    //         currentActor
    //     );
    //
    //     nodeRemoveComponentPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_updateComponentAllocation(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeComponentAllocationParams memory params = nodeUpdateComponentAllocationPreconditions(seed);
    //
    //     uint64 targetWeight = uint64(params.targetWeight);
    //     uint64 maxDelta = uint64(params.maxDelta);
    //     params.targetWeight = targetWeight;
    //     params.maxDelta = maxDelta;
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node),
    //         abi.encodeWithSelector(
    //             INode.updateComponentAllocation.selector, params.component, targetWeight, maxDelta, params.router
    //         ),
    //         currentActor
    //     );
    //
    //     nodeUpdateComponentAllocationPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_updateTargetReserveRatio(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeTargetReserveParams memory params = nodeUpdateTargetReserveRatioPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.updateTargetReserveRatio.selector, params.target), currentActor
    //     );
    //
    //     nodeUpdateTargetReserveRatioPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_enableSwingPricing(uint256 seed, bool statusSeed) public {
    //     // Actor selection handled in preconditions
    //     NodeSwingPricingParams memory params = nodeEnableSwingPricingPreconditions(seed, statusSeed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node),
    //         abi.encodeWithSelector(INode.enableSwingPricing.selector, params.status, params.maxSwingFactor),
    //         currentActor
    //     );
    //
    //     nodeEnableSwingPricingPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_addPolicies(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodePoliciesParams memory params = nodeAddPoliciesPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node),
    //         abi.encodeWithSelector(
    //             INode.addPolicies.selector, params.proof, params.proofFlags, params.selectors, params.policies
    //         ),
    //         currentActor
    //     );
    //
    //     nodeAddPoliciesPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_removePolicies(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodePoliciesRemovalParams memory params = nodeRemovePoliciesPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node),
    //         abi.encodeWithSelector(INode.removePolicies.selector, params.selectors, params.policies),
    //         currentActor
    //     );
    //
    //     nodeRemovePoliciesPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_addRebalancer(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeAddressParams memory params = nodeAddRebalancerPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.addRebalancer.selector, params.target), currentActor
    //     );
    //
    //     nodeAddRebalancerPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_removeRebalancer(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeAddressParams memory params = nodeRemoveRebalancerPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.removeRebalancer.selector, params.target), currentActor
    //     );
    //
    //     nodeRemoveRebalancerPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_addRouter(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeAddressParams memory params = nodeAddRouterPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.addRouter.selector, params.target), currentActor
    //     );
    //
    //     nodeAddRouterPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_removeRouter(uint256 seed) public {
    //     // Actor selection handled in preconditions
    //     NodeAddressParams memory params = nodeRemoveRouterPreconditions(seed);
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(INode.removeRouter.selector, params.target), currentActor
    //     );
    //
    //     nodeRemoveRouterPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_renounceOwnership(uint256 seed) public {
    //     NodeOwnershipParams memory params = nodeRenounceOwnershipPreconditions(seed);
    //     // Actor selection handled in preconditions
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node), abi.encodeWithSelector(bytes4(keccak256("renounceOwnership()"))), currentActor
    //     );
    //
    //     nodeRenounceOwnershipPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_transferOwnership(uint256 seed) public {
    //     NodeOwnershipParams memory params = nodeTransferOwnershipPreconditions(seed);
    //     // Actor selection handled in preconditions
    //
    //     (bool success, bytes memory returnData) = fl.doFunctionCall(
    //         address(node),
    //         abi.encodeWithSelector(bytes4(keccak256("transferOwnership(address)")), params.newOwner),
    //         currentActor
    //     );
    //
    //     nodeTransferOwnershipPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_payManagementFees(uint256 seed) public {
    //     NodePayManagementFeesParams memory params = nodePayManagementFeesPreconditions(seed);
    //     // Actor selection handled in preconditions
    //
    //     address[] memory tracked = new address[](2);
    //     tracked[0] = node.nodeOwnerFeeAddress();
    //     tracked[1] = protocolFeesAddress;
    //     _before(tracked);
    //
    //     (bool success, bytes memory returnData) =
    //         fl.doFunctionCall(address(node), abi.encodeWithSelector(INode.payManagementFees.selector), currentActor);
    //
    //     _after(tracked);
    //     nodePayManagementFeesPostconditions(success, returnData, params);
    // }

    // function fuzz_admin_node_updateTotalAssets(uint256 seed) public {
    //     NodeUpdateTotalAssetsParams memory params = nodeUpdateTotalAssetsPreconditions(seed);
    //     // Actor selection handled in preconditions
    //
    //     _before();
    //
    //     (bool success, bytes memory returnData) =
    //         fl.doFunctionCall(address(node), abi.encodeWithSelector(INode.updateTotalAssets.selector), currentActor);
    //
    //     _after();
    //     nodeUpdateTotalAssetsPostconditions(success, returnData, params);
    // }

    /**
     * @notice Fuzz handler for OneInch router swap
     * @dev Exercises:
     *      - src/routers/OneInchV6RouterV1.sol:111 swap function
     *      - src/routers/OneInchV6RouterV1.sol:151 _subtractExecutionFee
     *      - Validates incentive/executor whitelisting
     *      - Tests swap with proper calldata encoding
     * @param seed Used to generate test parameters
     */
    function fuzz_admin_oneinch_swap(uint256 seed) public {
        OneInchSwapParams memory params = oneInchSwapPreconditions(seed);

        if (!params.shouldSucceed) {
            return;
        }

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(routerOneInch),
            abi.encodeWithSelector(
                routerOneInch.swap.selector,
                address(node),
                params.incentive,
                params.incentiveAmount,
                params.minAssetsOut,
                params.executor,
                params.swapCalldata
            ),
            params.caller
        );

        oneInchSwapPostconditions(success, returnData, params);
    }
}
