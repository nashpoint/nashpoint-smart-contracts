// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {DeployParams} from "src/interfaces/INodeFactory.sol";

contract DeployTestEnv is Script {
    bytes32 public constant SALT = bytes32(uint256(1));

    function run() external {
        // Get deployer address
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        address rebalancer = vm.addr(vm.envUint("REBALANCER"));
        address user = vm.addr(vm.envUint("USER"));

        // Store the actual private key:
        uint256 rebalancerKey = vm.envUint("REBALANCER");

        vm.startBroadcast();

        // Deploy core contracts
        NodeRegistry registry = new NodeRegistry(deployer);
        NodeFactory factory = new NodeFactory(address(registry));
        QuoterV1 quoter = new QuoterV1(address(registry));
        ERC4626Router router4626 = new ERC4626Router(address(registry));

        // Deploy test tokens
        ERC20Mock asset = new ERC20Mock("Test Token", "TEST");
        ERC4626Mock vault = new ERC4626Mock(address(asset));

        // Initialize registry
        registry.initialize(
            _toArray(address(factory)),
            _toArray(address(router4626)),
            _toArray(address(quoter)),
            _toArray(address(rebalancer)),
            address(0),
            0,
            0,
            0.01 ether
        );

        // Configure components
        router4626.setWhitelistStatus(address(vault), true);

        DeployParams memory params = DeployParams({
            name: "Test Node",
            symbol: "TNODE",
            asset: address(asset),
            owner: deployer,
            rebalancer: rebalancer,
            quoter: address(quoter),
            routers: _toArray(address(router4626)),
            components: _toArray(address(vault)),
            componentAllocations: _defaultComponentAllocations(1, address(router4626)),
            targetReserveRatio: 0.1 ether,
            salt: SALT
        });
        // Deploy node
        (INode node,) = factory.deployFullNode(params);

        // Fund test addresses
        asset.mint(user, 1000000 ether);
        asset.mint(deployer, 1000000 ether);
        asset.approve(address(node), type(uint256).max);
        node.deposit(1000 ether, deployer);
        node.enableSwingPricing(true, 2e16);
        vm.stopBroadcast();

        vm.startBroadcast(rebalancerKey);
        router4626.invest(address(node), address(vault), 0);
        vm.stopBroadcast();
    }

    function _toArray(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }

    function _defaultComponentAllocations(uint256 count, address router)
        internal
        pure
        returns (ComponentAllocation[] memory)
    {
        ComponentAllocation[] memory allocations = new ComponentAllocation[](count);
        allocations[0] =
            ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether, router: router, isComponent: true});
        return allocations;
    }

    function _defaultReserveAllocation(address router) internal pure returns (ComponentAllocation memory) {
        return ComponentAllocation({targetWeight: 0.1 ether, maxDelta: 0.01 ether, router: router, isComponent: true});
    }
}
