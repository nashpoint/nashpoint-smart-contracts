// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "test/BaseTest.sol";
import {Node} from "src/Node.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol"; // delete after
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol"; // delete after
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {console2} from "forge-std/console2.sol";

contract ForkTest is BaseTest {
    uint256 arbitrumFork;
    address constant yUsdcaAddress = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1; // yearn vault
    uint256 constant blockNumber = 277189217;

    IERC20 public usdc = IERC20(usdcAddress);
    IERC4626 public yUsdcA = IERC4626(yUsdcaAddress);
    address public usdcWhale = 0x4Af51BEb7475a686137bb1B7a9F941fb490961A1;

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL, blockNumber);
        vm.selectFork(arbitrumFork);
        super.setUp();

        vm.startPrank(owner);
        router4626.setWhitelistStatus(yUsdcaAddress, true);
        quoter.setErc4626(yUsdcaAddress, true);
        node.removeComponent(address(vault));
        node.addComponent(address(yUsdcA), ComponentAllocation({targetWeight: 0.9 ether}));
        vm.stopPrank();
    }

    function test_canSelectArbitrum() public {
        vm.selectFork(arbitrumFork);
        assertEq(vm.activeFork(), arbitrumFork);
    }

    function test_usdcAddress() public view {
        string memory name = IERC20Metadata(usdcAddress).name();
        uint256 totalSupply = IERC20Metadata(usdcAddress).totalSupply();
        assertEq(name, "USD Coin");
        assertEq(totalSupply, 1808663807522167);
        assertEq(IERC20Metadata(usdcAddress).decimals(), 6);
    }

    function test_yearnUsdcA_Address() public view {
        string memory name = IERC20Metadata(yUsdcA).name();
        address vaultAsset = IERC4626(yUsdcA).asset();

        assertEq(name, "USDC-A yVault");
        assertEq(vaultAsset, usdcAddress);
    }

    function test_yUsdcA_userDeposit() public {
        vm.startPrank(usdcWhale);
        usdc.transfer(user, 100e6);

        uint256 expectedShares = yUsdcA.previewDeposit(100e6);

        vm.startPrank(user);
        usdc.approve(address(yUsdcA), 100e6);
        yUsdcA.deposit(100e6, user);
        vm.stopPrank();

        assertEq(yUsdcA.balanceOf(address(user)), expectedShares);
    }

    function test_yUsdcA_nodeDeposit() public {
        vm.startPrank(usdcWhale);
        usdc.transfer(user, 100e6);

        vm.startPrank(user);
        usdc.approve(address(node), 100e6);
        node.deposit(100e6, user);
        vm.stopPrank();

        uint256 userShares = node.balanceOf(address(user));

        assertEq(node.convertToAssets(userShares), 100e6);
        assertEq(usdc.balanceOf(address(node)), 100e6);
        assertEq(yUsdcA.balanceOf(address(node)), 0);

        vm.startPrank(rebalancer);
        router4626.deposit(address(node), address(yUsdcA), 90e6);
        vm.stopPrank();

        uint256 nodeShares = yUsdcA.balanceOf(address(node));

        assertApproxEqAbs(yUsdcA.convertToAssets(nodeShares), 90e6, 1);
        assertEq(usdc.balanceOf(address(node)), 10e6);
        assertApproxEqAbs(node.totalAssets(), 100e6, 1);

        vm.startPrank(rebalancer);
        router4626.redeem(address(node), address(yUsdcA), yUsdcA.balanceOf(address(node)));
        vm.stopPrank();

        assertEq(yUsdcA.balanceOf(address(node)), 0);
        assertApproxEqAbs(usdc.balanceOf(address(node)), 100e6, 1);
    }
}
