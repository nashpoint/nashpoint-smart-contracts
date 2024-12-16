// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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
    address constant yUsdcaAddress = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1; // yearn vault
    address constant fUsdcAddress = 0x1A996cb54bb95462040408C06122D45D6Cdb6096; // fluid vault
    address constant sdUSDCV3Address = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6; // gearbox vault
    // note: gTrade has some weird epoch system so not possible to integrate currently

    IERC20 public usdc = IERC20(usdcArbitrum);
    IERC4626 public yUsdcA = IERC4626(yUsdcaAddress);
    IERC4626 public fUsdc = IERC4626(fUsdcAddress);
    IERC4626 public sdUsdcV3 = IERC4626(sdUSDCV3Address);

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL, blockNumber);
        vm.selectFork(arbitrumFork);
        super.setUp();

        vm.startPrank(owner);
        router4626.setWhitelistStatus(yUsdcaAddress, true);
        router4626.setWhitelistStatus(fUsdcAddress, true);
        router4626.setWhitelistStatus(sdUSDCV3Address, true);
        quoter.setErc4626(yUsdcaAddress, true);
        quoter.setErc4626(fUsdcAddress, true);
        quoter.setErc4626(sdUSDCV3Address, true);
        node.removeComponent(address(vault));
        node.addComponent(address(yUsdcA), ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether}));
        node.addComponent(address(fUsdc), ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether}));
        node.addComponent(address(sdUsdcV3), ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether}));
        vm.stopPrank();
    }

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
        router4626.invest(address(node), address(yUsdcA));
        vm.stopPrank();

        uint256 nodeShares = yUsdcA.balanceOf(address(node));

        assertApproxEqAbs(yUsdcA.convertToAssets(nodeShares), 90e6, 1);
        assertEq(usdc.balanceOf(address(node)), 10e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(yUsdcA), yUsdcA.balanceOf(address(node)));
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
        router4626.invest(address(node), address(fUsdc));
        vm.stopPrank();

        uint256 nodeShares = fUsdc.balanceOf(address(node));

        assertApproxEqAbs(fUsdc.convertToAssets(nodeShares), 90e6, 1);
        assertEq(usdc.balanceOf(address(node)), 10e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(fUsdc), fUsdc.balanceOf(address(node)));
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
        router4626.invest(address(node), address(sdUsdcV3));
        vm.stopPrank();

        uint256 nodeShares = sdUsdcV3.balanceOf(address(node));

        assertApproxEqAbs(sdUsdcV3.convertToAssets(nodeShares), 90e6, 1);
        assertEq(usdc.balanceOf(address(node)), 10e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.liquidate(address(node), address(sdUsdcV3), sdUsdcV3.balanceOf(address(node)));
        vm.stopPrank();

        assertEq(sdUsdcV3.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }
}
