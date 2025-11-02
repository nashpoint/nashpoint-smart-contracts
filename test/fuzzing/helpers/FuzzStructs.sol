// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzSetup.sol";
import {DigiftAdapter} from "../../../src/adapters/digift/DigiftAdapter.sol";
import {IIncentraDistributor} from "../../../src/interfaces/external/IIncentraDistributor.sol";
import {DigiftEventVerifier} from "../../../src/adapters/digift/DigiftEventVerifier.sol";
import {RegistryType} from "../../../src/interfaces/INodeRegistry.sol";
import {NodeInitArgs} from "../../../src/interfaces/INode.sol";

/**
 * @title FuzzStructs
 * @notice Centralised repository for parameter and state structs used across the fuzzing suite
 */
contract FuzzStructs is FuzzSetup {
    // ==============================================================
    // STATE SNAPSHOT STRUCTS
    // ==============================================================

    struct State {
        mapping(address => ActorState) actorStates;
        uint256 nodeAssetBalance;
        uint256 nodeEscrowAssetBalance;
        uint256 nodeTotalAssets;
        uint256 nodeTotalSupply;
        uint256 sharesExiting;
    }

    struct ActorState {
        uint256 assetBalance;
        uint256 shareBalance;
        uint256 pendingRedeem;
        uint256 claimableRedeem;
        uint256 claimableAssets;
    }

    // ==============================================================
    // PARAMETER STRUCTS
    // ==============================================================

    struct DepositParams {
        address receiver;
        uint256 assets;
        uint256 maxDeposit;
        bool shouldSucceed;
    }

    struct MintParams {
        address receiver;
        uint256 shares;
        uint256 maxMint;
        bool shouldSucceed;
    }

    struct RequestRedeemParams {
        address controller;
        address owner;
        uint256 shares;
        bool shouldSucceed;
        uint256 pendingBefore;
    }

    struct FulfillRedeemParams {
        address controller;
        bool shouldSucceed;
        uint256 pendingBefore;
    }

    struct WithdrawParams {
        address controller;
        address receiver;
        uint256 assets;
        bool shouldSucceed;
        uint256 claimableAssetsBefore;
        uint256 claimableSharesBefore;
    }

    struct SetOperatorParams {
        address controller;
        address operator;
        bool approved;
        bool shouldSucceed;
    }

    struct RouterInvestParams {
        address component;
        uint256 minSharesOut;
        uint256 expectedDeposit;
        uint256 sharesBefore;
        uint256 nodeAssetBalanceBefore;
        bool shouldSucceed;
    }

    struct RouterLiquidateParams {
        address component;
        uint256 shares;
        uint256 minAssetsOut;
        uint256 sharesBefore;
        uint256 nodeAssetBalanceBefore;
        bool shouldSucceed;
    }

    struct RouterFulfillParams {
        address controller;
        address component;
        uint256 minAssetsOut;
        uint256 pendingBefore;
        uint256 escrowBalanceBefore;
        uint256 nodeAssetBalanceBefore;
        bool shouldSucceed;
    }

    struct RouterBatchWhitelistParams {
        address[] components;
        bool[] statuses;
        bool shouldSucceed;
    }

    struct RouterSingleStatusParams {
        address component;
        bool status;
        bool shouldSucceed;
    }

    struct RouterToleranceParams {
        uint256 newTolerance;
        bool shouldSucceed;
    }

    struct RouterAsyncInvestParams {
        address component;
        uint256 nodeAssetBalanceBefore;
        uint256 pendingDepositBefore;
        bool shouldSucceed;
    }

    struct RouterMintClaimableParams {
        address component;
        uint256 claimableAssetsBefore;
        uint256 shareBalanceBefore;
        bool shouldSucceed;
    }

    struct RouterRequestAsyncWithdrawalParams {
        address component;
        uint256 shares;
        uint256 shareBalanceBefore;
        uint256 pendingRedeemBefore;
        bool shouldSucceed;
    }

    struct RouterExecuteAsyncWithdrawalParams {
        address component;
        uint256 assets;
        uint256 nodeAssetBalanceBefore;
        uint256 claimableAssetsBefore;
        bool shouldSucceed;
    }

    struct FluidClaimParams {
        uint256 cumulativeAmount;
        bytes32 positionId;
        uint256 cycle;
        bytes32[] merkleProof;
        bytes32 proofHash;
        bool shouldSucceed;
    }

    struct IncentraClaimParams {
        address[] campaignAddrs;
        IIncentraDistributor.CampaignReward[] rewards;
        bytes32 campaignAddrsHash;
        bytes32 rewardsHash;
        bool shouldSucceed;
    }

    struct MerklClaimParams {
        address[] tokens;
        uint256[] amounts;
        bytes32[][] proofs;
        bytes32 usersHash;
        bytes32 tokensHash;
        bytes32 amountsHash;
        bytes32 proofsHash;
        bool shouldSucceed;
    }

    struct OneInchSwapParams {
        address incentive;
        uint256 incentiveAmount;
        uint256 minAssetsOut;
        address executor;
        bytes swapCalldata;
        bool shouldSucceed;
        uint256 nodeAssetBalanceBefore;
        uint256 incentiveBalanceBefore;
        uint256 expectedReturn;
    }

    struct OneInchStatusParams {
        address target;
        bool status;
        bool shouldSucceed;
    }

    struct NodeUintParams {
        uint256 value;
        bool shouldSucceed;
    }

    struct NodeFeeParams {
        uint64 fee;
        bool shouldSucceed;
    }

    struct NodeAddressParams {
        address target;
        bool shouldSucceed;
    }

    struct NodeComponentAllocationParams {
        address component;
        uint256 targetWeight;
        uint256 maxDelta;
        address router;
        bool shouldSucceed;
    }

    struct NodeRemoveComponentParams {
        address component;
        bool force;
        address router;
        uint256 componentAssetsBefore;
        bool routerBlacklistedBefore;
        bool shouldSucceed;
    }

    struct NodeRescueParams {
        address token;
        address recipient;
        uint256 amount;
        uint256 recipientBalanceBefore;
        uint256 nodeBalanceBefore;
        bool shouldSucceed;
    }

    struct NodeApproveParams {
        address spender;
        uint256 amount;
        uint256 allowanceBefore;
        bool shouldSucceed;
    }

    struct NodeTransferParams {
        address receiver;
        uint256 amount;
        bool shouldSucceed;
    }

    struct NodeTransferFromParams {
        address owner;
        address receiver;
        uint256 amount;
        uint256 allowanceBefore;
        bool shouldSucceed;
    }

    struct NodeRedeemParams {
        address controller;
        address receiver;
        uint256 shares;
        uint256 claimableAssetsBefore;
        uint256 claimableSharesBefore;
        bool shouldSucceed;
    }

    struct NodeOwnershipParams {
        address caller;
        address newOwner;
        bool shouldSucceed;
    }

    struct NodeFactoryDeployParams {
        NodeInitArgs initArgs;
        bytes[] payload;
        bytes32 salt;
        bool shouldSucceed;
    }

    struct NodeInitializeParams {
        NodeInitArgs initArgs;
        address escrow;
        bool shouldSucceed;
    }

    struct NodePoliciesParams {
        bytes32[] proof;
        bool[] proofFlags;
        bytes4[] selectors;
        address[] policies;
        bool shouldSucceed;
    }

    struct NodePoliciesRemovalParams {
        bytes4[] selectors;
        address[] policies;
        bool shouldSucceed;
    }

    struct NodeTargetReserveParams {
        uint64 target;
        bool shouldSucceed;
    }

    struct NodeSwingPricingParams {
        bool status;
        uint64 maxSwingFactor;
        bool shouldSucceed;
    }

    struct NodeSubmitPolicyParams {
        bytes4 selector;
        address policy;
        bytes data;
        bool shouldSucceed;
    }

    struct NodeQueueParams {
        address[] queue;
        bool shouldSucceed;
    }

    struct NodeStartRebalanceParams {
        address caller;
        uint256 lastRebalanceBefore;
        bool shouldSucceed;
    }

    struct NodePayManagementFeesParams {
        address caller;
        uint256 lastPaymentBefore;
        uint256 nodeAssetBalanceBefore;
        uint256 nodeTotalAssetsBefore;
        uint256 protocolFeeBalanceBefore;
        uint256 nodeOwnerBalanceBefore;
        bool shouldSucceed;
    }

    struct NodeUpdateTotalAssetsParams {
        address caller;
        uint256 nodeTotalAssetsBefore;
        bool shouldSucceed;
    }

    struct NodeSubtractExecutionFeeParams {
        address caller;
        uint256 fee;
        uint256 nodeBalanceBefore;
        uint256 protocolFeeBalanceBefore;
        bool shouldSucceed;
    }

    struct NodeExecuteParams {
        address caller;
        address target;
        bytes data;
        address allowanceSpender;
        uint256 allowance;
        uint256 allowanceBefore;
        bool shouldSucceed;
    }

    struct NodeSubmitPolicyDataParams {
        address caller;
        bytes4 selector;
        address policy;
        bytes data;
        uint256 expectedProofLength;
        bytes32 proofHash;
        bool shouldSucceed;
    }

    struct NodeFinalizeParams {
        address router;
        address controller;
        uint256 assetsToReturn;
        uint256 sharesPending;
        uint256 sharesAdjusted;
        uint256 nodeAssetBalanceBefore;
        uint256 escrowBalanceBefore;
        uint256 sharesExitingBefore;
        bool shouldSucceed;
    }

    struct NodeMulticallParams {
        address caller;
        bytes[] calls;
        bool shouldSucceed;
    }

    struct RegistryAddressParams {
        address target;
        bool shouldSucceed;
    }

    struct RegistryFeeParams {
        uint64 value;
        bool shouldSucceed;
    }

    struct RegistryExecutionFeeParams {
        uint64 value;
        bool shouldSucceed;
    }

    struct RegistrySwingParams {
        uint64 value;
        bool shouldSucceed;
    }

    struct RegistryPoliciesParams {
        bytes32 root;
        bool shouldSucceed;
    }

    struct RegistrySetTypeParams {
        address target;
        RegistryType typeEnum;
        bool status;
        bool shouldSucceed;
    }

    struct RegistryTransferOwnershipParams {
        address newOwner;
        bool shouldSucceed;
    }

    struct RegistryAddNodeParams {
        address caller;
        address node;
        bool shouldSucceed;
    }

    struct RegistryInitializeParams {
        address owner;
        address feeAddress;
        uint64 managementFee;
        uint64 executionFee;
        uint64 maxSwingFactor;
        bool shouldSucceed;
    }

    struct RegistryOwnershipCallParams {
        address caller;
        bool shouldSucceed;
    }

    struct RegistryUpgradeParams {
        address implementation;
        bytes data;
        bool shouldSucceed;
    }

    struct RouterFulfillAsyncParams {
        address controller;
        address component;
        uint256 pendingBefore;
        uint256 escrowBalanceBefore;
        uint256 claimableAssetsBefore;
        bool shouldSucceed;
    }

    struct DigiftApproveParams {
        address spender;
        uint256 amount;
        bool shouldSucceed;
    }

    struct DigiftTransferParams {
        address to;
        uint256 amount;
        bool shouldSucceed;
    }

    struct DigiftRequestParams {
        uint256 amount;
        bool shouldSucceed;
    }

    struct DigiftMintParams {
        uint256 shares;
        bool shouldSucceed;
    }

    struct DigiftWithdrawParams {
        uint256 assets;
        bool shouldSucceed;
    }

    struct DigiftAssetFundingParams {
        uint256 amount;
        bool shouldSucceed;
    }

    struct DigiftAssetApprovalParams {
        uint256 amount;
        bool shouldSucceed;
    }

    struct DigiftSetAddressBoolParams {
        address target;
        bool status;
        bool shouldSucceed;
    }

    struct DigiftSetUintParams {
        uint256 value;
        bool shouldSucceed;
    }

    struct DigiftForwardParams {
        bool expectDeposit;
        bool expectRedeem;
        bool shouldSucceed;
    }

    struct DigiftSettleParams {
        address[] nodes;
        uint256 shares;
        uint256 assets;
        bool shouldSucceed;
    }

    struct DigiftVerifierConfigureParams {
        DigiftEventVerifier.EventType eventType;
        uint256 expectedShares;
        uint256 expectedAssets;
        bool shouldSucceed;
    }

    struct DigiftFactoryDeployParams {
        DigiftAdapter.InitArgs initArgs;
        address expectedOwner;
        bool shouldSucceed;
    }

    struct DigiftFactoryOwnershipParams {
        address newOwner;
        bool shouldSucceed;
    }

    struct DigiftFactoryUpgradeParams {
        address newImplementation;
        bool shouldSucceed;
    }

    struct DigiftVerifierWhitelistParams {
        address adapter;
        bool status;
        bool shouldSucceed;
    }

    struct DigiftVerifierBlockHashParams {
        uint256 blockNumber;
        bytes32 blockHash;
        bool shouldSucceed;
    }

    struct DigiftVerifierVerifyParams {
        DigiftEventVerifier.EventType eventType;
        address adapter;
        address securityToken;
        address currencyToken;
        uint256 expectedShares;
        uint256 expectedAssets;
        bool shouldSucceed;
    }

    struct PolicyCapParams {
        uint256 newCap;
    }

    struct PolicyWhitelistParams {
        address actor;
        bool add;
    }

    struct PolicyPauseParams {
        bytes4 selector;
        bool isGlobal;
        bool pause;
    }
}
