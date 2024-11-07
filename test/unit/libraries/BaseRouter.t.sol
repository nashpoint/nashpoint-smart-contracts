// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {BaseRouter} from "src/libraries/BaseRouter.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {Node} from "src/Node.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract TestRouter is BaseRouter {
    constructor(address registry_) BaseRouter(registry_) {}

    function testOnlyNodeRebalancer(address node) external onlyNodeRebalancer(node) {}

    function testOnlyRegistryOwner() external onlyRegistryOwner {}

    function testOnlyWhitelisted(address target) external onlyWhitelisted(target) {}
}

contract BaseRouterTest is BaseTest {
    TestRouter public testRouter;
    ERC20Mock public mockToken;
    address public testTarget;
    address public testSpender;

    function setUp() public override {
        super.setUp();
        
        testTarget = makeAddr("testTarget");
        testSpender = makeAddr("testSpender");
        
        testRouter = new TestRouter(address(registry));
        
        mockToken = new ERC20Mock("Mock Token", "MOCK");

        vm.label(testTarget, "TestTarget");
        vm.label(testSpender, "TestSpender");
        vm.label(address(testRouter), "TestRouter");
        vm.label(address(mockToken), "MockToken");
    }

    function test_constructor() public {
        assertEq(address(testRouter.registry()), address(registry));
    }

    function test_constructor_revert_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new TestRouter(address(0));
    }

    function test_setWhitelistStatus() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit BaseRouter.TargetWhitelisted(testTarget, true);
        testRouter.setWhitelistStatus(testTarget, true);
        assertTrue(testRouter.isWhitelisted(testTarget));

        vm.expectEmit(true, true, true, true);
        emit BaseRouter.TargetWhitelisted(testTarget, false);
        testRouter.setWhitelistStatus(testTarget, false);
        assertFalse(testRouter.isWhitelisted(testTarget));
        
        vm.stopPrank();
    }

    function test_setWhitelistStatus_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRouter.setWhitelistStatus(address(0), true);
    }

    function test_setWhitelistStatus_revert_NotRegistryOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        testRouter.setWhitelistStatus(testTarget, true);
    }

    function test_batchSetWhitelistStatus() public {
        address[] memory targets = new address[](2);
        targets[0] = testTarget;
        targets[1] = makeAddr("testTarget2");
        bool[] memory statuses = new bool[](2);
        statuses[0] = true;
        statuses[1] = false;

        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit BaseRouter.TargetWhitelisted(targets[0], statuses[0]);
        vm.expectEmit(true, true, true, true);
        emit BaseRouter.TargetWhitelisted(targets[1], statuses[1]);
        testRouter.batchSetWhitelistStatus(targets, statuses);

        assertTrue(testRouter.isWhitelisted(targets[0]));
        assertFalse(testRouter.isWhitelisted(targets[1]));
        
        vm.stopPrank();
    }

    function test_batchSetWhitelistStatus_revert_LengthMismatch() public {
        address[] memory targets = new address[](2);
        bool[] memory statuses = new bool[](1);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.LengthMismatch.selector);
        testRouter.batchSetWhitelistStatus(targets, statuses);
    }

    function test_batchSetWhitelistStatus_revert_ZeroAddress() public {
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRouter.batchSetWhitelistStatus(targets, statuses);
    }

    function test_batchSetWhitelistStatus_revert_NotRegistryOwner() public {
        address[] memory targets = new address[](1);
        bool[] memory statuses = new bool[](1);

        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        testRouter.batchSetWhitelistStatus(targets, statuses);
    }

    function test_approve() public {
        // Setup valid node         
        vm.prank(owner);
        node.addRouter(address(testRouter));

        // Whitelist spender instead of token
        vm.prank(owner);
        testRouter.setWhitelistStatus(testSpender, true);

        // Test approve with valid node and rebalancer
        vm.prank(rebalancer);
        testRouter.approve(address(node), address(mockToken), testSpender, 100);

        assertEq(mockToken.allowance(address(node), testSpender), 100);
    }

    function test_approve_revert_NotWhitelisted() public {
        // Setup valid node         
        vm.prank(owner);
        node.addRouter(address(testRouter));

        // Don't whitelist spender
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        testRouter.approve(address(node), address(mockToken), testSpender, 100);
    }

    function test_approve_revert_InvalidNode() public {
        address invalidNode = makeAddr("invalidNode");

        // Whitelist spender
        vm.prank(owner);
        testRouter.setWhitelistStatus(testSpender, true);

        // Should revert on invalid node check
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        testRouter.approve(invalidNode, address(mockToken), testSpender, 100);
    }

    function test_onlyWhitelisted() public {
        // Setup whitelist
        vm.prank(owner);
        testRouter.setWhitelistStatus(testTarget, true);

        // Test the modifier
        testRouter.testOnlyWhitelisted(testTarget);
    }

    function test_onlyWhitelisted_revert_NotWhitelisted() public {
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        testRouter.testOnlyWhitelisted(testTarget);
    }

    function test_onlyNodeRebalancer() public {
        assertEq(node.rebalancer(), rebalancer);

        // Test the modifier with valid node and rebalancer
        vm.prank(rebalancer);
        testRouter.testOnlyNodeRebalancer(address(node));
    }

    function test_onlyNodeRebalancer_revert_InvalidNode() public {
        address invalidNode = makeAddr("invalidNode");

        // Should revert before even checking rebalancer
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        testRouter.testOnlyNodeRebalancer(invalidNode);
    }

    function test_onlyNodeRebalancer_revert_NotRebalancer() public {
        // Setup valid node but call from wrong address
        assertNotEq(node.rebalancer(), randomUser); 

        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        testRouter.testOnlyNodeRebalancer(address(node));
    }

    function test_onlyRegistryOwner() public {
        vm.prank(owner);
        testRouter.testOnlyRegistryOwner();
    }

    function test_onlyRegistryOwner_revert_NotRegistryOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        testRouter.testOnlyRegistryOwner();
    }
}
