// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RevertHandler.sol";
import {ErrorsLib} from "../../../src/libraries/ErrorsLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    UpgradeableBeacon
} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

abstract contract Properties_ERR is RevertHandler {
    /*
     *
     * FUZZ NOTE: CHECK REVERTS CONFIGURATION IN FUZZ STORAGE VARIABLES
     *
     */

    function _getAllowedPanicCodes()
        internal
        pure
        virtual
        override
        returns (uint256[] memory)
    {
        uint256[] memory panicCodes = new uint256[](0);

        return panicCodes;
    }

    // Add additional errors here
    // Example:
    // Deposit errors [0-5]
    // allowedErrors[0] = IUsdnProtocolErrors.UsdnProtocolEmptyVault.selector;
    // allowedErrors[1] = IUsdnProtocolErrors
    //     .UsdnProtocolDepositTooSmall
    //     .selector;

    function _getAllowedCustomErrors()
        internal
        pure
        virtual
        override
        returns (bytes4[] memory)
    {
        bytes4[] memory allowedErrors = new bytes4[](125);
        allowedErrors[0] = 0xd92e233d; // NodeFactory.ZeroAddress()
        allowedErrors[1] = 0x430f13b3; // NodeFactory.InvalidName()
        allowedErrors[2] = 0x04119bc4; // NodeFactory.InvalidSymbol()
        allowedErrors[3] = 0xee90c468; // NodeFactory.Forbidden()
        allowedErrors[4] = 0xe13ea8b0; // ERC7540Router.InsufficientSharesReturned(address component, uint256 sharesReturned, uint256 expectedShares)
        allowedErrors[5] = 0xb6e4de52; // ERC7540Router.InsufficientAssetsReturned(address component, uint256 assetsReturned, uint256 expectedAssets)
        allowedErrors[6] = 0x70ea8da0; // ERC7540Router.ExceedsAvailableShares(address node, address component, uint256 shares)
        allowedErrors[7] = 0x9ec9c32c; // ERC7540Router.ExceedsAvailableAssets(address node, address component, uint256 assets)
        allowedErrors[8] = 0x88d3e72a; // ERC7540Router.IncorrectRequestId(uint256 requestId)
        allowedErrors[9] = 0x6b03847f; // OneInchV6RouterV1.ExecutorNotWhitelisted()
        allowedErrors[10] = 0x46d6ddea; // OneInchV6RouterV1.IncentiveNotWhitelisted()
        allowedErrors[11] = 0x7ffa4624; // OneInchV6RouterV1.IncentiveIsAsset()
        allowedErrors[12] = 0x6ab8740d; // OneInchV6RouterV1.IncentiveIsComponent()
        allowedErrors[13] = 0xdcc4b980; // OneInchV6RouterV1.IncentiveIncompleteSwap()
        allowedErrors[14] = 0x8d7986f2; // OneInchV6RouterV1.IncentiveInsufficientAmount()
        allowedErrors[15] = 0xa3a14c50; // ERC4626Router.ExceedsMaxComponentDeposit(address component, uint256 depositAmount, uint256 maxDeposit)
        allowedErrors[16] = 0xe13ea8b0; // ERC4626Router.InsufficientSharesReturned(address component, uint256 sharesReturned, uint256 expectedShares)
        allowedErrors[17] = 0xb6e4de52; // ERC4626Router.InsufficientAssetsReturned(address component, uint256 assetsReturned, uint256 expectedAssets)
        allowedErrors[18] = 0x73fb0074; // ERC4626Router.InvalidShareValue(address component, uint256 shares)
        // ERC7540Mock custom errors
        allowedErrors[116] = 0x19f8c45a; // ERC7540Mock.ERC7540Mock_NoPendingDepositAvailable()
        allowedErrors[117] = 0x45451498; // ERC7540Mock.ERC7540Mock_NoPendingRedeemAvailable()
        allowedErrors[118] = 0x48ff9673; // ERC7540Mock.ERC7540Mock_NoClaimableRedeemAvailable()
        allowedErrors[119] = 0x5d41aba8; // ERC7540Mock.ERC7540Mock_ExceedsPendingDeposit()
        allowedErrors[120] = 0x4658eb3f; // ERC7540Mock.ERC7540Mock_ExceedsPendingRedeem()
        allowedErrors[121] = 0x41ecdb1d; // ERC7540Mock.ERC7540Mock_NotImplementedYet()
        // OpenZeppelin ERC6093 errors
        allowedErrors[122] = 0xfb8f41b2; // ERC20InsufficientAllowance(address,uint256,uint256)
        allowedErrors[123] = 0xe450d38c; // ERC20InsufficientBalance(address,uint256,uint256)
        // OpenZeppelin Address library errors
        allowedErrors[124] = 0xd6bda275; // FailedCall()
        allowedErrors[19] = 0xd92e233d; // ErrorsLib.ZeroAddress()
        allowedErrors[20] = 0xa741a045; // ErrorsLib.AlreadySet()
        allowedErrors[21] = 0x441dfbd6; // ErrorsLib.NotSet()
        allowedErrors[22] = 0x35250365; // ErrorsLib.NotRebalancer()
        allowedErrors[23] = 0x7c214f04; // ErrorsLib.NotOperator()
        allowedErrors[24] = 0x8c51c63a; // ErrorsLib.SafeApproveFailed()
        allowedErrors[25] = 0x430f13b3; // ErrorsLib.InvalidName()
        allowedErrors[26] = 0x04119bc4; // ErrorsLib.InvalidSymbol()
        allowedErrors[27] = 0x1f2a2005; // ErrorsLib.ZeroAmount()
        allowedErrors[28] = 0xddb5de5e; // ErrorsLib.InvalidSender()
        allowedErrors[29] = 0x49e27cff; // ErrorsLib.InvalidOwner()
        allowedErrors[30] = 0x6d5769be; // ErrorsLib.InvalidController()
        allowedErrors[31] = 0xf4d678b8; // ErrorsLib.InsufficientBalance()
        allowedErrors[32] = 0x4b39454c; // ErrorsLib.RequestDepositFailed()
        allowedErrors[33] = 0x1df29218; // ErrorsLib.RequestRedeemFailed()
        allowedErrors[34] = 0x43588e57; // ErrorsLib.CannotSetSelfAsOperator()
        allowedErrors[35] = 0xfdc8b49b; // ErrorsLib.NoPendingDepositRequest()
        allowedErrors[36] = 0xc080425e; // ErrorsLib.NoPendingRedeemRequest()
        allowedErrors[37] = 0xe4bac01b; // ErrorsLib.ExceedsMaxDeposit()
        allowedErrors[38] = 0x52f7657b; // ErrorsLib.ExceedsMaxMint()
        allowedErrors[39] = 0xe11466d6; // ErrorsLib.ExceedsMaxRedeem()
        allowedErrors[40] = 0xb27956c5; // ErrorsLib.ExceedsMaxWithdraw()
        allowedErrors[41] = 0xf7d74013; // ErrorsLib.ExceedsMaxDepositLimit()
        allowedErrors[42] = 0xb03ac0b6; // ErrorsLib.InvalidComponent()
        allowedErrors[43] = 0xc420dae9; // ErrorsLib.InvalidComponentAsset()
        allowedErrors[44] = 0xc1ab6dc1; // ErrorsLib.InvalidToken()
        allowedErrors[45] = 0xd954416a; // ErrorsLib.InvalidRole()
        allowedErrors[46] = 0x32cc7236; // ErrorsLib.NotFactory()
        allowedErrors[47] = 0x0dc149f0; // ErrorsLib.AlreadyInitialized()
        allowedErrors[48] = 0xd08a05d5; // ErrorsLib.NotNodeOwner()
        allowedErrors[49] = 0xd90257a5; // ErrorsLib.NotNodeRebalancer()
        allowedErrors[50] = 0x91655201; // ErrorsLib.NotRouter()
        allowedErrors[51] = 0xaba47339; // ErrorsLib.NotRegistered()
        allowedErrors[52] = 0xef1a8d1a; // ErrorsLib.NotRegistryOwner()
        allowedErrors[53] = 0xff633a38; // ErrorsLib.LengthMismatch()
        allowedErrors[54] = 0x20b401c8; // ErrorsLib.NonZeroBalance()
        allowedErrors[55] = 0x584a7938; // ErrorsLib.NotWhitelisted()
        allowedErrors[56] = 0xa57ed368; // ErrorsLib.NotBlacklisted()
        allowedErrors[57] = 0x09550c77; // ErrorsLib.Blacklisted()
        allowedErrors[58] = 0x30812d42; // ErrorsLib.InvalidNode()
        allowedErrors[59] = 0x5576a6c2; // ErrorsLib.ReserveBelowTargetRatio()
        allowedErrors[60] = 0x554b72bb; // ErrorsLib.ComponentWithinTargetRange(address node, address component)
        allowedErrors[61] = 0xc02c9fc4; // ErrorsLib.ExceedsAvailableReserve()
        allowedErrors[62] = 0x2e5ba0aa; // ErrorsLib.DuplicateComponent()
        allowedErrors[63] = 0xaa9a98df; // ErrorsLib.CooldownActive()
        allowedErrors[64] = 0x284e99ba; // ErrorsLib.RebalanceWindowClosed()
        allowedErrors[65] = 0xa91714a6; // ErrorsLib.RebalanceWindowOpen()
        allowedErrors[66] = 0xeceff917; // ErrorsLib.NotEnoughAssetsToPayFees(uint256 feeForPeriod, uint256 assetsBalance)
        allowedErrors[67] = 0xfa511286; // ErrorsLib.InvalidComponentRatios()
        allowedErrors[68] = 0x5534f9b3; // ErrorsLib.FeeExceedsAmount(uint256 fee, uint256 amount)
        allowedErrors[69] = 0x58d620b3; // ErrorsLib.InvalidFee()
        allowedErrors[70] = 0x7d6e5ec8; // ErrorsLib.PolicyAlreadyAdded(bytes4 sig, address policy)
        allowedErrors[71] = 0x42b1767d; // ErrorsLib.PolicyAlreadyRemoved(bytes4 sig, address policy)
        allowedErrors[72] = 0x965321da; // ErrorsLib.NotFound(address element)
        allowedErrors[73] = 0x5b373b55; // ErrorsLib.NotAllowedAction(bytes4 sig)
        allowedErrors[74] = 0xee90c468; // ErrorsLib.Forbidden()
        allowedErrors[75] = 0x9d6b436c; // ProtocolPausingPolicy.GlobalPause()
        allowedErrors[76] = 0x754cce71; // ProtocolPausingPolicy.SigPause(bytes4 sig)
        allowedErrors[77] = 0x9d6b436c; // NodePausingPolicy.GlobalPause()
        allowedErrors[78] = 0x754cce71; // NodePausingPolicy.SigPause(bytes4 sig)
        allowedErrors[79] = 0x73a6d13b; // CapPolicy.CapExceeded(uint256 byAmount)
        allowedErrors[80] = 0x451b7cff; // allows.BadHeader()
        allowedErrors[81] = 0xdb6950fd; // allows.LogAlreadyUsed()
        allowedErrors[82] = 0xb74476bf; // allows.MissedWindow()
        allowedErrors[83] = 0x055dbb6c; // allows.NoEvent()
        allowedErrors[84] = 0x4b131c2e; // allows.ZeroBytes()
        allowedErrors[85] = 0x584a7938; // allows.NotWhitelisted()
        allowedErrors[86] = 0x1d8d0c74; // ID.BelowLimit(uint256 minAmount, uint256 actualAmount)
        allowedErrors[87] = 0x2e600ba9; // ID.ControllerNotSender()
        allowedErrors[88] = 0xf2e85df0; // ID.OwnerNotSender()
        allowedErrors[89] = 0xe9d5d60d; // ID.DepositRequestPending()
        allowedErrors[90] = 0xead2d7c6; // ID.DepositRequestNotClaimed()
        allowedErrors[91] = 0x60937c40; // ID.RedeemRequestPending()
        allowedErrors[92] = 0xd468c857; // ID.RedeemRequestNotClaimed()
        allowedErrors[93] = 0x2f19e7ee; // ID.DepositRequestNotFulfilled()
        allowedErrors[94] = 0xc15a465e; // ID.RedeemRequestNotFulfilled()
        allowedErrors[95] = 0x0e1bc532; // ID.MintAllSharesOnly()
        allowedErrors[96] = 0x247379fd; // ID.WithdrawAllAssetsOnly()
        allowedErrors[97] = 0x618104e8; // ID.NothingToSettle()
        allowedErrors[98] = 0xa204529c; // ID.NoPendingDepositRequest(address node)
        allowedErrors[99] = 0x02ca80ab; // ID.NoPendingRedeemRequest(address node)
        allowedErrors[100] = 0x90a2caf2; // ID.Unsupported()
        allowedErrors[101] = 0x1f3b85d3; // ID.InvalidPercentage()
        allowedErrors[102] = 0x9b9f824f; // ID.PriceNotInRange(uint256 lastValue, uint256 currentValue)
        allowedErrors[103] = 0x8a63b2aa; // ID.SettlementNotInRange(uint256 expected, uint256 actual)
        allowedErrors[104] = 0x16d7d159; // ID.StalePriceData(uint256 lastUpdate, uint256 currentTimestamp)
        allowedErrors[105] = 0x5cd26b68; // ID.NotNode()
        allowedErrors[106] = 0x2a19e833; // ID.NotManager(address caller)
        allowedErrors[107] = 0x872682ef; // ID.NotWhitelistedNode(address node)
        allowedErrors[108] = 0x49eb36ee; // ID.BadPriceOracle(address oracle)
        allowedErrors[109] = 0x68bda8d4; // ID.NotAllNodesSettled()
        allowedErrors[110] = 0x82b42900; // IFluidDistributor.Unauthorized()
        allowedErrors[111] = 0xa86b6512; // IFluidDistributor.InvalidParams()
        allowedErrors[112] = 0x9b8febfe; // IFluidDistributor.InvalidCycle()
        allowedErrors[113] = 0x09bde339; // IFluidDistributor.InvalidProof()
        allowedErrors[114] = 0x969bf728; // IFluidDistributor.NothingToClaim()
        allowedErrors[115] = 0xbd79de58; // IFluidDistributor.MsgSenderNotRecipient()
        return allowedErrors;
    }

    function _isAllowedERC20Error(
        bytes memory returnData
    ) internal pure virtual override returns (bool) {
        bytes[] memory allowedErrors = new bytes[](9);
        allowedErrors[0] = INSUFFICIENT_ALLOWANCE;
        allowedErrors[1] = TRANSFER_FROM_ZERO;
        allowedErrors[2] = TRANSFER_TO_ZERO;
        allowedErrors[3] = APPROVE_TO_ZERO;
        allowedErrors[4] = MINT_TO_ZERO;
        allowedErrors[5] = BURN_FROM_ZERO;
        allowedErrors[6] = DECREASED_ALLOWANCE;
        allowedErrors[7] = BURN_EXCEEDS_BALANCE;
        allowedErrors[8] = EXCEEDS_BALANCE_ERROR;

        for (uint256 i = 0; i < allowedErrors.length; i++) {
            if (keccak256(returnData) == keccak256(allowedErrors[i])) {
                return true;
            }
        }
        return false;
    }

    function _getAllowedSoladyERC20Error()
        internal
        pure
        virtual
        override
        returns (bytes4[] memory)
    {
        bytes4[] memory allowedErrors = new bytes4[](5);
        allowedErrors[0] = SafeTransferLib.ETHTransferFailed.selector;
        allowedErrors[1] = SafeTransferLib.TransferFromFailed.selector;
        allowedErrors[2] = SafeTransferLib.TransferFailed.selector;
        allowedErrors[3] = SafeTransferLib.ApproveFailed.selector;
        allowedErrors[4] = bytes4(0x82b42900); //unauthorized selector

        return allowedErrors;
    }

    function _isAllowedFoundryERC20Error(
        bytes memory returnData
    ) internal virtual override returns (bool) {
        // ERC7540Mock string errors
        bytes4 errorSelector = bytes4(keccak256("Error(string)"));

        bytes[] memory allowedErrors = new bytes[](10);
        allowedErrors[0] = abi.encodeWithSelector(errorSelector, "only poolManager can execute");
        allowedErrors[1] = abi.encodeWithSelector(errorSelector, "Cannot request deposit of 0 assets");
        allowedErrors[2] = abi.encodeWithSelector(errorSelector, "Not authorized");
        allowedErrors[3] = abi.encodeWithSelector(errorSelector, "Cannot request redeem of 0 shares");
        allowedErrors[4] = abi.encodeWithSelector(errorSelector, "Insufficient shares");
        allowedErrors[5] = abi.encodeWithSelector(errorSelector, "ERC20: addition overflow");
        // ERC7540Mock preview errors
        allowedErrors[6] = abi.encodeWithSelector(errorSelector, "ERC7540: previewDeposit not available for async vault");
        allowedErrors[7] = abi.encodeWithSelector(errorSelector, "ERC7540: previewMint not available for async vault");
        allowedErrors[8] = abi.encodeWithSelector(errorSelector, "ERC7540: previewWithdraw not available for async vault");
        allowedErrors[9] = abi.encodeWithSelector(errorSelector, "ERC7540: previewRedeem not available for async vault");

        for (uint256 i = 0; i < allowedErrors.length; i++) {
            if (keccak256(returnData) == keccak256(allowedErrors[i])) {
                return true;
            }
        }
        return false;
    }
}
