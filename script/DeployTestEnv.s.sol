// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";
import {SwingPricingV1} from "src/pricers/SwingPricingV1.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";

contract DeployTestEnv is Script {
    bytes32 public constant SALT = bytes32(uint256(1));
    address owner;
    address user;
    address user2;
    address user3;

    function run() external {
        // Get deployer address
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        address rebalancer = makeAddr("rebalancer");
        owner = makeAddr("owner");
        user = makeAddr("user");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.startBroadcast();

        // Deploy core contracts
        NodeRegistry registry = new NodeRegistry(deployer);
        NodeFactory factory = new NodeFactory(address(registry));
        QuoterV1 quoter = new QuoterV1(address(registry));
        SwingPricingV1 pricer = new SwingPricingV1(address(registry));
        ERC4626Router router = new ERC4626Router(address(registry));

        // Deploy test tokens
        ERC20Mock asset = new ERC20Mock("Test Token", "TEST");
        ERC4626Mock vault = new ERC4626Mock(address(asset));

        // Initialize registry
        registry.initialize(
            _toArray(address(factory)),
            _toArray(address(router)),
            _toArray(address(quoter)),
            _toArray(address(rebalancer))
        );

        // Configure components
        quoter.setErc4626(address(vault), true);
        router.setWhitelistStatus(address(vault), true);

        // Deploy node
        (INode node,) = factory.deployFullNode(
            "Test Node",
            "TNODE",
            address(asset),
            deployer,
            rebalancer,
            address(quoter),
            _toArray(address(router)),
            _toArray(address(vault)),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation(),
            SALT
        );

        node.enableSwingPricing(true, address(pricer), 2e16);

        // Fund test addresses
        asset.mint(owner, 1000000 ether);
        asset.mint(user, 1000000 ether);
        asset.mint(user2, 1000000 ether);
        asset.mint(user3, 1000000 ether);
        asset.mint(deployer, 1000000 ether);

        vm.stopBroadcast();
    }

    function _toArray(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }

    function _defaultComponentAllocations(uint256 count) internal pure returns (ComponentAllocation[] memory) {
        ComponentAllocation[] memory allocations = new ComponentAllocation[](count);
        allocations[0] = ComponentAllocation({targetWeight: 0.9 ether});
        return allocations;
    }

    function _defaultReserveAllocation() internal pure returns (ComponentAllocation memory) {
        return ComponentAllocation({targetWeight: 0.1 ether});
    }
}
