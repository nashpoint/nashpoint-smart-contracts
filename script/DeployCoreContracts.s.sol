// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.28;

// import {Script} from "forge-std/Script.sol";
// import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
// import {Node} from "src/Node.sol";
// import {NodeFactory} from "src/NodeFactory.sol";
// import {NodeRegistry} from "src/NodeRegistry.sol";
// import {QuoterV1} from "src/quoters/QuoterV1.sol";
// import {ERC4626Router} from "src/routers/ERC4626Router.sol";
// import {ERC7540Router} from "src/routers/ERC7540Router.sol";
// import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
// import {INode, ComponentAllocation} from "src/interfaces/INode.sol";

// import {console2} from "forge-std/Test.sol";

// /*
// export FOUNDRY_PROFILE=deploy
// unset FOUNDRY_PROFILE
// */

// /// Local Network ///

// /*
// forge script script/DeployCoreContracts.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
// */

// /// Sepolia Testnet ///

// /*
// forge script script/DeployCoreContracts.s.sol --rpc-url $ETH_SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --force --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
// */

// /*
// forge script script/DeployCoreContracts.s.sol --rpc-url $ETH_SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --verify --resume
// */

// /// Arbitrum Mainnet ///

// /*
// forge script script/DeployCoreContracts.s.sol --rpc-url $ARBITRUM_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --force --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
// */

// contract DeployTestEnv is Script {
//     bytes32 public SALT;
//     address public deployer;
//     address public registryOwner;
//     address public rebalancer;
//     address public feeRecipient;

//     uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
//     address hotWallet = vm.envAddress("METAMASK_HOT_WALLET");

//     function run() external {
//         // Read environment values
//         SALT = bytes32(abi.encodePacked(block.timestamp));
//         deployer = vm.addr(privateKey);

//         registryOwner = hotWallet;
//         rebalancer = hotWallet;
//         feeRecipient = hotWallet;

//         // Begin the broadcast
//         vm.startBroadcast();

//         // Deploy core contracts
//         (
//             NodeRegistry registry,
//             NodeFactory factory,
//             QuoterV1 quoter,
//             ERC4626Router router4626,
//             ERC7540Router router7540
//         ) = deployCoreContracts(deployer);

//         // Initialize the registry with the deployed addresses
//         initializeRegistry(registry, factory, router4626, router7540, quoter, rebalancer, feeRecipient);

//         // Transfer ownership of the registry to the registryOwner
//         registry.transferOwnership(registryOwner);

//         // Stop the broadcast
//         vm.stopBroadcast();

//         console2.log("registryOwner address: %s", registry.owner());
//         console2.log("Rebalancer address: %s", rebalancer);
//         console2.log("feeRecipient address: %s", feeRecipient);
//         console2.log("NodeRegistry address: %s", address(registry));
//         console2.log("NodeFactory address: %s", address(factory));
//         console2.log("QuoterV1 address: %s", address(quoter));
//         console2.log("ERC4626Router address: %s", address(router4626));
//         console2.log("ERC7540Router address: %s", address(router7540));
//     }

//     // Deploy core contracts and return them.
//     function deployCoreContracts(address deployer_)
//         internal
//         returns (
//             NodeRegistry registry,
//             NodeFactory factory,
//             QuoterV1 quoter,
//             ERC4626Router router4626,
//             ERC7540Router router7540
//         )
//     {
//         registry = new NodeRegistry(deployer_);
//         address nodeImplementation = address(new Node(address(registry)));
//         factory = new NodeFactory(address(registry), nodeImplementation);
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
//         address rebalancer_,
//         address feeRecipient_
//     ) internal {
//         registry.initialize(
//             _toArray(address(factory)),
//             _toArrayTwo(address(router4626), address(router7540)),
//             _toArray(address(quoter)),
//             _toArray(rebalancer_),
//             feeRecipient_,
//             0, // protocol fee
//             0, // execution fee
//             0.1 ether // 10%
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
