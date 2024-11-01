// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {QueueManager} from "src/QueueManager.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract QueueManagerHarness is QueueManager {
    constructor(address node_) QueueManager(node_) {}

    function calculatePrice(uint128 assets, uint128 shares) external view returns (uint256 price) {
        return _calculatePrice(assets, shares);
    }
}

contract QueueManagerTest is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(owner);
    }

    function test_deployment() public {
        QueueManager newManager = new QueueManager(address(node));

        assertEq(address(newManager.node()), address(node));
    }

    function test_deployment_RevertIf_ZeroNode() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new QueueManager(address(0));
    }

    function testPrice() public {
        QueueManagerHarness harness = new QueueManagerHarness(address(node));
        assertEq(harness.calculatePrice(1, 0), 0);
        assertEq(harness.calculatePrice(0, 1), 0);
    }
}
