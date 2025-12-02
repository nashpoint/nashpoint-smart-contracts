// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseTest} from "../BaseTest.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {Node} from "src/Node.sol";
import {NodeRegistry, RegistryType} from "src/NodeRegistry.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {INode, ComponentAllocation, NodeInitArgs} from "src/interfaces/INode.sol";
import {IERC7575} from "src/interfaces/IERC7575.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {console2} from "forge-std/console2.sol";
import {SetupCall} from "src/interfaces/INodeFactory.sol";

contract MockPolicyConfigurator {
    address public configuredNode;
    uint256 public configuredValue;
    uint256 public callCount;

    function configure(address node, uint256 value) external {
        configuredNode = node;
        configuredValue = value;
        callCount++;
    }
}

contract NodeFactoryTest is BaseTest {
    NodeRegistry public testRegistry;
    NodeFactory public testFactory;

    ERC20Mock public testAsset;
    ERC4626Mock public testComponent;
    ERC4626Router public testRouter;
    address public testRebalancer;
    address nodeImplementation;

    string constant TEST_NAME = "Test Node";
    string constant TEST_SYMBOL = "TNODE";
    bytes32 constant TEST_SALT = bytes32(uint256(1));

    function getTestReserveAllocation() internal view returns (ComponentAllocation memory) {
        return ComponentAllocation({
            targetWeight: 0.5 ether,
            maxDelta: 0.01 ether,
            router: address(testRouter),
            isComponent: true
        });
    }

    function getTestComponentAllocations(uint256 count)
        internal
        view
        returns (ComponentAllocation[] memory allocations)
    {
        allocations = new ComponentAllocation[](count);
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = ComponentAllocation({
                targetWeight: 0.5 ether,
                maxDelta: 0.01 ether,
                router: address(testRouter),
                isComponent: true
            });
        }
    }

    function setUp() public override {
        super.setUp();

        address registryImpl = address(new NodeRegistry());
        testRegistry = NodeRegistry(
            address(
                new ERC1967Proxy(
                    registryImpl,
                    abi.encodeWithSelector(
                        NodeRegistry.initialize.selector, owner, protocolFeesAddress, 0, 0, 0.99 ether
                    )
                )
            )
        );

        testAsset = new ERC20Mock("Test Asset", "TASSET");
        testRebalancer = makeAddr("testRebalancer");
        testComponent = new ERC4626Mock(address(testAsset));
        testRouter = new ERC4626Router(address(testRegistry));
        nodeImplementation = address(new Node(address(testRegistry)));
        testFactory = new NodeFactory(address(testRegistry), nodeImplementation);

        vm.startPrank(owner);

        testRegistry.setRegistryType(address(testFactory), RegistryType.FACTORY, true);
        testRegistry.setRegistryType(address(testRouter), RegistryType.ROUTER, true);
        testRegistry.setRegistryType(address(testRebalancer), RegistryType.REBALANCER, true);

        testRouter.setWhitelistStatus(address(testComponent), true);

        vm.stopPrank();

        vm.label(address(testAsset), "TestAsset");
        vm.label(address(testRouter), "TestRouter");
        vm.label(testRebalancer, "TestRebalancer");
        vm.label(address(testComponent), "TestComponent");
        vm.label(address(testRegistry), "TestRegistry");
        vm.label(address(testFactory), "TestFactory");
    }

    function _defaultPayload() internal view returns (bytes[] memory) {
        bytes[] memory payload = new bytes[](4);
        payload[0] = abi.encodeWithSelector(INode.addRouter.selector, address(testRouter));
        payload[1] = abi.encodeWithSelector(INode.addRebalancer.selector, testRebalancer);
        payload[2] = abi.encodeWithSelector(
            INode.addComponent.selector, address(testComponent), 0.5 ether, 0.01 ether, address(testRouter)
        );
        payload[3] = abi.encodeWithSelector(INode.updateTargetReserveRatio.selector, 0.1 ether);
        return payload;
    }

    function _defaultSetupCalls() internal pure returns (SetupCall[] memory) {
        return new SetupCall[](0);
    }

    function test_deployFullNode_executesSetupCalls() public {
        MockPolicyConfigurator configurator = new MockPolicyConfigurator();
        uint256 customValue = 123;

        address predictedNode = testFactory.predictDeterministicAddress(TEST_SALT, owner);

        SetupCall[] memory setupCalls = new SetupCall[](1);
        setupCalls[0] = SetupCall({
            target: address(configurator),
            payload: abi.encodeWithSelector(MockPolicyConfigurator.configure.selector, predictedNode, customValue)
        });

        vm.startPrank(owner);
        testRegistry.updateSetupCallWhitelist(address(configurator), true);
        (INode node,) = testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), owner), _defaultPayload(), setupCalls, TEST_SALT
        );
        vm.stopPrank();

        assertEq(address(node), predictedNode);
        assertEq(configurator.configuredNode(), address(node));
        assertEq(configurator.configuredValue(), customValue);
        assertEq(configurator.callCount(), 1);
    }

    function test_deployFullNode_setupCalls_cannotCallRegistry() public {
        SetupCall[] memory setupCalls = new SetupCall[](1);
        setupCalls[0] = SetupCall({
            target: address(testRegistry),
            payload: abi.encodeWithSelector(NodeRegistry.addNode.selector, address(123))
        });

        vm.prank(owner);
        vm.expectRevert(NodeFactory.Forbidden.selector);
        testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), owner), _defaultPayload(), setupCalls, TEST_SALT
        );
    }

    function test_deployFullNode_setupCalls_cannotCallNotWhitelisted() public {
        SetupCall[] memory setupCalls = new SetupCall[](1);
        setupCalls[0] = SetupCall({
            target: address(0x1234),
            payload: abi.encodeWithSelector(NodeRegistry.addNode.selector, address(123))
        });

        vm.prank(owner);
        vm.expectRevert(NodeFactory.Forbidden.selector);
        testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), owner), _defaultPayload(), setupCalls, TEST_SALT
        );
    }

    function test_deployFullNode_setupCallsPullFundsAndDeposit() public {
        uint256 depositAmount = 1_000 ether;
        testAsset.mint(owner, depositAmount);

        // if asset will support permit this approval call can be omitted
        vm.prank(owner);
        testAsset.approve(address(testFactory), depositAmount);

        address predictedNode = testFactory.predictDeterministicAddress(TEST_SALT, owner);

        SetupCall[] memory setupCalls = new SetupCall[](2);
        setupCalls[0] = SetupCall({
            target: address(testAsset),
            payload: abi.encodeWithSelector(testAsset.transferFrom.selector, owner, address(testFactory), depositAmount)
        });
        setupCalls[1] = SetupCall({
            target: address(testAsset),
            payload: abi.encodeWithSelector(testAsset.approve.selector, predictedNode, depositAmount)
        });

        vm.startPrank(owner);
        testRegistry.updateSetupCallWhitelist(address(testAsset), true);
        bytes[] memory payload = new bytes[](1);
        payload[0] = abi.encodeWithSelector(IERC7575.deposit.selector, depositAmount, owner);
        (INode node,) = testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), owner), payload, setupCalls, TEST_SALT
        );
        vm.stopPrank();

        assertEq(testAsset.balanceOf(address(testFactory)), 0);
        assertEq(testAsset.balanceOf(address(node)), depositAmount);
        assertEq(node.balanceOf(owner), depositAmount);
    }

    function test_deployFullNode_success() public {
        vm.prank(owner);
        vm.expectEmit(false, true, true, true);

        emit NodeFactory.NodeCreated(address(0), address(testAsset), TEST_NAME, TEST_SYMBOL, owner);

        (INode node,) = testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), owner),
            _defaultPayload(),
            _defaultSetupCalls(),
            TEST_SALT
        );

        assertTrue(testRegistry.isNode(address(node)));
    }

    function test_constructor_revert_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new NodeFactory(address(0), address(0));
    }

    function test_deployFullNode_revert_ZeroAddress() public {
        // Test zero asset address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(0), owner), _defaultPayload(), _defaultSetupCalls(), TEST_SALT
        );

        // Test zero owner address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), address(0)),
            _defaultPayload(),
            _defaultSetupCalls(),
            TEST_SALT
        );
    }

    function test_deployFullNode_revert_InvalidName() public {
        vm.expectRevert(ErrorsLib.InvalidName.selector);
        testFactory.deployFullNode(
            NodeInitArgs(
                "", // empty name
                TEST_SYMBOL,
                address(testAsset),
                owner
            ),
            _defaultPayload(),
            _defaultSetupCalls(),
            TEST_SALT
        );
    }

    function test_deployFullNode_revert_InvalidSymbol() public {
        vm.expectRevert(ErrorsLib.InvalidSymbol.selector);
        testFactory.deployFullNode(
            NodeInitArgs(
                TEST_NAME,
                "", // empty symbol
                address(testAsset),
                owner
            ),
            _defaultPayload(),
            _defaultSetupCalls(),
            TEST_SALT
        );
    }

    function test_deployFullNode_revert_router_NotWhitelisted() public {
        vm.prank(owner);
        testRegistry.setRegistryType(address(testRouter), RegistryType.ROUTER, false);

        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), owner),
            _defaultPayload(),
            _defaultSetupCalls(),
            TEST_SALT
        );
    }
}
