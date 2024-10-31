// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {QueueManager} from "src/QueueManager.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract QueueManagerHarness is QueueManager {
    constructor(address node, address quoter, address owner) QueueManager(node, quoter, owner) {}

    function calculatePrice(uint128 assets, uint128 shares) external view returns (uint256 price) {
        return _calculatePrice(assets, shares);
    }
}

contract QueueManagerTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_deployment() public {
        QueueManager newManager = new QueueManager(address(node), address(quoter), owner);

        assertEq(address(newManager.node()), address(node));
        assertEq(address(newManager.quoter()), address(quoter));
        assertEq(Ownable(address(newManager)).owner(), owner);
    }

    function test_deployment_RevertIf_ZeroNode() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new QueueManager(address(0), address(quoter), owner);
    }

    function test_deployment_RevertIf_ZeroQuoter() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new QueueManager(address(node), address(0), owner);
    }

    function test_requestDeposit() public {
        uint256 amount = 1000;
        address controller = makeAddr("controller");

        vm.prank(address(node));
        bool success = queueManager.requestDeposit(amount, controller);
        assertTrue(success);

        assertEq(queueManager.pendingDepositRequest(controller), amount);
    }

    function test_requestRedeem() public {
        uint256 shares = 1000;
        address controller = makeAddr("controller");

        vm.prank(address(node));
        bool success = queueManager.requestRedeem(shares, controller);
        assertTrue(success);

        assertEq(queueManager.pendingRedeemRequest(controller), shares);
    }

    function testPrice() public {
        QueueManagerHarness harness = new QueueManagerHarness(address(node), address(quoter), owner);
        assertEq(harness.calculatePrice(1, 0), 0);
        assertEq(harness.calculatePrice(0, 1), 0);
    }
}
