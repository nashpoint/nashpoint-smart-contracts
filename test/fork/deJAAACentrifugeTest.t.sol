// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Node} from "src/Node.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";

interface ISpoke {
    // tokenId 0 in case of ERC20
    function assetToId(address asset, uint256 tokenId) external view returns (uint128 assetId);
}

interface IBalanceSheet {
    function updateManager(uint64 poolId, address who, bool canManage) external;
    function escrow(uint64 poolId) external view returns (IPoolEscrow);
}

interface IPoolEscrow {
    function deposit(bytes16 scId, address asset, uint256 tokenId, uint128 value) external;
    function reserve(bytes16 scId, address asset, uint256 tokenId, uint128 value) external;
}

interface IAsyncRequestManager {
    function globalEscrow() external returns (address);
    function balanceSheet() external returns (address);

    function fulfillDepositRequest(
        uint64 poolId,
        bytes16 scId,
        address user,
        uint128 assetId,
        uint128 fulfilledAssets,
        uint128 fulfilledShares,
        uint128 cancelledAssets
    ) external;

    function fulfillRedeemRequest(
        uint64 poolId,
        bytes16 scId,
        address user,
        uint128 assetId,
        uint128 fulfilledAssets,
        uint128 fulfilledShares,
        uint128 cancelledShares
    ) external;
}

interface IAsyncVault {
    function manager() external view returns (address);
    function poolId() external view returns (uint64);
    function scId() external view returns (bytes16);
    function root() external view returns (address);
    function asset() external view returns (address);
    function share() external view returns (address);
}

contract deJAAACentrifugeTest is Test {
    address root;
    address globalEscrow;
    IPoolEscrow poolEscrow;
    IBalanceSheet balanceSheet;
    IAsyncRequestManager manager;
    ISpoke spoke = ISpoke(0xd30Da1d7F964E5f6C2D9fE2AAA97517F6B23FA2B);

    address deJAAA = 0xe897E7F16e8F4ed568A62955b17744bCB3207d6E;

    address protocolOwner = 0x69C2d63BC4Fcd16CD616D22089B58de3796E1F5c;
    address nodeOwner = 0x8d1A519326724b18A6F5877a082aae19394D0f67;
    address rebalancer = nodeOwner;
    ERC7540Router erc7540Router = ERC7540Router(0x6a200b1Bafc7183741809B35E1B0DE9E4f4c0828);
    ERC4626Router erc4626Router = ERC4626Router(0x18E7a99c527Bd1727111082b8C7D36D1995B89B8);

    Node node = Node(0x6ca200319A0D4127a7a473d6891B86f34e312F42);

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 404279640);

        vm.startPrank(protocolOwner);
        erc7540Router.setWhitelistStatus(deJAAA, true);
        vm.stopPrank();

        root = IAsyncVault(deJAAA).root();
        manager = IAsyncRequestManager(IAsyncVault(deJAAA).manager());
        globalEscrow = manager.globalEscrow();
        balanceSheet = IBalanceSheet(manager.balanceSheet());
        poolEscrow = balanceSheet.escrow(IAsyncVault(deJAAA).poolId());
    }

    function test_deJAAA_integration() external {
        address aave = 0x8E7617ba208479e1CCA2b929916285C1eCaCe4C5;
        vm.startPrank(nodeOwner);
        // set aave to zero
        node.updateComponentAllocation(aave, 0, 0, address(erc4626Router));
        node.addComponent(deJAAA, 50.31e16, 0, address(erc7540Router));
        vm.stopPrank();

        assertTrue(node.validateComponentRatios(), "100% ratio");

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(rebalancer);
        node.startRebalance();

        erc4626Router.liquidate(address(node), aave, IERC20(aave).balanceOf(address(node)), 0);

        uint256 depositAmount = erc7540Router.investInAsyncComponent(address(node), deJAAA);

        vm.stopPrank();

        vm.startPrank(root);
        manager.fulfillDepositRequest(
            IAsyncVault(deJAAA).poolId(),
            IAsyncVault(deJAAA).scId(),
            address(node),
            spoke.assetToId(IAsyncVault(deJAAA).asset(), 0),
            uint128(depositAmount),
            uint128(depositAmount),
            0 ether
        );
        // TODO: manager for that poolId is not whitelisted yet - we need this for requestRedeem
        // otherwise revert with NotAuthorized()
        balanceSheet.updateManager(IAsyncVault(deJAAA).poolId(), address(manager), true);
        vm.stopPrank();
        deal(IAsyncVault(deJAAA).share(), globalEscrow, depositAmount);

        vm.startPrank(rebalancer);

        uint256 sharesReceived = erc7540Router.mintClaimableShares(address(node), deJAAA);

        erc7540Router.requestAsyncWithdrawal(address(node), deJAAA, sharesReceived);

        vm.startPrank(root);
        manager.fulfillRedeemRequest(
            IAsyncVault(deJAAA).poolId(),
            IAsyncVault(deJAAA).scId(),
            address(node),
            spoke.assetToId(IAsyncVault(deJAAA).asset(), 0),
            uint128(depositAmount),
            uint128(depositAmount),
            0 ether
        );
        // prepare poolEscrow for actual withdrawal
        poolEscrow.deposit(IAsyncVault(deJAAA).scId(), IAsyncVault(deJAAA).asset(), 0, uint128(depositAmount));
        poolEscrow.reserve(IAsyncVault(deJAAA).scId(), IAsyncVault(deJAAA).asset(), 0, uint128(depositAmount));
        deal(IAsyncVault(deJAAA).asset(), address(poolEscrow), depositAmount);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        uint256 assetsReceived = erc7540Router.executeAsyncWithdrawal(address(node), deJAAA, depositAmount);

        assertEq(assetsReceived, depositAmount);
    }
}
