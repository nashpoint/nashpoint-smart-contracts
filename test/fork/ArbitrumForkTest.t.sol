// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {console2} from "forge-std/console2.sol";

contract ArbitrumForkTest is BaseTest {
    uint256 arbitrumFork;
    uint256 constant blockNumber = 277189217;
    address constant yUsdcaAddress = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1; // yearn
    address constant fUsdcAddress = 0x1A996cb54bb95462040408C06122D45D6Cdb6096; // fluid
    address constant sdUSDCV3Address = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6; // gearbox
    address constant farmUsdcCompoundV3Address = 0x7b33c028fdcd6425c60b7d2A1a54eC10bFdF14B8; // compound
    address constant farmUsdcAaveV3Address = 0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c; // aave
    address constant revertUsdcV3VaultAddress = 0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825; // revert

    address constant farmControllerAddress = 0x68B2FC1566f411C1Af8fF5bFDA3dD4F3F3e59D03;

    IERC20 public usdc = IERC20(usdcArbitrum);
    IERC4626 public yUsdcA = IERC4626(yUsdcaAddress);
    IERC4626 public fUsdc = IERC4626(fUsdcAddress);
    IERC4626 public sdUsdcV3 = IERC4626(sdUSDCV3Address);
    IERC4626 public farmUsdcCompoundV3 = IERC4626(farmUsdcCompoundV3Address);
    IERC4626 public farmUsdcAaveV3 = IERC4626(farmUsdcAaveV3Address);
    IERC4626 public revertUsdcV3Vault = IERC4626(revertUsdcV3VaultAddress);

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL, blockNumber);
        vm.selectFork(arbitrumFork);
        super.setUp();

        // warp forward to ensure not rebalancing
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        router4626.setWhitelistStatus(yUsdcaAddress, true);
        router4626.setWhitelistStatus(fUsdcAddress, true);
        router4626.setWhitelistStatus(sdUSDCV3Address, true);
        router4626.setWhitelistStatus(farmUsdcCompoundV3Address, true);
        router4626.setWhitelistStatus(farmUsdcAaveV3Address, true);
        router4626.setWhitelistStatus(revertUsdcV3VaultAddress, true);

        node.removeComponent(address(vault), false);
        node.addComponent(address(yUsdcA), 0.15 ether, 0.01 ether, address(router4626));
        node.addComponent(address(fUsdc), 0.15 ether, 0.01 ether, address(router4626));
        node.addComponent(address(sdUsdcV3), 0.15 ether, 0.01 ether, address(router4626));
        node.addComponent(address(farmUsdcCompoundV3), 0.15 ether, 0.01 ether, address(router4626));
        node.addComponent(address(farmUsdcAaveV3), 0.15 ether, 0.01 ether, address(router4626));
        node.addComponent(address(revertUsdcV3Vault), 0.15 ether, 0.01 ether, address(router4626));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance();
    }

    // user interaction tests

    function test_canSelectArbitrum() public {
        vm.selectFork(arbitrumFork);
        assertEq(vm.activeFork(), arbitrumFork);
    }

    function test_usdcAddress() public view {
        string memory name = IERC20Metadata(usdcArbitrum).name();
        uint256 totalSupply = IERC20Metadata(usdcArbitrum).totalSupply();
        assertEq(name, "USD Coin");
        assertEq(totalSupply, 1808663807522167);
        assertEq(IERC20Metadata(usdcArbitrum).decimals(), 6);
    }

    function test_yearnUsdcA_Address() public view {
        string memory name = IERC20Metadata(yUsdcA).name();
        address vaultAsset = IERC4626(yUsdcA).asset();

        assertEq(name, "USDC-A yVault");
        assertEq(vaultAsset, usdcArbitrum);
    }

    function test_yUsdcA_userDeposit() public {
        uint256 expectedShares = yUsdcA.previewDeposit(100e6);

        vm.startPrank(user);
        usdc.approve(address(yUsdcA), 100e6);
        yUsdcA.deposit(100e6, user);
        vm.stopPrank();

        assertEq(yUsdcA.balanceOf(address(user)), expectedShares);
    }

    function test_farmUsdcCompoundV3_userDeposit() public {
        uint256 expectedShares = farmUsdcCompoundV3.previewDeposit(100e6);

        // mock the controller to not greylist the user
        vm.mockCall(
            farmControllerAddress, // controller address
            abi.encodeWithSignature("greyList(address)", user),
            abi.encode(false)
        );

        vm.startPrank(user);
        usdc.approve(address(farmUsdcCompoundV3), 100e6);
        farmUsdcCompoundV3.deposit(100e6, user);
        vm.stopPrank();

        assertEq(farmUsdcCompoundV3.balanceOf(address(user)), expectedShares);
    }

    function test_farmUsdcAaveV3_userDeposit() public {
        uint256 expectedShares = farmUsdcAaveV3.previewDeposit(100e6);

        // mock the controller to not greylist the user
        vm.mockCall(
            farmControllerAddress, // controller address
            abi.encodeWithSignature("greyList(address)", user),
            abi.encode(false)
        );

        vm.startPrank(user);
        usdc.approve(address(farmUsdcAaveV3), 100e6);
        farmUsdcAaveV3.deposit(100e6, user);
        vm.stopPrank();

        assertEq(farmUsdcAaveV3.balanceOf(address(user)), expectedShares);
    }

    function test_revertUsdcV3Vault_userDeposit() public {
        uint256 expectedShares = revertUsdcV3Vault.previewDeposit(100e6);

        vm.startPrank(user);
        usdc.approve(address(revertUsdcV3Vault), 100e6);
        revertUsdcV3Vault.deposit(100e6, user);
        vm.stopPrank();

        assertEq(revertUsdcV3Vault.balanceOf(address(user)), expectedShares);
    }

    // node interaction tests

    function test_yUsdcA_nodeInvestLiquidate() public {
        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        uint256 userShares = node.balanceOf(address(user));

        assertEq(node.convertToAssets(userShares), 100e6);
        assertEq(usdc.balanceOf(address(node)), 100e6);
        assertEq(yUsdcA.balanceOf(address(node)), 0);

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(yUsdcA), 0);
        vm.stopPrank();

        uint256 nodeShares = yUsdcA.balanceOf(address(node));

        assertApproxEqAbs(yUsdcA.convertToAssets(nodeShares), 15e6, 1);
        assertEq(usdc.balanceOf(address(node)), 85e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(yUsdcA), yUsdcA.balanceOf(address(node)), 0);
        vm.stopPrank();

        assertEq(yUsdcA.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }

    function test_fUsdc_nodeInvestLiquidate() public {
        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(fUsdc), 0);
        vm.stopPrank();

        uint256 nodeShares = fUsdc.balanceOf(address(node));

        assertApproxEqAbs(fUsdc.convertToAssets(nodeShares), 15e6, 1);
        assertEq(usdc.balanceOf(address(node)), 85e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(fUsdc), fUsdc.balanceOf(address(node)), 0);
        vm.stopPrank();

        assertEq(fUsdc.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }

    function test_sdUsdcV3_nodeInvestLiquidate() public {
        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(sdUsdcV3), 0);
        vm.stopPrank();

        uint256 nodeShares = sdUsdcV3.balanceOf(address(node));

        assertApproxEqAbs(sdUsdcV3.convertToAssets(nodeShares), 15e6, 1);
        assertEq(usdc.balanceOf(address(node)), 85e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(sdUsdcV3), sdUsdcV3.balanceOf(address(node)), 0);
        vm.stopPrank();

        assertEq(sdUsdcV3.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }

    function test_farmUsdcCompoundV3_nodeInvestLiquidate() public {
        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        // mock the controller to not greylist the user
        vm.mockCall(
            farmControllerAddress, // controller address
            abi.encodeWithSignature("greyList(address)", node),
            abi.encode(false)
        );

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(farmUsdcCompoundV3), 0);
        vm.stopPrank();

        uint256 nodeShares = farmUsdcCompoundV3.balanceOf(address(node));

        assertApproxEqAbs(farmUsdcCompoundV3.convertToAssets(nodeShares), 15e6, 1);
        assertEq(usdc.balanceOf(address(node)), 85e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(farmUsdcCompoundV3), farmUsdcCompoundV3.balanceOf(address(node)), 0);
        vm.stopPrank();

        assertEq(farmUsdcCompoundV3.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }

    function test_farmUsdcAaveV3_nodeInvestLiquidate() public {
        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        // mock the controller to not greylist the user
        vm.mockCall(
            farmControllerAddress, // controller address
            abi.encodeWithSignature("greyList(address)", node),
            abi.encode(false)
        );

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(farmUsdcAaveV3), 0);
        vm.stopPrank();

        uint256 nodeShares = farmUsdcAaveV3.balanceOf(address(node));

        assertApproxEqAbs(farmUsdcAaveV3.convertToAssets(nodeShares), 15e6, 1);
        assertEq(usdc.balanceOf(address(node)), 85e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(farmUsdcAaveV3), farmUsdcAaveV3.balanceOf(address(node)), 0);
        vm.stopPrank();

        assertEq(farmUsdcAaveV3.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }

    function test_revertUsdcV3Vault_nodeInvestLiquidate() public {
        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router4626.invest(address(node), address(revertUsdcV3Vault), 0);
        vm.stopPrank();

        uint256 nodeShares = revertUsdcV3Vault.balanceOf(address(node));

        assertApproxEqAbs(revertUsdcV3Vault.convertToAssets(nodeShares), 15e6, 1);
        assertEq(usdc.balanceOf(address(node)), 85e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(revertUsdcV3Vault), revertUsdcV3Vault.balanceOf(address(node)), 0);
        vm.stopPrank();

        assertEq(revertUsdcV3Vault.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }
}
