// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.28;

// import {Script} from "forge-std/Script.sol";
// import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
// import {Node} from "src/Node.sol";
// import {NodeFactory} from "src/NodeFactory.sol";
// import {NodeRegistry} from "src/NodeRegistry.sol";
// import {QuoterV1} from "src/quoters/QuoterV1.sol";
// import {ERC4626Router} from "src/routers/ERC4626Router.sol";
// import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
// import {INode, ComponentAllocation} from "src/interfaces/INode.sol";

// import {console2} from "forge-std/Test.sol";

// contract DeployTestEnv is Script {
//     bytes32 public constant SALT = bytes32(uint256(1));
//     address feeRecipient;
//     ERC4626Mock vault2;
//     ERC4626Mock vault3;

//     function run() external {
//         // Read environment values
//         uint256 privateKey = vm.envUint("PRIVATE_KEY");
//         uint256 rebalancerKey = vm.envUint("REBALANCER");
//         address deployer = vm.addr(privateKey);
//         address rebalancer = vm.addr(rebalancerKey);
//         address user = vm.addr(vm.envUint("USER"));

//         feeRecipient = makeAddr("feeRecipient");

//         // Begin the first broadcast
//         vm.startBroadcast();

//         // Deploy core contracts
//         (NodeRegistry registry, NodeFactory factory, QuoterV1 quoter, ERC4626Router router4626) =
//             deployCoreContracts(deployer);

//         // Deploy test tokens
//         (ERC20Mock asset, ERC4626Mock vault) = deployTestTokens();

//         // Initialize the registry with the deployed addresses
//         initializeRegistry(registry, factory, router4626, quoter, rebalancer);

//         // Configure the router for the vault
//         configureComponents(router4626, vault);

//         // Deploy the node using the factory
//         INode node = deployNode(factory, asset, deployer, vault, router4626, quoter, rebalancer);

//         // Fund test addresses and deposit into the node
//         fundTestAddresses(asset, node, deployer, user);

//         registry.setProtocolMaxSwingFactor(10e16);
//         router4626.setWhitelistStatus(address(vault2), true);
//         router4626.setWhitelistStatus(address(vault3), true);

//         // Enable swing pricing
//         node.enableSwingPricing(true, 2e16);
//         node.setRebalanceCooldown(0);
//         node.updateComponentAllocation(address(vault), 0.3 ether, 0, address(router4626));
//         node.addComponent(address(vault2), 0.3 ether, 0, address(router4626));
//         node.addComponent(address(vault3), 0.3 ether, 0, address(router4626));
//         vm.stopBroadcast();

//         // Rebalance the node
//         vm.startBroadcast(rebalancerKey);
//         node.startRebalance();
//         router4626.invest(address(node), address(vault), 0);
//         router4626.invest(address(node), address(vault2), 0);
//         router4626.invest(address(node), address(vault3), 0);
//         vm.stopBroadcast();

//         console2.log("Node deployed and initialized");
//         console2.log("Node address: %s", address(node));
//         console2.log("Asset address: %s", address(asset));
//         console2.log("Vault address: %s", address(vault));
//         console2.log("Vault2 address: %s", address(vault2));
//         console2.log("Vault3 address: %s", address(vault3));
//         console2.log("User address: %s", user);
//         console2.log("Deployer address: %s", deployer);
//         console2.log("Rebalancer address: %s", rebalancer);
//         console2.log("ERC4626Router address: %s", address(router4626));
//     }

//     // Deploy core contracts and return them.
//     function deployCoreContracts(address deployer)
//         internal
//         returns (NodeRegistry registry, NodeFactory factory, QuoterV1 quoter, ERC4626Router router4626)
//     {
//         registry = new NodeRegistry(deployer);
//         address nodeImplementation = address(new Node(address(registry)));
//         factory = new NodeFactory(address(registry), nodeImplementation);
//         quoter = new QuoterV1(address(registry));
//         router4626 = new ERC4626Router(address(registry));
//     }

//     // Deploy test tokens.
//     function deployTestTokens() internal returns (ERC20Mock asset, ERC4626Mock vault) {
//         asset = new ERC20Mock("Test Token", "TEST");
//         vault = new ERC4626Mock(address(asset));
//         vault2 = new ERC4626Mock(address(asset));
//         vault3 = new ERC4626Mock(address(asset));
//     }

//     // Initialize the registry using helper functions.
//     function initializeRegistry(
//         NodeRegistry registry,
//         NodeFactory factory,
//         ERC4626Router router4626,
//         QuoterV1 quoter,
//         address rebalancer
//     ) internal {
//         registry.initialize(
//             _toArray(address(factory)),
//             _toArray(address(router4626)),
//             _toArray(address(quoter)),
//             _toArray(rebalancer),
//             feeRecipient,
//             0,
//             0,
//             0.01 ether
//         );
//     }

//     // Configure the router so that the vault is whitelisted.
//     function configureComponents(ERC4626Router router4626, ERC4626Mock vault) internal {
//         router4626.setWhitelistStatus(address(vault), true);
//     }

//     // Deploy a node using the factory.
//     function deployNode(
//         NodeFactory factory,
//         ERC20Mock asset,
//         address ownerAddress,
//         ERC4626Mock vault,
//         ERC4626Router router4626,
//         QuoterV1 quoter,
//         address rebalancer
//     ) internal returns (INode node) {
//         (node,) = factory.deployFullNode(
//             "Test Node",
//             "TNODE",
//             address(asset),
//             ownerAddress,
//             _toArray(address(vault)),
//             _defaultComponentAllocations(1, address(router4626)),
//             0.1 ether,
//             rebalancer,
//             address(quoter),
//             SALT
//         );
//     }

//     // Fund test addresses and perform a deposit.
//     function fundTestAddresses(ERC20Mock asset, INode node, address deployer, address user) internal {
//         asset.mint(user, 1000000 ether);
//         asset.mint(deployer, 1000000 ether);
//         asset.approve(address(node), type(uint256).max);
//         node.deposit(1000 ether, deployer);
//     }

//     // Helper to turn an address into a one-element array.
//     function _toArray(address addr) internal pure returns (address[] memory arr) {
//         arr = new address[](1);
//         arr[0] = addr;
//     }

//     // Return default component allocations.
//     function _defaultComponentAllocations(uint256 count, address router)
//         internal
//         pure
//         returns (ComponentAllocation[] memory)
//     {
//         ComponentAllocation[] memory allocations = new ComponentAllocation[](count);
//         allocations[0] =
//             ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether, router: router, isComponent: true});
//         return allocations;
//     }
// }
