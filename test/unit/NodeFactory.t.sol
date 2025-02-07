// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseTest} from "../BaseTest.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {DeployParams} from "src/interfaces/INodeFactory.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {console2} from "forge-std/console2.sol";

contract TestFactoryHarness is NodeFactory {
    constructor(address registry) NodeFactory(registry) {}

    function createNode(
        string memory name,
        string memory symbol,
        address asset,
        address owner,
        address[] memory routers,
        address[] memory components,
        ComponentAllocation[] memory componentAllocations,
        uint64 targetReserveRatio,
        bytes32 salt
    ) public returns (INode node) {
        salt = keccak256(abi.encodePacked(msg.sender, salt));
        node =
            _createNode(name, symbol, asset, owner, routers, components, componentAllocations, targetReserveRatio, salt);
    }
}

contract NodeFactoryTest is BaseTest {
    NodeRegistry public testRegistry;
    TestFactoryHarness public testFactory;

    ERC20Mock public testAsset;
    ERC4626Mock public testComponent;
    ERC4626Router public testRouter;
    address public testQuoter;
    address public testRebalancer;

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

        testAsset = new ERC20Mock("Test Asset", "TASSET");
        testQuoter = makeAddr("testQuoter");
        testRebalancer = makeAddr("testRebalancer");
        testComponent = new ERC4626Mock(address(testAsset));
        testRegistry = new NodeRegistry(owner);
        testRouter = new ERC4626Router(address(testRegistry));
        testFactory = new TestFactoryHarness(address(testRegistry));

        vm.startPrank(owner);
        testRegistry.initialize(
            _toArray(address(testFactory)),
            _toArray(address(testRouter)),
            _toArray(testQuoter),
            _toArray(testRebalancer),
            protocolFeesAddress,
            0,
            0,
            0.99 ether
        );

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

    function test_createNode() public {
        bytes32 expectedSalt = keccak256(abi.encodePacked(owner, TEST_SALT));
        vm.prank(owner);
        vm.expectEmit(false, true, true, true);

        emit EventsLib.NodeCreated(address(0), address(testAsset), TEST_NAME, TEST_SYMBOL, owner, expectedSalt);

        INode node = testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            address(testAsset),
            owner,
            _toArray(address(testRouter)),
            _toArray(address(testComponent)),
            getTestComponentAllocations(1),
            0.5 ether,
            TEST_SALT
        );

        assertTrue(testRegistry.isNode(address(node)));
    }

    function test_deployFullNode() public {
        bytes32 expectedSalt = keccak256(abi.encodePacked(owner, TEST_SALT));
        vm.prank(owner);
        vm.expectEmit(false, true, true, true);

        emit EventsLib.NodeCreated(
            address(0),
            address(testAsset),
            TEST_NAME,
            TEST_SYMBOL,
            address(testFactory), // owner is factory during creation
            expectedSalt
        );

        DeployParams memory params = DeployParams({
            name: TEST_NAME,
            symbol: TEST_SYMBOL,
            asset: address(testAsset),
            owner: owner,
            rebalancer: testRebalancer,
            quoter: testQuoter,
            routers: _toArray(address(testRouter)),
            components: _toArray(address(testComponent)),
            componentAllocations: getTestComponentAllocations(1),
            targetReserveRatio: 0.5 ether,
            salt: TEST_SALT
        });

        (INode node, address escrow) = testFactory.deployFullNode(params);

        assertTrue(testRegistry.isNode(address(node)));
        assertEq(Ownable(address(node)).owner(), owner);
        assertEq(address(node.escrow()), address(escrow));
    }

    function test_constructor_revert_ZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new NodeFactory(address(0));
    }

    function test_createNode_revert_ZeroAddress() public {
        // Test zero asset address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            address(0),
            owner,
            _toArray(address(testRouter)),
            _toArray(address(testComponent)),
            getTestComponentAllocations(1),
            0.1 ether,
            TEST_SALT
        );

        // Test zero owner address
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            address(testAsset),
            address(0),
            _toArray(address(testRouter)),
            _toArray(address(testComponent)),
            getTestComponentAllocations(1),
            0.1 ether,
            TEST_SALT
        );
    }

    function test_createNode_revert_InvalidName() public {
        vm.expectRevert(ErrorsLib.InvalidName.selector);
        testFactory.createNode(
            "", // empty name
            TEST_SYMBOL,
            address(testAsset),
            owner,
            _toArray(address(testRouter)),
            _toArray(address(testComponent)),
            getTestComponentAllocations(1),
            0.1 ether,
            TEST_SALT
        );
    }

    function test_createNode_revert_InvalidSymbol() public {
        vm.expectRevert(ErrorsLib.InvalidSymbol.selector);
        testFactory.createNode(
            TEST_NAME,
            "", // empty symbol
            address(testAsset),
            owner,
            _toArray(address(testRouter)),
            _toArray(address(testComponent)),
            getTestComponentAllocations(1),
            0.1 ether,
            TEST_SALT
        );
    }

    function test_createNode_revert_LengthMismatch() public {
        address[] memory components = new address[](2);
        components[0] = address(testComponent);
        components[1] = makeAddr("testComponent2");

        vm.expectRevert(ErrorsLib.LengthMismatch.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            address(testAsset),
            owner,
            _toArray(address(testRouter)),
            components,
            getTestComponentAllocations(1), // Only 1 allocation for 2 components
            0.1 ether,
            TEST_SALT
        );
    }

    function test_createNode_revert_NotRegistered() public {
        // Test unregistered router
        address unregisteredRouter = makeAddr("unregisteredRouter");
        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        testFactory.createNode(
            TEST_NAME,
            TEST_SYMBOL,
            address(testAsset),
            owner,
            _toArray(unregisteredRouter),
            _toArray(address(testComponent)),
            getTestComponentAllocations(1),
            0.1 ether,
            TEST_SALT
        );
    }
}
