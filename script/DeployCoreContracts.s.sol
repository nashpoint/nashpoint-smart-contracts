// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.28;

// import {Script} from "forge-std/Script.sol";
// import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
// import {NodeFactory} from "src/NodeFactory.sol";
// import {NodeRegistry} from "src/NodeRegistry.sol";
// import {QuoterV1} from "src/quoters/QuoterV1.sol";
// import {ERC4626Router} from "src/routers/ERC4626Router.sol";
// import {ERC7540Router} from "src/routers/ERC7540Router.sol";
// import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
// import {INode, ComponentAllocation} from "src/interfaces/INode.sol";

// import {console2} from "forge-std/Test.sol";

// /*
// forge script script/DeployCoreContracts.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
// */

// contract DeployTestEnv is Script {
//     bytes32 public SALT;

//     uint256 privateKey = vm.envUint("PRIVATE_KEY");

//     function run() external {
//         SALT = bytes32(abi.encodePacked(block.timestamp));
//         // Read environment values
//         address registryOwner = vm.addr(privateKey);
//         address rebalancer = vm.addr(privateKey);
//         address feeRecipient = vm.addr(privateKey);

//         // Begin the broadcast
//         vm.startBroadcast();

//         // Deploy core contracts
//         (
//             NodeRegistry registry,
//             NodeFactory factory,
//             QuoterV1 quoter,
//             ERC4626Router router4626,
//             ERC7540Router router7540
//         ) = deployCoreContracts(registryOwner);

//         // Initialize the registry with the deployed addresses
//         initializeRegistry(registry, factory, router4626, router7540, quoter, rebalancer, feeRecipient);

//         // Set the protocol max swing factor
//         registry.setProtocolMaxSwingFactor(10e16);

//         // Stop the broadcast
//         vm.stopBroadcast();

//         console2.log("registryOwner address: %s", registryOwner);
//         console2.log("Rebalancer address: %s", rebalancer);
//         console2.log("ERC4626Router address: %s", address(router4626));
//         console2.log("ERC7540Router address: %s", address(router7540));
//         console2.log("QuoterV1 address: %s", address(quoter));
//         console2.log("NodeRegistry address: %s", address(registry));
//         console2.log("NodeFactory address: %s", address(factory));
//         console2.log("feeRecipient address: %s", feeRecipient);
//     }

//     // Deploy core contracts and return them.
//     function deployCoreContracts(address deployer)
//         internal
//         returns (
//             NodeRegistry registry,
//             NodeFactory factory,
//             QuoterV1 quoter,
//             ERC4626Router router4626,
//             ERC7540Router router7540
//         )
//     {
//         registry = new NodeRegistry(deployer);
//         factory = new NodeFactory(address(registry));
//         quoter = new QuoterV1(address(registry));
//         router4626 = new ERC4626Router(address(registry));
//         router7540 = new ERC7540Router(address(registry));
//     }

//     // Initialize the registry using helper functions.
//     function initializeRegistry(
//         NodeRegistry registry,
//         NodeFactory factory,
//         ERC4626Router router4626,
//         ERC7540Router router7540,
//         QuoterV1 quoter,
//         address rebalancer,
//         address feeRecipient
//     ) internal {
//         registry.initialize(
//             _toArray(address(factory)),
//             _toArrayTwo(address(router4626), address(router7540)),
//             _toArray(address(quoter)),
//             _toArray(rebalancer),
//             feeRecipient,
//             0,
//             0,
//             0.01 ether
//         );
//     }

//     // Helper to turn an address into a one-element array.
//     function _toArray(address addr) internal pure returns (address[] memory arr) {
//         arr = new address[](1);
//         arr[0] = addr;
//     }

//     // Helper to turn two addresses into a two-element array.
//     function _toArrayTwo(address addr1, address addr2) internal pure returns (address[] memory arr) {
//         arr = new address[](2);
//         arr[0] = addr1;
//         arr[1] = addr2;
//     }
// }
