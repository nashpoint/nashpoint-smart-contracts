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
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {console2} from "forge-std/console2.sol";

contract NodeFactoryTest is BaseTest {
    NodeRegistry public testRegistry;
    NodeFactory public testFactory;

    ERC20Mock public testAsset;
    ERC4626Mock public testComponent;
    ERC4626Router public testRouter;
    address public testQuoter;
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
        testQuoter = makeAddr("testQuoter");
        testRebalancer = makeAddr("testRebalancer");
        testComponent = new ERC4626Mock(address(testAsset));
        testRouter = new ERC4626Router(address(testRegistry));
        nodeImplementation = address(new Node(address(testRegistry)));
        testFactory = new NodeFactory(address(testRegistry), nodeImplementation);

        vm.startPrank(owner);

        testRegistry.setRegistryType(address(testFactory), RegistryType.FACTORY, true);
        testRegistry.setRegistryType(address(testRouter), RegistryType.ROUTER, true);
        testRegistry.setRegistryType(address(testRebalancer), RegistryType.REBALANCER, true);
        testRegistry.setRegistryType(address(testQuoter), RegistryType.QUOTER, true);

        testRouter.setWhitelistStatus(address(testComponent), true);

        vm.stopPrank();

        vm.label(address(testAsset), "TestAsset");
        vm.label(testQuoter, "TestQuoter");
        vm.label(address(testRouter), "TestRouter");
        vm.label(testRebalancer, "TestRebalancer");
        vm.label(address(testComponent), "TestComponent");
        vm.label(address(testRegistry), "TestRegistry");
        vm.label(address(testFactory), "TestFactory");
    }

    function _defaultPayload() internal view returns (bytes[] memory) {
        bytes[] memory payload = new bytes[](5);
        payload[0] = abi.encodeWithSelector(INode.addRouter.selector, address(testRouter));
        payload[1] = abi.encodeWithSelector(INode.addRebalancer.selector, testRebalancer);
        payload[2] = abi.encodeWithSelector(
            INode.addComponent.selector, address(testComponent), 0.5 ether, 0.01 ether, address(testRouter)
        );
        payload[3] = abi.encodeWithSelector(INode.updateTargetReserveRatio.selector, 0.1 ether);
        payload[4] = abi.encodeWithSelector(INode.setQuoter.selector, address(testQuoter));
        return payload;
    }

    function test_deployFullNode_success() public {
        vm.prank(owner);
        vm.expectEmit(false, true, true, true);

        emit NodeFactory.NodeCreated(address(0), address(testAsset), TEST_NAME, TEST_SYMBOL, owner);

        (INode node,) = testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), owner), _defaultPayload(), TEST_SALT
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
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(0), owner), _defaultPayload(), TEST_SALT
        );

        // Test zero owner address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), address(0)), _defaultPayload(), TEST_SALT
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
            TEST_SALT
        );
    }

    function test_deployFullNode_revert_router_NotWhitelisted() public {
        vm.prank(owner);
        testRegistry.setRegistryType(address(testRouter), RegistryType.ROUTER, false);

        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        testFactory.deployFullNode(
            NodeInitArgs(TEST_NAME, TEST_SYMBOL, address(testAsset), owner), _defaultPayload(), TEST_SALT
        );
    }
}
