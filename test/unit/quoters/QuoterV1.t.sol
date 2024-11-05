// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";
import {Node} from "src/Node.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {QueueManager} from "src/QueueManager.sol";

contract QuoterV1Test is BaseTest {
    QuoterV1 public quoterV1;
    ERC4626Mock public vault;
    
    address public testNode;

    function setUp() public override {
        super.setUp();
        
        // Deploy mock ERC4626 vault
        vault = new ERC4626Mock(address(asset));

        // Deploy quoter
        quoterV1 = new QuoterV1(address(registry));

        // Add this test contract as a factory
        vm.prank(owner);
        registry.addFactory(address(this));

        // Setup labels
        vm.label(address(vault), "Vault");
        vm.label(address(quoterV1), "QuoterV1");
    }

    function test_initialize() public {
        address[] memory erc4626Components = new address[](1);
        erc4626Components[0] = address(vault);
        
        address[] memory erc7540Components = new address[](0);

        vm.prank(owner);
        quoterV1.initialize(erc4626Components, erc7540Components);

        assertTrue(quoterV1.isErc4626(address(vault)));
        assertTrue(quoterV1.isInitialized());
    }

    function test_initialize_RevertIf_AlreadyInitialized() public {
        vm.startPrank(owner);
        
        quoterV1.initialize(new address[](0), new address[](0));
        
        vm.expectRevert(ErrorsLib.AlreadyInitialized.selector);
        quoterV1.initialize(new address[](0), new address[](0));
        
        vm.stopPrank();
    }

    function test_initialize_RevertIf_NotRegistryOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        quoterV1.initialize(new address[](0), new address[](0));
    }

    function test_setErc4626() public {
        vm.prank(owner);
        quoterV1.setErc4626(address(vault), true);
        assertTrue(quoterV1.isErc4626(address(vault)));
    }

    function test_setErc4626_RevertIf_NotRegistryOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.NotRegistryOwner.selector);
        quoterV1.setErc4626(address(vault), true);
    }

    function test_getPrice_WithReserveOnly() public {
        // Deploy and setup node
        
        // requestDeposit and fulfillDepositRequest to get asset into Node

        // test getPrice
    }

    function test_getPrice_WithErc4626() public {
        // Deploy and setup node with mock ERC4626 as component
        Node node = deployNodeWithVault();
        registry.addNode(address(node));
        
        // requestDeposit and fulfillDepositRequest to get asset into Node

        // Rebalance asset into erc4626mock with ERC4626Router
        
        // test getPrice
    }

    function test_getPrice_ZeroSupply() public {
        Node node = deployBasicNode();
        registry.addNode(address(node));
        
        deal(address(asset), address(node), 100 ether);
        assertEq(quoterV1.getPrice(address(node)), 0);
    }

    function test_getPrice_RevertIf_NotRegistered() public {
        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        quoterV1.getPrice(randomUser);
    }

    function test_getTotalAssets_RevertIf_InvalidComponent() public {
        // Deploy node with unregistered component type
        address[] memory components = new address[](1);
        components[0] = address(vault);
        
        Node node = deployNodeWithComponents(components);
        registry.addNode(address(node));
        
        vm.expectRevert(ErrorsLib.InvalidComponent.selector);
        quoterV1.getTotalAssets(address(node));
    }

    // Helper functions
    function deployBasicNode() internal returns (Node) {
        return new Node(
            address(registry),
            "Test Node",
            "NODE",
            address(asset),
            address(quoterV1),
            owner,
            address(0), // rebalancer
            new address[](0), // routers
            new address[](0), // components
            new ComponentAllocation[](0), // allocations
            ComponentAllocation(0, 0, 0) // reserveAllocation: min, max, target
        );
    }

    function deployNodeWithVault() internal returns (Node) {
        address[] memory components = new address[](1);
        components[0] = address(vault);
        
        ComponentAllocation[] memory allocations = new ComponentAllocation[](1);
        allocations[0] = ComponentAllocation(
            0, // minimumWeight
            type(uint256).max, // maximumWeight
            type(uint256).max / 2 // targetWeight (set to half of max)
        );
        
        vm.prank(owner);
        quoterV1.setErc4626(address(vault), true);
        
        return new Node(
            address(registry),
            "Test Node",
            "NODE",
            address(asset),
            address(quoterV1),
            owner,
            address(0),
            new address[](0),
            components,
            allocations,
            ComponentAllocation(0, type(uint256).max, type(uint256).max / 2) // min, max, target
        );
    }

    function deployNodeWithComponents(address[] memory components) internal returns (Node) {
        ComponentAllocation[] memory allocations = new ComponentAllocation[](components.length);
        for(uint i = 0; i < components.length; i++) {
            allocations[i] = ComponentAllocation(
                0, // minimumWeight
                type(uint256).max, // maximumWeight
                type(uint256).max / 2 // targetWeight
            );
        }
        
        return new Node(
            address(registry),
            "Test Node",
            "NODE",
            address(asset),
            address(quoterV1),
            owner,
            address(0),
            new address[](0),
            components,
            allocations,
            ComponentAllocation(0, type(uint256).max, type(uint256).max / 2) // min, max, target
        );
    }
}
