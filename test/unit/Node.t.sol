// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseTest} from "../BaseTest.sol";
import {stdStorage, StdStorage, console2} from "forge-std/Test.sol";

import {Node} from "src/Node.sol";
import {INode, ComponentAllocation, Request, NodeInitArgs} from "src/interfaces/INode.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC7540Redeem, IERC7540Operator} from "src/interfaces/IERC7540.sol";
import {IERC7575, IERC165} from "src/interfaces/IERC7575.sol";
import {IQuoterV1} from "src/interfaces/IQuoterV1.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
import {INodeRegistry, RegistryType} from "src/interfaces/INodeRegistry.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract NodeTest is BaseTest {
    using stdStorage for StdStorage;

    NodeRegistry public testRegistry;
    Node public testNode;
    address public testAsset;
    address public testQuoter;
    address public testRouter;
    address public testRebalancer;
    address public testComponent;
    address public testComponent2;
    address public testComponent3;
    address public testEscrow;
    ERC20Mock public testToken;
    ERC4626Mock public testVault;
    ERC4626Mock public testVault2;
    ERC4626Mock public testVault3;

    address nodeImplementation;

    string constant TEST_NAME = "Test Node";
    string constant TEST_SYMBOL = "TNODE";

    uint256 public maxDeposit;
    uint256 public rebalanceCooldown;

    function setUp() public override {
        super.setUp();

        address registryImpl = address(new NodeRegistry());
        testRegistry = NodeRegistry(
            address(
                new ERC1967Proxy(
                    registryImpl,
                    abi.encodeWithSelector(
                        NodeRegistry.initialize.selector, owner, protocolFeesAddress, 0, 0, 0.1 ether
                    )
                )
            )
        );

        testToken = new ERC20Mock("Test Token", "TEST");
        testVault = new ERC4626Mock(address(testToken));
        testVault2 = new ERC4626Mock(address(testToken));
        testVault3 = new ERC4626Mock(address(testToken));
        testEscrow = makeAddr("testEscrow");

        testAsset = address(testToken);
        testQuoter = makeAddr("testQuoter");
        testRouter = makeAddr("testRouter");
        testRebalancer = makeAddr("testRebalancer");
        testComponent = address(testVault);
        testComponent2 = address(testVault2);
        testComponent3 = address(testVault3);
        liquidityPool = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);

        vm.startPrank(owner);

        testRegistry.setRegistryType(address(this), RegistryType.FACTORY, true);
        testRegistry.setRegistryType(address(testRouter), RegistryType.ROUTER, true);
        testRegistry.setRegistryType(address(testRebalancer), RegistryType.REBALANCER, true);
        testRegistry.setRegistryType(address(testQuoter), RegistryType.QUOTER, true);

        testRegistry.setRegistryType(address(router4626), RegistryType.ROUTER, true);
        router4626.setWhitelistStatus(address(testComponent), true);

        nodeImplementation = address(new Node(address(testRegistry)));
        testNode = Node(Clones.clone(nodeImplementation));
        testNode.initialize(NodeInitArgs(TEST_NAME, TEST_SYMBOL, testAsset, owner), testEscrow);

        testNode.addRouter(address(testRouter));
        testNode.addRouter(address(router4626));
        testNode.addRebalancer(testRebalancer);
        testNode.setQuoter(testQuoter);
        ComponentAllocation memory allocation = _defaultComponentAllocations(1)[0];
        testNode.addComponent(testComponent, allocation.targetWeight, allocation.maxDelta, allocation.router);
        testNode.updateTargetReserveRatio(0.1 ether);

        vm.stopPrank();

        vm.label(testAsset, "TestAsset");
        vm.label(testQuoter, "TestQuoter");
        vm.label(testRouter, "TestRouter");
        vm.label(testRebalancer, "TestRebalancer");
        vm.label(testComponent, "TestComponent");
        vm.label(address(testRegistry), "TestRegistry");
        vm.label(address(testNode), "TestNode");

        Node nodeImpl = Node(address(node));
        maxDeposit = nodeImpl.maxDepositSize();
        rebalanceCooldown = nodeImpl.rebalanceCooldown();
    }

    function test_constructor() public view {
        // Check immutables
        assertEq(address(testNode.registry()), address(testRegistry));
        assertEq(testNode.asset(), testAsset);

        // Check initial state
        assertEq(testNode.name(), TEST_NAME);
        assertEq(testNode.symbol(), TEST_SYMBOL);
        assertTrue(testNode.isRouter(testRouter));

        // Check components
        address[] memory nodeComponents = testNode.getComponents();
        assertEq(nodeComponents.length, 1);
        assertEq(nodeComponents[0], testComponent);

        // Check component allocation
        ComponentAllocation memory componentAllocation = testNode.getComponentAllocation(testComponent);
        assertEq(componentAllocation.targetWeight, 0.9 ether);
        assertEq(componentAllocation.maxDelta, 0.01 ether);

        // Check reserve allocation
        uint64 reserveAllocation = testNode.targetReserveRatio();
        assertEq(reserveAllocation, 0.1 ether);

        // Check ownership
        assertEq(testNode.owner(), owner);
    }

    function test_addComponent() public {
        address newComponent = makeAddr("newComponent");
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        vm.mockCall(newComponent, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(testAsset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, newComponent), abi.encode(true)
        );

        vm.prank(owner);
        testNode.addComponent(newComponent, allocation.targetWeight, allocation.maxDelta, allocation.router);

        assertTrue(testNode.isComponent(newComponent));
        ComponentAllocation memory componentAllocation = testNode.getComponentAllocation(newComponent);
        assertEq(componentAllocation.targetWeight, allocation.targetWeight);
        assertEq(componentAllocation.maxDelta, allocation.maxDelta);

        // Verify components array
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2); // Original + new component
        assertEq(components[1], newComponent);
    }

    function test_addComponent_revert_ZeroAddress() public {
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        vm.prank(owner);
        vm.expectRevert();
        testNode.addComponent(address(0), allocation.targetWeight, allocation.maxDelta, allocation.router);
    }

    function test_addComponent_revert_AlreadySet() public {
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.addComponent(testComponent, allocation.targetWeight, allocation.maxDelta, allocation.router);
    }

    function test_removeComponent() public {
        // Add a second component first
        address secondComponent = makeAddr("secondComponent");
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        vm.mockCall(secondComponent, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(testAsset));

        vm.mockCall(
            address(router4626),
            abi.encodeWithSelector(IRouter.isWhitelisted.selector, secondComponent),
            abi.encode(true)
        );

        vm.startPrank(owner);
        testNode.addComponent(secondComponent, allocation.targetWeight, allocation.maxDelta, allocation.router);

        // Now remove the first component
        testNode.removeComponent(testComponent, false);
        vm.stopPrank();

        assertFalse(testNode.isComponent(testComponent));
        ComponentAllocation memory componentAllocation = testNode.getComponentAllocation(testComponent);
        assertEq(componentAllocation.targetWeight, 0);
        assertEq(componentAllocation.maxDelta, 0);

        // Verify components array
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 1);
        assertEq(components[0], secondComponent);
    }

    function test_removeComponent_revert_NotSet() public {
        address nonExistentComponent = makeAddr("nonExistentComponent");

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.removeComponent(nonExistentComponent, false);
    }

    function test_removeComponent_revert_NonZeroBalance() public {
        // Mock non-zero balance
        vm.mockCall(
            testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(100)
        );

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NonZeroBalance.selector);
        testNode.removeComponent(testComponent, false);
    }

    function test_removeComponent_revert_rebalanceWindowOpen() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(rebalancer, RegistryType.REBALANCER, true);
        testNode.addRebalancer(rebalancer);
        vm.stopPrank();

        vm.warp(block.timestamp + 24 hours);

        vm.prank(rebalancer);
        testNode.startRebalance();

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.RebalanceWindowOpen.selector);
        testNode.removeComponent(testComponent, false);
    }

    function test_removeComponent_revert_notOwner() public {
        vm.prank(owner);
        testNode.removeComponent(testComponent, false);

        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        testNode.removeComponent(testComponent, false);
    }

    function test_removeComponent_SingleComponent() public {
        // Mock zero balance first to avoid NonZeroBalance error
        vm.mockCall(testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));

        vm.prank(owner);
        testNode.removeComponent(testComponent, false);

        address[] memory components = testNode.getComponents();
        assertEq(components.length, 0);
        assertFalse(testNode.isComponent(testComponent));
    }

    function test_removeComponent_FirstOfMany() public {
        address component2 = makeAddr("component2");
        address component3 = makeAddr("component3");

        vm.mockCall(component2, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(testAsset));
        vm.mockCall(component3, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(testAsset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component2), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component3), abi.encode(true)
        );

        vm.startPrank(owner);
        testNode.addComponent(component2, 0.5 ether, 0.01 ether, address(router4626));
        testNode.addComponent(component3, 0.5 ether, 0.01 ether, address(router4626));

        // Remove first component
        testNode.removeComponent(testComponent, false);
        vm.stopPrank();

        // Verify array state
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2);
        assertTrue(components[0] == component2 || components[0] == component3);
        assertTrue(components[1] == component2 || components[1] == component3);
        assertFalse(components[0] == components[1]);
        assertFalse(testNode.isComponent(testComponent));
    }

    function test_removeComponent_MiddleOfMany() public {
        address component2 = makeAddr("component2");
        address component3 = makeAddr("component3");

        // Mock zero balances for all components
        vm.mockCall(testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));
        vm.mockCall(component2, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));
        vm.mockCall(component3, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));

        vm.mockCall(component2, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(testAsset));
        vm.mockCall(component3, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(testAsset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component2), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component3), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.getComponentAssets.selector, component2), abi.encode(0)
        );

        vm.startPrank(owner);
        testNode.addComponent(component2, 0.5 ether, 0.01 ether, address(router4626));
        testNode.addComponent(component3, 0.5 ether, 0.01 ether, address(router4626));

        // Remove middle component
        testNode.removeComponent(component2, false);
        vm.stopPrank();

        // Verify array state
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2);
        assertEq(components[0], testComponent);
        assertEq(components[1], component3);
        assertFalse(testNode.isComponent(component2));
    }

    function test_removeComponent_LastOfMany() public {
        address component2 = makeAddr("component2");
        address component3 = makeAddr("component3");

        // Mock zero balances for all components
        vm.mockCall(testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));
        vm.mockCall(component2, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));
        vm.mockCall(component3, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(0));

        vm.mockCall(component2, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(testAsset));
        vm.mockCall(component3, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(testAsset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component2), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component3), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.getComponentAssets.selector, component3), abi.encode(0)
        );

        vm.startPrank(owner);
        testNode.addComponent(component2, 0.5 ether, 0.01 ether, address(router4626));
        testNode.addComponent(component3, 0.5 ether, 0.01 ether, address(router4626));

        // Remove last component
        testNode.removeComponent(component3, false);
        vm.stopPrank();

        // Verify array state
        address[] memory components = testNode.getComponents();
        assertEq(components.length, 2);
        assertEq(components[0], testComponent);
        assertEq(components[1], component2);
        assertFalse(testNode.isComponent(component3));
    }

    function test_removeComponent_force_succeeds() public {
        assertTrue(testNode.isComponent(testComponent));

        // component has a balance
        vm.mockCall(
            testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(100 ether)
        );

        // component has been blacklisted on the router contract
        vm.mockCall(
            address(router4626),
            abi.encodeWithSelector(router4626.isBlacklisted.selector, address(testComponent)),
            abi.encode(true)
        );

        // node owner calls uses force bool = true
        vm.prank(owner);
        testNode.removeComponent(testComponent, true);
        assertFalse(testNode.isComponent(testComponent));
    }

    function test_removeComponent_force_reverts_notBlacklisted() public {
        assertTrue(testNode.isComponent(testComponent));

        vm.mockCall(
            testComponent, abi.encodeWithSelector(IERC20.balanceOf.selector, address(testNode)), abi.encode(100 ether)
        );

        // reverts because not blacklisted
        vm.expectRevert(ErrorsLib.NotBlacklisted.selector);
        vm.prank(owner);
        testNode.removeComponent(testComponent, true);

        // owner is same address as registry owner in this test
        // owner adds test component to router blacklist
        vm.prank(owner);
        router4626.setBlacklistStatus(testComponent, true);

        // force now succeeds
        vm.prank(owner);
        testNode.removeComponent(testComponent, true);
        assertFalse(testNode.isComponent(testComponent));
    }

    function test_updateComponentAllocation() public {
        ComponentAllocation memory newAllocation = ComponentAllocation({
            targetWeight: 0.8 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        vm.startPrank(owner);
        testNode.updateComponentAllocation(
            testComponent, newAllocation.targetWeight, newAllocation.maxDelta, newAllocation.router
        );

        ComponentAllocation memory componentAllocation = testNode.getComponentAllocation(testComponent);
        assertEq(componentAllocation.targetWeight, newAllocation.targetWeight);
        assertEq(componentAllocation.maxDelta, newAllocation.maxDelta);
    }

    function test_updateComponentAllocation_revert_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.updateComponentAllocation(makeAddr("nonexistent"), 0.8 ether, 0.01 ether, address(router4626));
    }

    function test_updateReserveAllocation() public {
        ComponentAllocation memory newAllocation = ComponentAllocation({
            targetWeight: 0.3 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        vm.prank(owner);
        testNode.updateTargetReserveRatio(newAllocation.targetWeight);

        uint64 reserveAllocation = testNode.targetReserveRatio();
        assertEq(reserveAllocation, newAllocation.targetWeight);
    }

    function test_addRouter() public {
        address newRouter = makeAddr("newRouter");
        vm.mockCall(
            address(testRegistry),
            abi.encodeWithSelector(INodeRegistry.isRegistryType.selector, newRouter, RegistryType.ROUTER),
            abi.encode(true)
        );
        vm.prank(owner);
        testNode.addRouter(newRouter);
        assertTrue(testNode.isRouter(newRouter));
    }

    function test_addRouter_revert_NotWhitelisted() public {
        address newRouter = makeAddr("notWhitelistedRouter");
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        testNode.addRouter(newRouter);
    }

    function test_addRouter_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.addRouter(address(0));
    }

    function test_addRouter_revert_AlreadySet() public {
        vm.startPrank(owner);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        node.addRouter(address(router4626));
    }

    function test_removeRouter() public {
        vm.prank(owner);
        testNode.removeRouter(testRouter);

        assertFalse(testNode.isRouter(testRouter));
    }

    function test_removeRouter_revert_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.removeRouter(makeAddr("nonexistent"));
    }

    function test_addRebalancer() public {
        address newRebalancer = makeAddr("newRebalancer");

        vm.mockCall(
            address(testRegistry),
            abi.encodeWithSelector(INodeRegistry.isRegistryType.selector, newRebalancer, RegistryType.REBALANCER),
            abi.encode(true)
        );

        vm.prank(owner);
        testNode.addRebalancer(newRebalancer);
        assertTrue(testNode.isRebalancer(newRebalancer));
    }

    function test_addRebalancer_revert_not_whitelisted() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        testNode.addRebalancer(makeAddr("notWhitelisted"));
    }

    function test_addRebalancer_revert_AlreadySet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.addRebalancer(testRebalancer);
    }

    function test_removeRebalancer() public {
        vm.prank(owner);
        testNode.removeRebalancer(testRebalancer);

        assertFalse(testNode.isRebalancer(testRebalancer));
    }

    function test_removeRebalancer_revert_NotSet() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotSet.selector);
        testNode.removeRebalancer(makeAddr("nonexistent"));
    }

    function test_setQuoter() public {
        address newQuoter = makeAddr("newQuoter");

        vm.startPrank(owner);
        INodeRegistry(testRegistry).setRegistryType(newQuoter, RegistryType.QUOTER, true);
        testNode.setQuoter(newQuoter);
        vm.stopPrank();
        assertEq(address(testNode.quoter()), newQuoter);
    }

    function test_setQuoter_revert_NotWhitelisted() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        testNode.setQuoter(makeAddr("notWhitelisted"));
    }

    function test_setLiquidationQueue() public {
        vm.mockCall(
            address(router4626),
            abi.encodeWithSelector(IRouter.isWhitelisted.selector, testComponent2),
            abi.encode(true)
        );

        vm.mockCall(
            address(router4626),
            abi.encodeWithSelector(IRouter.isWhitelisted.selector, testComponent3),
            abi.encode(true)
        );

        vm.startPrank(owner);
        testNode.addComponent(testComponent2, 0.5 ether, 0.01 ether, address(router4626));
        testNode.addComponent(testComponent3, 0.5 ether, 0.01 ether, address(router4626));

        address[] memory components = testNode.getComponents();
        assertEq(components.length, 3);
        assertEq(components[0], testComponent);
        assertEq(components[1], testComponent2);
        assertEq(components[2], testComponent3);

        testNode.setLiquidationQueue(components);
        vm.stopPrank();

        assertEq(testNode.getLiquidationsQueue()[0], testComponent);
        assertEq(testNode.getLiquidationsQueue()[1], testComponent2);
        assertEq(testNode.getLiquidationsQueue()[2], testComponent3);
    }

    function test_setLiquidationQueue_revert_invalidComponent() public {
        address[] memory components = new address[](1);
        components[0] = makeAddr("invalidComponent");

        assertFalse(testNode.isComponent(components[0]));
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.InvalidComponent.selector);
        testNode.setLiquidationQueue(components);
    }

    function test_setLiquidationQueue_revert_DuplicateComponent() public {
        address[] memory components = new address[](3);
        components[0] = testComponent;
        components[1] = testComponent2;
        components[2] = testComponent;

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.DuplicateComponent.selector);
        testNode.setLiquidationQueue(components);
    }

    function test_liquidationQueue_excludes_pendingDeposit() public {
        // sets async asset (7540) before sync (4626) in liquidity queue
        setup_asyncAsset_first();

        uint256 userWithdrawal = node.convertToAssets(node.pendingRedeemRequest(0, address(user)));
        uint256 erc7540Assets = liquidityPool.maxWithdraw(address(node));

        // assert node has non-zero pendingDeposit in liquidity pool but no assets
        assertEq(erc7540Assets, 0);
        assertGt(liquidityPool.pendingDepositRequest(0, address(node)), 0);

        // enforceLiquidityQueue ignores pendingDeposit
        vm.prank(rebalancer);
        uint256 assetsReturned = router4626.fulfillRedeemRequest(address(node), address(user), address(vault), 0);
        assertEq(assetsReturned, userWithdrawal);
    }

    function test_liquidationQueue_excludes_claimableDeposits() public {
        // sets async asset (7540) before sync (4626) in liquidity queue
        setup_asyncAsset_first();

        uint256 userWithdrawal = node.convertToAssets(node.pendingRedeemRequest(0, address(user)));
        uint256 erc7540Assets = liquidityPool.maxWithdraw(address(node));

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        // assert node has non-zero claimableDeposit in liquidity pool but no assets
        assertGt(liquidityPool.claimableDepositRequest(0, address(node)), 0);
        assertEq(erc7540Assets, 0);

        // enforceLiquidityQueue ignores claimableDeposit
        vm.prank(rebalancer);
        uint256 assetsReturned = router4626.fulfillRedeemRequest(address(node), address(user), address(vault), 0);
        assertEq(assetsReturned, userWithdrawal);
    }

    function test_liquidateQueue_excludes_shareBalance() public {
        // sets async asset (7540) before sync (4626) in liquidity queue
        setup_asyncAsset_first();

        uint256 userWithdrawal = node.convertToAssets(node.pendingRedeemRequest(0, address(user)));
        uint256 erc7540Assets = liquidityPool.maxWithdraw(address(node));

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.prank(rebalancer);
        router7540.mintClaimableShares(address(node), address(liquidityPool));

        // assert node has non-zero share balance in liquidity pool but no assets
        assertGt(liquidityPool.balanceOf(address(node)), 0);
        assertEq(erc7540Assets, 0);

        // enforceLiquidityQueue ignores share balance
        vm.prank(rebalancer);
        uint256 assetsReturned = router4626.fulfillRedeemRequest(address(node), address(user), address(vault), 0);
        assertEq(assetsReturned, userWithdrawal);
    }

    function test_liquidationQueue_excludes_pendingRedemptions() public {
        // sets async asset (7540) before sync (4626) in liquidity queue
        setup_asyncAsset_first();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        uint256 shares = router7540.mintClaimableShares(address(node), address(liquidityPool));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), shares);
        vm.stopPrank();

        uint256 userWithdrawal = node.convertToAssets(node.pendingRedeemRequest(0, address(user)));
        uint256 erc7540Assets = liquidityPool.maxWithdraw(address(node));

        // assert node has non-zero share pendingRedeem in liquidity pool but no assets
        assertGt(liquidityPool.pendingRedeemRequest(0, address(node)), 0);
        assertEq(erc7540Assets, 0);

        // enforceLiquidityQueue ignores share balance
        vm.prank(rebalancer);
        uint256 assetsReturned = router4626.fulfillRedeemRequest(address(node), address(user), address(vault), 0);
        assertEq(assetsReturned, userWithdrawal);
    }

    function test_liquidationQueue_includes_claimableRedemptions() public {
        // sets async asset (7540) before sync (4626) in liquidity queue
        setup_asyncAsset_first();

        vm.prank(testPoolManager);
        liquidityPool.processPendingDeposits();

        vm.startPrank(rebalancer);
        uint256 shares = router7540.mintClaimableShares(address(node), address(liquidityPool));
        router7540.requestAsyncWithdrawal(address(node), address(liquidityPool), shares);
        vm.stopPrank();

        vm.prank(testPoolManager);
        liquidityPool.processPendingRedemptions();

        // assert async asset has claimable balance
        uint256 erc7540Assets = liquidityPool.maxWithdraw(address(node));
        assertGt(erc7540Assets, 0);

        vm.prank(rebalancer);
        vm.expectRevert();
        router4626.fulfillRedeemRequest(address(node), address(user), address(vault), 0);
    }

    function setup_asyncAsset_first() public {
        address[] memory components = new address[](2);
        components[0] = address(liquidityPool);
        components[1] = address(vault);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.addRouter(address(router7540));
        router7540.setWhitelistStatus(address(liquidityPool), true);
        node.updateComponentAllocation(address(vault), 0.5 ether, 0.01 ether, address(router4626));
        node.addComponent(address(liquidityPool), 0.4 ether, 0.01 ether, address(router7540));
        node.setLiquidationQueue(components);
        vm.stopPrank();

        vm.warp(block.timestamp - 1 days);

        uint256 assets = 100 ether;
        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.deposit(assets, user);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        router7540.investInAsyncComponent(address(node), address(liquidityPool));
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        vm.startPrank(user);
        node.approve(address(node), 20 ether);
        node.requestRedeem(20 ether, user, user);
        vm.stopPrank();
    }

    function test_setRebalanceCooldown() public {
        uint64 newRebalanceCooldown = 1 days;
        vm.prank(owner);
        testNode.setRebalanceCooldown(newRebalanceCooldown);
        assertEq(testNode.rebalanceCooldown(), newRebalanceCooldown);
    }

    function test_setRebalanceCooldown_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.setRebalanceCooldown(1 days);
    }

    function test_setRebalanceWindow() public {
        uint64 newRebalanceWindow = 1 hours;
        vm.prank(owner);
        testNode.setRebalanceWindow(newRebalanceWindow);
        assertEq(testNode.rebalanceWindow(), newRebalanceWindow);
    }

    function test_setRebalanceWindow_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.setRebalanceWindow(1 hours);
    }

    function test_rebalanceCooldown() public {
        _seedNode(100 ether);

        // Cast the interface back to the concrete implementation
        Node node = Node(address(node));

        assertEq(node.rebalanceCooldown(), 23 hours);
        assertEq(node.rebalanceWindow(), 1 hours);

        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault), 0);

        // warp forward 30 mins so still inside rebalance window
        vm.warp(block.timestamp + 30 minutes);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault), 0);

        // warp forward 30 mins so outside rebalance window
        vm.warp(block.timestamp + 31 minutes);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert();
        router4626.invest(address(node), address(vault), 0);

        vm.prank(rebalancer);
        vm.expectRevert();
        node.startRebalance();

        // warp forward 1 day so cooldown is over
        vm.warp(block.timestamp + 1 days);

        vm.expectEmit(true, true, true, true);
        emit EventsLib.RebalanceStarted(block.timestamp, node.rebalanceWindow());

        vm.prank(rebalancer);
        node.startRebalance();
    }

    function test_enableSwingPricing() public {
        uint64 newMaxSwingFactor = 0.1 ether;

        vm.prank(owner);
        testNode.enableSwingPricing(true, newMaxSwingFactor);

        assertTrue(testNode.swingPricingEnabled());
        assertEq(testNode.maxSwingFactor(), newMaxSwingFactor);
    }

    function test_enableSwingPricing_disable() public {
        uint64 newMaxSwingFactor = 0.1 ether;

        // Enable first
        vm.prank(owner);
        testNode.enableSwingPricing(true, newMaxSwingFactor);

        // Then disable
        vm.prank(owner);
        testNode.enableSwingPricing(false, 0);
        assertFalse(testNode.swingPricingEnabled());
        assertEq(testNode.maxSwingFactor(), 0);
    }

    function test_enableSwingPricing_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.enableSwingPricing(true, 0.1 ether);
    }

    function test_setNodeOwnerFeeAddress() public {
        address newNodeOwnerFeeAddress = makeAddr("newNodeOwnerFeeAddress");
        vm.prank(owner);
        testNode.setNodeOwnerFeeAddress(newNodeOwnerFeeAddress);
        assertEq(testNode.nodeOwnerFeeAddress(), newNodeOwnerFeeAddress);
    }

    function test_setNodeOwnerFeeAddress_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.setNodeOwnerFeeAddress(makeAddr("newNodeOwnerFeeAddress"));
    }

    function test_setNodeOwnerFeeAddress_revert_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testNode.setNodeOwnerFeeAddress(address(0));
    }

    function test_setNodeOwnerFeeAddress_revert_AlreadySet() public {
        address newNodeOwnerFeeAddress = makeAddr("newNodeOwnerFeeAddress");
        vm.prank(owner);
        testNode.setNodeOwnerFeeAddress(newNodeOwnerFeeAddress);

        vm.prank(owner);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testNode.setNodeOwnerFeeAddress(newNodeOwnerFeeAddress);
    }

    function test_setAnnualManagementFee() public {
        uint64 newAnnualManagementFee = 0.01 ether;
        vm.prank(owner);
        testNode.setAnnualManagementFee(newAnnualManagementFee);
        assertEq(testNode.annualManagementFee(), newAnnualManagementFee);
    }

    function test_setAnnualManagementFee_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        testNode.setAnnualManagementFee(0.01 ether);
    }

    function test_setMaxDepositSize() public {
        uint256 newMaxDepositSize = 100 ether;
        vm.prank(owner);
        node.setMaxDepositSize(newMaxDepositSize);
        assertEq(node.maxDeposit(user), newMaxDepositSize);
    }

    function test_setMaxDepositSize_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        node.setMaxDepositSize(1);
    }

    function test_setMaxDepositSize_revert_ExceedsMaxDepositLimit() public {
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.ExceedsMaxDepositLimit.selector);
        node.setMaxDepositSize(1e36 + 1);
    }

    function test_rescueTokens() public {
        ERC20Mock rescueToken = new ERC20Mock("RescueToken", "RST");
        deal(address(rescueToken), address(node), 100 ether);

        assertEq(rescueToken.balanceOf(address(node)), 100 ether);

        vm.prank(owner);
        node.rescueTokens(address(rescueToken), address(user), 100 ether);
        assertEq(rescueToken.balanceOf(address(user)), 100 ether);
        assertEq(rescueToken.balanceOf(address(node)), 0);
    }

    function test_rescueTokens_revert_asset() public {
        deal(address(asset), address(node), 100 ether);
        vm.prank(owner);
        vm.expectRevert(ErrorsLib.InvalidToken.selector);
        node.rescueTokens(address(asset), address(user), 100 ether);
    }

    function test_rescueTokens_revert_component() public {
        vm.warp(block.timestamp + 1 days);
        deal(address(testComponent), address(node), 100 ether);

        vm.mockCall(testComponent, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, testComponent), abi.encode(true)
        );

        vm.startPrank(owner);
        node.addComponent(testComponent, 0.5 ether, 0.01 ether, address(router4626));
        vm.expectRevert(ErrorsLib.InvalidToken.selector);
        node.rescueTokens(address(testComponent), address(user), 100 ether);
    }

    function test_rescueTokens_revert_notOwner() public {
        vm.prank(user);
        vm.expectRevert();
        node.rescueTokens(address(asset), address(user), 100 ether);
    }

    function test_startRebalance() public {
        _seedNode(100 ether);

        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault), 0);

        assertEq(node.totalAssets(), 100 ether);
        assertEq(vault.totalAssets(), 90 ether);
        assertEq(vault.convertToAssets(vault.balanceOf(address(node))), 90 ether);

        // increase asset holdings of vault to 100 units, node being the only shareholder
        deal(address(asset), address(vault), 100 ether);
        assertEq(vault.totalAssets(), 100 ether);

        uint256 lastRebalance = Node(address(node)).lastRebalance();
        vm.warp(block.timestamp + lastRebalance + 1);

        vm.prank(rebalancer);
        node.startRebalance();

        // assert that calling startRebalance() has updated the cache correctly
        assertEq(vault.convertToAssets(vault.balanceOf(address(node))), 100 ether - 1);
        assertEq(node.totalAssets(), 110 ether - 1);
    }

    function test_startRebalance_revert_CooldownActive() public {
        uint256 lastRebalance = Node(address(node)).lastRebalance();
        assertEq(lastRebalance, block.timestamp);
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.CooldownActive.selector);
        node.startRebalance();
    }

    function test_startRebalance_revert_InvalidComponentRatios() public {
        vm.warp(block.timestamp + 1 days);

        vm.mockCall(testComponent, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, testComponent), abi.encode(true)
        );

        vm.prank(owner);
        node.addComponent(testComponent, 1.2 ether, 0.01 ether, address(router4626));

        vm.startPrank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidComponentRatios.selector);
        node.startRebalance();
    }

    function test_execute() public {
        deal(address(asset), address(node), 100 ether);

        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, makeAddr("recipient"), 100);

        vm.prank(address(router4626));
        bytes memory result = node.execute(address(asset), data);

        bool success = abi.decode(result, (bool));
        assertTrue(success, "ERC20 transfer should succeed");

        assertEq(asset.balanceOf(makeAddr("recipient")), 100);
    }

    function test_execute_revert_NotRouter() public {
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        testNode.execute(testAsset, "");
    }

    function test_execute_revert_ZeroAddress() public {
        deal(address(asset), address(node), 100 ether);

        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, makeAddr("recipient"), 100);

        vm.prank(address(router4626));
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        node.execute(address(0), data);
    }

    function test_execute_revert_NotRebalancing() public {
        // Setup a valid router and target
        address target = makeAddr("target");
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, address(this), 100);

        // Mock successful call to avoid other reverts
        vm.mockCall(target, 0, data, abi.encode(true));
        vm.warp(block.timestamp + 2 hours);

        // Try to execute as router
        vm.prank(testRouter);
        vm.expectRevert(ErrorsLib.RebalanceWindowClosed.selector);
        testNode.execute(target, data);
    }

    function test_payManagementFees() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        uint64 nodeFee = 0.01 ether; // takes 1% of totalAssets
        uint64 protocolFee = 0.2 ether; // takes 20% of annualManagementFee
        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(nodeFee);
        registry.setProtocolManagementFee(protocolFee);
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        uint256 amount = 100 ether;
        uint256 feeAmount = (nodeFee * amount) / 1e18;
        uint256 protocolFeeAmount = feeAmount * protocolFee / 1e18;
        uint256 nodeFeeAmount = feeAmount - protocolFeeAmount;

        _seedNode(amount);
        assertEq(node.totalAssets(), amount);

        vm.warp(block.timestamp + 365 days);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit EventsLib.ManagementFeePaid(node.nodeOwnerFeeAddress(), nodeFeeAmount, protocolFeeAmount);
        uint256 feeForPeriod = node.payManagementFees();
        vm.stopPrank();

        assertEq(feeForPeriod, protocolFeeAmount + nodeFeeAmount);
        assertEq(asset.balanceOf(address(ownerFeesRecipient)), nodeFeeAmount);
        assertEq(asset.balanceOf(address(protocolFeesRecipient)), protocolFeeAmount);
        assertEq(node.totalAssets(), 100 ether - feeForPeriod);
    }

    function test_payManagementFees_zeroFees() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0);
        registry.setProtocolManagementFee(0);
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);
        assertEq(node.totalAssets(), 100 ether);

        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        node.payManagementFees();

        assertEq(asset.balanceOf(address(ownerFeesRecipient)), 0);
        assertEq(asset.balanceOf(address(protocolFeesRecipient)), 0);
        assertEq(node.totalAssets(), 100 ether);
    }

    function test_payManagementFees_revert_NotEnoughAssets() public {
        _seedNode(100 ether);

        vm.prank(rebalancer);
        router4626.invest(address(node), address(vault), 0);

        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        vm.startPrank(owner);
        node.setAnnualManagementFee(0.2e18);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);

        vm.warp(block.timestamp + 365 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.NotEnoughAssetsToPayFees.selector,
                20 ether, // expected fee amount
                10 ether // actual balance
            )
        );

        node.payManagementFees();
    }

    function test_payManagementFees_revert_NotOwnerOrRebalancer() public {
        vm.prank(randomUser);
        vm.expectRevert(); // Will revert due to onlyOwnerOrRebalancer modifier
        node.payManagementFees();
    }

    function test_payManagementFees_revert_DuringRebalance() public {
        // Start a rebalance
        vm.warp(block.timestamp + 1 days);
        vm.prank(rebalancer);
        node.startRebalance();

        // Try to pay fees during rebalance
        vm.prank(owner);
        vm.expectRevert(); // Will revert due to onlyWhenNotRebalancing modifier
        node.payManagementFees();
    }

    function test_payManagementFees_NoFeesIfZeroAssets() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // 1% annual fee
        registry.setProtocolManagementFee(0.2e18); // 20% of management fee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();
        // Ensure no assets in node
        assertEq(node.totalAssets(), 0);

        vm.warp(block.timestamp + 1 days);

        vm.prank(owner);
        uint256 feesPaid = node.payManagementFees();

        assertEq(feesPaid, 0);
    }

    function test_payManagementFees_PartialYear() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // 1% annual fee
        registry.setProtocolManagementFee(0.2e18); // 20% of management fee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);

        // Warp 6 months into the future
        vm.warp(block.timestamp + 182.5 days);

        vm.prank(owner);
        uint256 feesPaid = node.payManagementFees();

        // Should be approximately 0.5 ether (half of 1% of 100 ether)
        assertApproxEqAbs(feesPaid, 0.5 ether, 0.01 ether);
        assertApproxEqAbs(asset.balanceOf(ownerFeesRecipient), 0.4 ether, 0.01 ether); // 80% of fees
        assertApproxEqAbs(asset.balanceOf(protocolFeesRecipient), 0.1 ether, 0.01 ether); // 20% of fees
    }

    function test_payManagementFees_MultiplePeriods() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // 1% annual fee
        registry.setProtocolManagementFee(0.2e18); // 20% of management fee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);

        // First period - 6 months
        vm.warp(block.timestamp + 182.5 days);
        vm.prank(owner);
        uint256 firstFeesPaid = node.payManagementFees();

        // Second period - 3 months
        vm.warp(block.timestamp + 91.25 days);
        vm.prank(owner);
        uint256 secondFeesPaid = node.payManagementFees();

        // First period should be ~0.5 ether, second should be ~0.25 ether
        assertApproxEqAbs(firstFeesPaid, 0.5 ether, 0.01 ether);
        assertApproxEqAbs(secondFeesPaid, 0.25 ether, 0.01 ether);
    }

    function test_payManagementFees_UpdatesTotalAssets() public {
        address ownerFeesRecipient = makeAddr("ownerFeesRecipient");
        address protocolFeesRecipient = makeAddr("protocolFeesRecipient");

        vm.startPrank(owner);
        node.setNodeOwnerFeeAddress(ownerFeesRecipient);
        node.setAnnualManagementFee(0.01e18); // 1% annual fee
        registry.setProtocolManagementFee(0.2e18); // 20% of management fee
        registry.setProtocolFeeAddress(protocolFeesRecipient);
        vm.stopPrank();

        _seedNode(100 ether);
        uint256 initialTotalAssets = node.totalAssets();

        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        uint256 feesPaid = node.payManagementFees();

        assertEq(node.totalAssets(), initialTotalAssets - feesPaid);
    }

    function test_subtractProtocolExecutionFee() public {
        // Seed the node with initial assets
        _seedNode(100 ether);
        uint256 initialTotalAssets = node.totalAssets();
        uint256 executionFee = 0.1 ether;

        // Mock the protocol fee address
        address protocolFeeAddress = makeAddr("protocolFeeAddress");
        vm.prank(owner);
        registry.setProtocolFeeAddress(protocolFeeAddress);

        // Call subtractProtocolExecutionFee as router
        vm.startPrank(address(router4626));
        vm.expectEmit(true, true, true, true);
        emit EventsLib.ExecutionFeeTaken(executionFee);
        node.subtractProtocolExecutionFee(executionFee);
        vm.stopPrank();

        // Verify fee was transferred and total assets was updated
        assertEq(asset.balanceOf(protocolFeeAddress), executionFee);
        assertEq(node.totalAssets(), initialTotalAssets - executionFee);
    }

    function test_subtractProtocolExecutionFee_revert_NotRouter() public {
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.subtractProtocolExecutionFee(0.1 ether);
    }

    function test_subtractProtocolExecutionFee_revert_NotEnoughAssets() public {
        // Seed the node with initial assets

        deal(address(asset), address(node), 0);

        uint256 executionFee = 1 ether;

        // Mock the protocol fee address
        address protocolFeeAddress = makeAddr("protocolFeeAddress");
        vm.prank(owner);
        registry.setProtocolFeeAddress(protocolFeeAddress);

        // Call subtractProtocolExecutionFee as router
        vm.prank(address(router4626));
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotEnoughAssetsToPayFees.selector, executionFee, 0));
        node.subtractProtocolExecutionFee(executionFee);
    }

    function test_updateTotalAssets() public {
        _seedNode(100 ether);

        // Mock quoter response
        uint256 expectedTotalAssets = 120 ether;

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.getComponentAssets.selector), abi.encode(20 ether)
        );

        vm.startPrank(rebalancer);
        vm.expectEmit(true, true, true, true);
        emit EventsLib.TotalAssetsUpdated(expectedTotalAssets);
        node.updateTotalAssets();
        vm.stopPrank();

        assertEq(node.totalAssets(), expectedTotalAssets);
    }

    function test_updateTotalAssets_revert_NotRebalancer() public {
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.updateTotalAssets();
    }

    function test_fulfillRedeemFromReserve() public {
        deal(address(asset), address(user), 100 ether);
        _userDeposits(user, 100 ether);

        _userRequestsRedeem(user, 50 ether);

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        assertEq(node.balanceOf(user), 50 ether);
        assertEq(node.totalAssets(), 50 ether);
        assertEq(node.totalSupply(), node.convertToShares(50 ether));

        assertEq(asset.balanceOf(address(escrow)), 50 ether);
        assertEq(node.claimableRedeemRequest(0, user), 50 ether);
    }

    function test_fulfillRedeemFromReserve_revert_NoPendingRedeemRequest() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NoPendingRedeemRequest.selector);
        node.fulfillRedeemFromReserve(user);
    }

    function test_fulfillRedeemFromReserve_ExceedsAvailableReserve() public {
        deal(address(asset), address(user), 100 ether);
        _userDeposits(user, 100 ether);

        assertEq(node.totalAssets(), 100 ether);
        assertEq(asset.balanceOf(address(user)), 0);

        vm.prank(rebalancer);
        uint256 investedAssets = router4626.invest(address(node), address(vault), 0);
        uint256 remainingReserve = node.totalAssets() - investedAssets;

        assertEq(investedAssets, 90 ether);
        assertEq(remainingReserve, 10 ether);

        _userRequestsRedeem(user, 50 ether);

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        assertEq(node.claimableRedeemRequest(0, user), 10 ether);
        assertEq(node.pendingRedeemRequest(0, user), 40 ether);
        assertEq(asset.balanceOf(address(escrow)), 10 ether);
        assertEq(node.balanceOf(address(escrow)), 40 ether);
    }

    function test_fulfillRedeemFromReserve_revert_onlyRebalancer() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.fulfillRedeemFromReserve(user);
    }

    function test_fulfillRedeemFromReserve_revert_onlyWhenRebalancing() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.RebalanceWindowClosed.selector);
        node.fulfillRedeemFromReserve(user);
    }

    function test_finalizeRedemption() public {
        _seedNode(100 ether);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 sharesToRedeem = node.convertToShares(50 ether);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        uint256 totalAssetsBefore = node.totalAssets();
        uint256 sharesAtEscowBefore = node.balanceOf(address(escrow));

        (uint256 pendingBefore, uint256 claimableBefore, uint256 claimableAssetsBefore, uint256 sharesAdjustedBefore) =
            node.requests(user);

        vm.prank(address(router4626));
        node.finalizeRedemption(user, 50 ether, sharesToRedeem, sharesToRedeem);

        (uint256 pendingAfter, uint256 claimableAfter, uint256 claimableAssetsAfter, uint256 sharesAdjustedAfter) =
            node.requests(user);

        // assert vault state and variables are correctly updated
        assertEq(Node(address(node)).sharesExiting(), 0);
        assertEq(node.totalAssets(), totalAssetsBefore - 50 ether);
        assertEq(node.balanceOf(address(escrow)), sharesAtEscowBefore - sharesToRedeem);

        // assert request state is correctly updated
        assertEq(pendingAfter, pendingBefore - sharesToRedeem);
        assertEq(claimableAfter, claimableBefore + sharesToRedeem);
        assertEq(claimableAssetsAfter, claimableAssetsBefore + 50 ether);
        assertEq(sharesAdjustedAfter, sharesAdjustedBefore - sharesToRedeem);
    }

    function test_finalizeRedemption_revert_onlyRouter() public {
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        node.finalizeRedemption(user, 50 ether, 100, 100);
    }

    // ERC-7540 FUNCTIONS

    function test_requestRedeem() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 shares = node.balanceOf(address(user)) / 10;
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        assertEq(node.pendingRedeemRequest(0, user), shares);
    }

    function test_requestRedeem_revert_InvalidOwner() public {
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.InvalidOwner.selector);
        node.requestRedeem(1 ether, user, randomUser);
        vm.stopPrank();
    }

    function test_requestRedeem_revert_InsufficientBalance() public {
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.InsufficientBalance.selector);
        node.requestRedeem(1 ether, user, user);
        vm.stopPrank();
    }

    function test_requestRedeem_revert_ZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        node.requestRedeem(0, user, user);
        vm.stopPrank();
    }

    function test_requestRedeem_updates_requestState() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 shares = node.balanceOf(address(user)) / 10;

        uint256 pending;
        uint256 claimable;
        uint256 claimableAssets;
        uint256 sharesAdjusted;

        (pending, claimable, claimableAssets, sharesAdjusted) = node.requests(user);

        assertEq(pending, 0);
        assertEq(claimable, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, 0);

        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        (pending, claimable, claimableAssets, sharesAdjusted) = node.requests(user);

        assertEq(pending, shares);
        assertEq(claimable, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, shares); // no swing factor applied
    }

    function test_pendingRedeemRequest() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 shares = node.balanceOf(address(user)) / 10;
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        assertEq(node.pendingRedeemRequest(0, user), shares);
    }

    function test_pendingRedeemRequest_isZero() public view {
        assertEq(node.pendingRedeemRequest(0, user), 0);
    }

    function test_claimableRedeemRequest() public {
        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        uint256 shares = node.balanceOf(address(user)) / 10;
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        assertEq(node.claimableRedeemRequest(0, user), shares);
    }

    function test_claimableRedeemRequest_isZero() public view {
        assertEq(node.claimableRedeemRequest(0, user), 0);
    }

    function test_setOperator() public {
        vm.prank(user);
        node.setOperator(address(rebalancer), true);
        assertTrue(node.isOperator(user, address(rebalancer)));
    }

    function test_setOperator_RevertIf_Self() public {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.CannotSetSelfAsOperator.selector);
        node.setOperator(user, true);
    }

    function test_setOperator_EmitEvent() public {
        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Operator.OperatorSet(user, address(randomUser), true);
        node.setOperator(address(randomUser), true);
    }

    function test_supportsInterface() public view {
        assertTrue(node.supportsInterface(type(IERC7540Redeem).interfaceId));
        assertTrue(node.supportsInterface(type(IERC7540Operator).interfaceId));
        assertTrue(node.supportsInterface(type(IERC7575).interfaceId));
        assertTrue(node.supportsInterface(type(IERC165).interfaceId));
    }

    function test_supportsInterface_ReturnsFalseForUnsupportedInterface() public view {
        bytes4 unsupportedInterfaceId = 0xffffffff; // An example of an unsupported interface ID
        assertFalse(node.supportsInterface(unsupportedInterfaceId));
    }

    // ERC-4626 FUNCTIONS

    function test_deposit(uint256 assets) public {
        vm.assume(assets < maxDeposit);
        uint256 shares = node.convertToShares(assets);

        deal(address(asset), address(user), assets);
        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.deposit(assets, user);
        vm.stopPrank();

        _verifySuccessfulEntry(user, assets, shares);
    }

    function test_deposit_revert_ExceedsMaxDeposit() public {
        deal(address(asset), address(user), maxDeposit + 1);
        vm.startPrank(user);
        asset.approve(address(node), maxDeposit + 1);
        vm.expectRevert(ErrorsLib.ExceedsMaxDeposit.selector);
        node.deposit(maxDeposit + 1, user);
        vm.stopPrank();
    }

    function test_mint(uint256 assets) public {
        vm.assume(assets < maxDeposit);

        uint256 shares = node.convertToShares(assets);
        uint256 expectedShares = node.previewDeposit(assets);
        assertEq(shares, expectedShares);

        deal(address(asset), address(user), assets);
        vm.startPrank(user);
        asset.approve(address(node), assets);
        node.mint(shares, user);
        vm.stopPrank();

        _verifySuccessfulEntry(user, assets, shares);
    }

    function test_mint_revert_ExceedsMaxMint() public {
        deal(address(asset), address(user), maxDeposit + 1);
        vm.startPrank(user);
        asset.approve(address(node), maxDeposit + 1);
        vm.expectRevert(ErrorsLib.ExceedsMaxMint.selector);
        node.mint(maxDeposit + 1, user);
        vm.stopPrank();
    }

    function test_withdraw_base(uint256 depositAmount, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1, 1e36);
        seedAmount = bound(seedAmount, 1, 1e36);
        _seedNode(seedAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        uint256 shares = node.balanceOf(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 maxWithdraw = node.maxWithdraw(user);
        uint256 maxRedeem = node.maxRedeem(user);

        vm.prank(user);
        uint256 withdrawShares = node.withdraw(maxWithdraw, user, user);

        assertEq(withdrawShares, maxRedeem);
        assertEq(asset.balanceOf(user), maxWithdraw);
        assertEq(node.maxWithdraw(user), 0);
        assertEq(node.maxRedeem(user), 0);

        (uint256 pending, uint256 claimable, uint256 claimableAssets, uint256 sharesAdjusted) = node.requests(user);
        assertEq(pending, 0);
        assertEq(claimable, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, 0);
    }

    function test_withdraw(uint256 depositAmount, uint256 seedAmount, uint256 amountToWithdraw) public {
        depositAmount = bound(depositAmount, 1, 1e36);
        amountToWithdraw = bound(amountToWithdraw, 1, depositAmount);
        seedAmount = bound(seedAmount, 1, 1e36);
        _seedNode(seedAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount);
        asset.approve(address(node), depositAmount);
        uint256 shares = node.deposit(depositAmount, user);
        uint256 sharesToRedeem = node.convertToShares(amountToWithdraw);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        vm.prank(user);
        uint256 assetsReceived = node.withdraw(amountToWithdraw, user, user);

        assertEq(assetsReceived, amountToWithdraw);
        assertEq(node.balanceOf(user), shares - sharesToRedeem);
        assertEq(asset.balanceOf(user), amountToWithdraw);
    }

    function test_withdraw_edge_cases() public {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        node.withdraw(0, user, user);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.InvalidController.selector);
        node.withdraw(1 ether, user, randomUser);

        uint256 depositAmount = 1 ether;
        _seedNode(depositAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        uint256 shares = node.balanceOf(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 maxWithdraw = node.maxWithdraw(user);

        // try to withdraw more than available
        vm.prank(user);
        vm.expectRevert(ErrorsLib.ExceedsMaxWithdraw.selector);
        node.withdraw(maxWithdraw + 1, user, user);
    }

    function test_redeem(uint256 depositAmount, uint256 sharesToRedeem, uint256 seedAmount) public {
        depositAmount = bound(depositAmount, 1, 1e36);
        sharesToRedeem = bound(sharesToRedeem, 1, depositAmount);
        seedAmount = bound(seedAmount, 1, 1e36);
        _seedNode(seedAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        uint256 shares = node.balanceOf(user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        uint256 expectedAssets = node.convertToAssets(sharesToRedeem);

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        vm.prank(user);
        uint256 assetsReceived = node.redeem(sharesToRedeem, user, user);

        assertEq(assetsReceived, expectedAssets);
        assertEq(node.balanceOf(user), shares - sharesToRedeem);
        assertEq(asset.balanceOf(user), expectedAssets);
    }

    function test_redeem_edge_cases() public {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        node.redeem(0, user, user);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.InvalidController.selector);
        node.redeem(1 ether, user, randomUser);

        uint256 depositAmount = 1 ether;
        _seedNode(depositAmount);

        vm.startPrank(user);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        uint256 shares = node.balanceOf(user);
        node.approve(address(node), shares);
        node.requestRedeem(shares, user, user);
        vm.stopPrank();

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        uint256 maxRedeem = node.maxRedeem(user);

        // try to redeem more than available
        vm.prank(user);
        vm.expectRevert(ErrorsLib.ExceedsMaxRedeem.selector);
        node.redeem(maxRedeem + 1, user, user);
    }

    function test_totalAssets(uint256 depositAmount, uint256 seedAmount, uint256 additionalDeposit) public {
        depositAmount = bound(depositAmount, 1, 1e30);
        additionalDeposit = bound(additionalDeposit, 1, 1e36 - depositAmount);
        seedAmount = bound(seedAmount, 1, 1e36);

        assertEq(node.totalAssets(), 0);

        _seedNode(seedAmount);

        assertEq(node.totalAssets(), seedAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount + additionalDeposit);
        asset.approve(address(node), type(uint256).max);
        node.deposit(depositAmount, user);
        vm.stopPrank();

        assertEq(node.totalAssets(), depositAmount + seedAmount);

        vm.prank(rebalancer);
        node.updateTotalAssets();

        assertEq(node.totalAssets(), depositAmount + seedAmount);

        vm.prank(user);
        node.deposit(additionalDeposit, user);

        assertEq(node.totalAssets(), depositAmount + seedAmount + additionalDeposit);
    }

    function test_convertToShares() public {
        assertEq(node.totalAssets(), 0);
        assertEq(node.totalSupply(), 0);
        assertEq(node.convertToShares(1e18), 1e18);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        assertEq(node.convertToShares(1 ether), 1 ether);

        deal(address(asset), address(node), 200 ether);

        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.convertToShares(2 ether), 1 ether);
    }

    function test_convertToAssets() public {
        assertEq(node.totalAssets(), 0);
        assertEq(node.totalSupply(), 0);
        assertEq(node.convertToAssets(1e18), 1e18);

        vm.startPrank(user);
        asset.approve(address(node), 100 ether);
        node.deposit(100 ether, user);
        vm.stopPrank();

        assertEq(node.convertToAssets(1 ether), 1 ether);

        deal(address(asset), address(node), 200 ether);
        vm.prank(rebalancer);
        node.updateTotalAssets();
        assertEq(node.convertToAssets(1 ether), 2 ether - 1); // minus 1 to account for rounding
    }

    function test_maxDeposit() public {
        assertEq(node.maxDeposit(user), maxDeposit);

        vm.warp(block.timestamp + 25 hours);
        assertEq(node.maxDeposit(user), 0);
    }

    function test_maxMint() public {
        assertEq(node.maxMint(user), maxDeposit);

        vm.warp(block.timestamp + 25 hours);
        assertEq(node.maxMint(user), 0);
    }

    function test_previewDeposit(uint256 amount) public view {
        assertEq(node.convertToShares(amount), node.previewDeposit(amount));
    }

    function test_previewMint(uint256 amount) public view {
        assertEq(node.convertToAssets(amount), node.previewMint(amount));
    }

    function test_previewWithdraw() public {
        vm.expectRevert();
        node.previewWithdraw(1);
    }

    function test_previewRedeem() public {
        vm.expectRevert();
        node.previewRedeem(1);
    }

    // VIEW FUNCTIONS

    function test_requests(uint256 depositAmount, uint256 seedAmount, uint256 sharesToRedeem) public {
        depositAmount = bound(depositAmount, 1, 1e36);
        sharesToRedeem = bound(depositAmount, 1, depositAmount);
        seedAmount = bound(seedAmount, 1, 1e36);
        _seedNode(depositAmount);

        vm.startPrank(user);
        deal(address(asset), user, depositAmount);
        asset.approve(address(node), depositAmount);
        node.deposit(depositAmount, user);
        node.approve(address(node), sharesToRedeem);
        node.requestRedeem(sharesToRedeem, user, user);
        vm.stopPrank();

        (uint256 pending, uint256 claimable, uint256 claimableAssets, uint256 sharesAdjusted) = node.requests(user);
        assertEq(pending, sharesToRedeem);
        assertEq(claimable, 0);
        assertEq(claimableAssets, 0);
        assertEq(sharesAdjusted, sharesToRedeem);

        vm.prank(rebalancer);
        node.fulfillRedeemFromReserve(user);

        (pending, claimable, claimableAssets, sharesAdjusted) = node.requests(user);
        assertEq(pending, 0);
        assertEq(claimable, sharesToRedeem);
        assertEq(claimableAssets, node.convertToAssets(sharesToRedeem));
        assertEq(sharesAdjusted, 0);
    }

    function test_getLiquidationsQueue() public {
        vm.warp(block.timestamp + 1 days);

        ERC4626Mock component1 = new ERC4626Mock(address(testAsset));
        ERC4626Mock component2 = new ERC4626Mock(address(testAsset));
        ERC4626Mock component3 = new ERC4626Mock(address(testAsset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component1), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component2), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component3), abi.encode(true)
        );

        vm.startPrank(owner);
        testNode.addComponent(address(component3), 0.3 ether, 0.01 ether, address(router4626));
        testNode.addComponent(address(component2), 0.3 ether, 0.01 ether, address(router4626));
        testNode.addComponent(address(component1), 0.4 ether, 0.01 ether, address(router4626));
        vm.stopPrank();

        // incorrect component order on purpose
        address[] memory expectedQueue = new address[](3);
        expectedQueue[0] = address(component1);
        expectedQueue[1] = address(component3);
        expectedQueue[2] = address(component2);

        vm.prank(owner);
        testNode.setLiquidationQueue(expectedQueue);

        address[] memory liquidationQueue = testNode.getLiquidationsQueue();
        assertEq(liquidationQueue.length, expectedQueue.length);
        for (uint256 i = 0; i < expectedQueue.length; i++) {
            assertEq(liquidationQueue[i], expectedQueue[i]);
        }
    }

    function test_getLiquidationsQueueLength() public {
        assertEq(testNode.getLiquidationsQueue().length, 0);

        ERC4626Mock component1 = new ERC4626Mock(address(testAsset));
        ERC4626Mock component2 = new ERC4626Mock(address(testAsset));
        ERC4626Mock component3 = new ERC4626Mock(address(testAsset));

        address[] memory queue = new address[](3);
        queue[0] = address(component1);
        queue[1] = address(component2);
        queue[2] = address(component3);

        vm.warp(block.timestamp + 1 days);

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component1), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component2), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component3), abi.encode(true)
        );

        vm.startPrank(owner);
        testNode.addComponent(address(component1), 0.4 ether, 0.01 ether, address(router4626));
        testNode.addComponent(address(component2), 0.3 ether, 0.01 ether, address(router4626));
        testNode.addComponent(address(component3), 0.3 ether, 0.01 ether, address(router4626));
        testNode.setLiquidationQueue(queue);
        vm.stopPrank();

        assertEq(testNode.getLiquidationsQueue().length, 3);
    }

    // todo: fix this test
    function test_getSharesExiting(uint256 depositAmount, uint256 redeemAmount) public {
        _seedNode(100 ether);
        depositAmount = bound(depositAmount, 1 ether, 1e36);
        deal(address(asset), user, depositAmount);

        uint256 shares = _userDeposits(user, depositAmount);
        redeemAmount = bound(redeemAmount, 1, shares);

        if (redeemAmount > shares) {
            redeemAmount = shares;
        }
        uint256 sharesExiting = Node(address(node)).sharesExiting();
        assertEq(sharesExiting, 0);

        vm.startPrank(user);
        node.approve(address(node), redeemAmount);
        node.requestRedeem(redeemAmount, user, user);
        vm.stopPrank();

        sharesExiting = Node(address(node)).sharesExiting();
        assertEq(sharesExiting, redeemAmount);
    }

    function test_targetReserveRatio(uint64 targetWeight) public {
        targetWeight = uint64(bound(targetWeight, 0.01 ether, 0.99 ether));

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        node.updateTargetReserveRatio(targetWeight);
        node.updateComponentAllocation(address(vault), 1e18 - targetWeight, 0.01 ether, address(router4626));
        vm.stopPrank();

        vm.prank(rebalancer);
        node.startRebalance(); // if this runs ratios are validated

        uint64 reserveAllocation = node.targetReserveRatio();
        assertEq(reserveAllocation, targetWeight);
    }

    function test_getComponents() public {
        vm.warp(block.timestamp + 1 days);

        address component1 = makeAddr("component1");
        address component2 = makeAddr("component2");

        vm.mockCall(component1, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));
        vm.mockCall(component2, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component1), abi.encode(true)
        );

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component2), abi.encode(true)
        );

        vm.startPrank(owner);
        node.addComponent(component1, 0.5 ether, 0.01 ether, address(router4626));
        node.addComponent(component2, 0.5 ether, 0.01 ether, address(router4626));
        vm.stopPrank();

        address[] memory components = node.getComponents();
        assertEq(components.length, 3); // there's an extra component defined in the base test
        assertEq(components[1], component1);
        assertEq(components[2], component2);
    }

    function test_getComponentRatio(uint64 ratio) public {
        vm.warp(block.timestamp + 1 days);

        address component = makeAddr("component");
        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: ratio,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        vm.mockCall(component, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, component), abi.encode(true)
        );

        vm.prank(owner);
        node.addComponent(component, allocation.targetWeight, allocation.maxDelta, allocation.router);

        ComponentAllocation memory componentAllocation = node.getComponentAllocation(component);
        assertEq(componentAllocation.targetWeight, allocation.targetWeight);
    }

    function test_isComponent() public {
        address randomAddress = makeAddr("random");
        assertFalse(node.isComponent(randomAddress));

        vm.warp(block.timestamp + 1 days);

        vm.mockCall(testComponent, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, testComponent), abi.encode(true)
        );

        vm.prank(owner);
        node.addComponent(testComponent, 0.5 ether, 0.01 ether, address(router4626));
        assertTrue(node.isComponent(testComponent));
    }

    function test_getMaxDelta(uint64 delta) public {
        vm.warp(block.timestamp + 2 days);

        ComponentAllocation memory allocation = ComponentAllocation({
            targetWeight: 0.5 ether,
            maxDelta: delta,
            router: address(router4626),
            isComponent: true
        });

        vm.mockCall(testComponent, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));

        vm.mockCall(
            address(router4626), abi.encodeWithSelector(IRouter.isWhitelisted.selector, testComponent), abi.encode(true)
        );

        vm.prank(owner);
        node.addComponent(testComponent, allocation.targetWeight, allocation.maxDelta, allocation.router);

        ComponentAllocation memory componentAllocation = node.getComponentAllocation(testComponent);
        assertEq(componentAllocation.maxDelta, delta);
        assertEq(componentAllocation.maxDelta, allocation.maxDelta);
    }

    function test_isCacheValid() public view {
        assertEq(block.timestamp, Node(address(node)).lastRebalance());
        assertEq(node.isCacheValid(), true);
    }

    function test_isCacheValid_isFalse() public {
        uint256 lastRebalance = Node(address(node)).lastRebalance();
        vm.warp(block.timestamp + lastRebalance + 1);
        assertFalse(node.isCacheValid());
    }

    // INTERNAL FUNCTIONS

    function test_validateController_RevertIfNotController() public {
        _seedNode(100 ether);
        _userDeposits(user, 100 ether);

        vm.startPrank(user);
        node.approve(address(node), 1 ether);
        node.requestRedeem(1 ether, user, user);
        vm.stopPrank();

        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidController.selector);
        node.redeem(1 ether, randomUser, user);
    }

    function test_validateOwner_withOperator() public {
        _seedNode(100 ether);
        _userDeposits(user, 100 ether);

        address operator = makeAddr("operator");

        vm.startPrank(user);
        node.approve(operator, 1 ether);
        node.setOperator(operator, true);
        vm.stopPrank();

        vm.prank(operator);
        node.requestRedeem(1 ether, user, user);
    }

    function test_validateOwner_ERC20InsufficientAllowance() public {
        _seedNode(100 ether);
        _userDeposits(user, 100 ether);

        address operator = makeAddr("operator");

        vm.startPrank(user);
        node.setOperator(operator, true);
        vm.stopPrank();

        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InsufficientAllowance(address,uint256,uint256)", operator, 0, 1 ether)
        );
        node.requestRedeem(1 ether, user, user);
        vm.stopPrank();
    }

    function test_getCashAfterRedemptions() public {
        _userDeposits(user, 100 ether);
        assertEq(node.getCashAfterRedemptions(), 100 ether);

        vm.startPrank(user);
        node.approve(address(node), 1 ether);
        node.requestRedeem(1 ether, user, user);
        vm.stopPrank();

        assertEq(node.getCashAfterRedemptions(), 99 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(rebalancer);
        node.startRebalance();
        router4626.invest(address(node), address(vault), 0);
        vm.stopPrank();

        vm.startPrank(user);
        node.approve(address(node), 90 ether);
        node.requestRedeem(90 ether, user, user);
        vm.stopPrank();

        assertEq(node.getCashAfterRedemptions(), 0);
    }

    function test_addPolicies() external {
        bytes32[] memory proof = new bytes32[](0);
        bool[] memory proofFlags = new bool[](0);

        bytes4[] memory firstSigs = new bytes4[](2);
        firstSigs[0] = 0x00000001;
        firstSigs[1] = 0x00000002;
        address[] memory firstPolicies = new address[](2);
        firstPolicies[0] = address(0x11);
        firstPolicies[1] = address(0x11);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        node.addPolicies(proof, proofFlags, firstSigs, firstPolicies);

        vm.startPrank(owner);

        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(INodeRegistry.verifyPolicies.selector, proof, proofFlags, firstSigs, firstPolicies),
            abi.encode(false)
        );
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        node.addPolicies(proof, proofFlags, firstSigs, firstPolicies);

        // assume policies are whitelisted
        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(INodeRegistry.verifyPolicies.selector, proof, proofFlags, firstSigs, firstPolicies),
            abi.encode(true)
        );
        vm.expectEmit(true, true, true, true);
        emit EventsLib.PoliciesAdded(firstSigs, firstPolicies);
        node.addPolicies(proof, proofFlags, firstSigs, firstPolicies);

        assertEq(node.getPolicies(0x00000001).length, 1);
        assertEq(node.getPolicies(0x00000002).length, 1);
        assertEq(node.getPolicies(0x00000001)[0], address(0x11));
        assertEq(node.getPolicies(0x00000002)[0], address(0x11));
        assertTrue(node.isSigPolicy(0x00000001, address(0x11)));
        assertTrue(node.isSigPolicy(0x00000002, address(0x11)));

        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.PolicyAlreadyAdded.selector, bytes4(0x00000001), address(0x11))
        );
        node.addPolicies(proof, proofFlags, firstSigs, firstPolicies);

        bytes4[] memory secondSigs = new bytes4[](1);
        secondSigs[0] = 0x00000001;
        address[] memory secondPolicies = new address[](1);
        secondPolicies[0] = address(0x12);

        // assume policies are whitelisted
        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(INodeRegistry.verifyPolicies.selector, proof, proofFlags, secondSigs, secondPolicies),
            abi.encode(true)
        );
        vm.expectEmit(true, true, true, true);
        emit EventsLib.PoliciesAdded(secondSigs, secondPolicies);
        node.addPolicies(proof, proofFlags, secondSigs, secondPolicies);

        assertEq(node.getPolicies(0x00000001).length, 2);
        assertEq(node.getPolicies(0x00000002).length, 1);
        assertEq(node.getPolicies(0x00000001)[0], address(0x11));
        assertEq(node.getPolicies(0x00000001)[1], address(0x12));
        assertEq(node.getPolicies(0x00000002)[0], address(0x11));
    }

    function test_removePolicies() external {
        bytes32[] memory proof = new bytes32[](0);
        bool[] memory proofFlags = new bool[](0);

        bytes4[] memory sigs = new bytes4[](3);
        sigs[0] = 0x00000001;
        sigs[1] = 0x00000001;
        sigs[2] = 0x00000002;
        address[] memory policies = new address[](3);
        policies[0] = address(0x11);
        policies[1] = address(0x12);
        policies[2] = address(0x11);

        vm.startPrank(owner);

        // assume policies are whitelisted
        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(INodeRegistry.verifyPolicies.selector, proof, proofFlags, sigs, policies),
            abi.encode(true)
        );
        node.addPolicies(proof, proofFlags, sigs, policies);

        bytes4[] memory removeSigs = new bytes4[](1);
        removeSigs[0] = 0x00000001;
        address[] memory removePolicies = new address[](1);
        removePolicies[0] = address(0x11);
        vm.expectEmit(true, true, true, true);
        emit EventsLib.PoliciesRemoved(removeSigs, removePolicies);
        node.removePolicies(removeSigs, removePolicies);

        assertEq(node.getPolicies(0x00000001).length, 1);
        assertEq(node.getPolicies(0x00000002).length, 1);
        assertEq(node.getPolicies(0x00000001)[0], address(0x12));
        assertEq(node.getPolicies(0x00000002)[0], address(0x11));
        assertFalse(node.isSigPolicy(0x00000001, address(0x11)));

        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.PolicyAlreadyRemoved.selector, removeSigs[0], removePolicies[0])
        );
        node.removePolicies(removeSigs, removePolicies);
    }

    // HELPER FUNCTIONS
    function _verifySuccessfulEntry(address user, uint256 assets, uint256 shares) internal view {
        assertEq(asset.balanceOf(address(node)), assets);
        assertEq(asset.balanceOf(user), 0);
        assertEq(node.balanceOf(user), shares);
        assertEq(asset.balanceOf(address(escrow)), 0);
    }
}
