// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {console2} from "forge-std/Test.sol";

import {BaseTest} from "../../BaseTest.sol";

import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {IERC7540, IERC7540Deposit} from "src/interfaces/IERC7540.sol";
import {BaseRouter} from "src/libraries/BaseRouter.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {ComponentAllocation} from "src/interfaces/INode.sol";

contract ERC7540RouterHarness is ERC7540Router {
    constructor(address _registry) ERC7540Router(_registry) {}

    function getInvestmentSize(address node, address component) public view returns (uint256 depositAssets) {
        return super._getInvestmentSize(node, component);
    }
}

contract ERC7540RouterTest is BaseTest {
    ERC7540RouterHarness public testRouter;

    function setUp() public override {
        super.setUp();
        testRouter = new ERC7540RouterHarness(address(registry));
    }

    function test_getInvestmentSize_7540() public {
        _seedNode(100 ether);
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        vm.stopPrank();

        uint256 investmentSize = testRouter.getInvestmentSize(address(node), address(liquidityPool));

        assertEq(node.getComponentRatio(address(liquidityPool)), 0.5 ether);
        assertEq(liquidityPool.balanceOf(address(node)), 0);
        assertEq(investmentSize, 50 ether);
    }

    function test_investInAsyncVault() public {
        _seedNode(100 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        assertEq(liquidityPool.pendingDepositRequest(0, address(node)), 50 ether);
    }

    function test_mintClaimableShares() public {
        _seedNode(100 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(poolManager);
        liquidityPool.processPendingDeposits();
        assertEq(liquidityPool.claimableDepositRequest(0, address(node)), 50 ether);

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(50 ether));
    }

    function test_requestAsyncWithdrawal() public {
        _seedNode(100 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(poolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(50 ether));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
        vm.stopPrank();

        assertEq(liquidityPool.pendingRedeemRequest(0, address(node)), 10 ether);
        assertEq(liquidityPool.balanceOf(address(node)), liquidityPool.convertToShares(40 ether));
    }

    function test_executeAsyncWithdrawal() public {
        _seedNode(100 ether);

        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc7540(address(liquidityPool), true);
        node.addComponent(address(liquidityPool), allocation);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        vm.stopPrank();

        vm.prank(rebalancer);
        router7540.investInAsyncVault(address(node), address(liquidityPool));

        vm.prank(poolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));

        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);
        vm.stopPrank();

        assertEq(liquidityPool.pendingRedeemRequest(0, address(node)), 10 ether);

        vm.prank(poolManager);
        liquidityPool.processPendingRedemptions();

        assertEq(liquidityPool.claimableRedeemRequest(0, address(node)), 10 ether);
        assertEq(liquidityPool.pendingRedeemRequest(0, address(node)), 0);

        uint256 balanceBefore = asset.balanceOf(address(node));

        vm.prank(rebalancer);
        router7540.executeAsyncWithdrawal(address(node), address(liquidityPool), 10 ether);

        uint256 balanceAfter = asset.balanceOf(address(node));
        assertEq(balanceAfter - balanceBefore, 10 ether);
    }
}
