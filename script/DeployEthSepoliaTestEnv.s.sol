// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {QuoterV1} from "src/quoters/QuoterV1.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {INodeRegistry, RegistryType} from "src/interfaces/INodeRegistry.sol";
import {INodeFactory} from "src/interfaces/INodeFactory.sol";

import {console2} from "forge-std/Test.sol";

/*
export FOUNDRY_PROFILE=deploy
unset FOUNDRY_PROFILE
*/

/*
forge script script/DeployEthSepoliaTestEnv.s.sol --rpc-url $ETH_SEPOLIA_RPC_URL --private-key $TESTNET_PRIVATE_KEY --broadcast --verify --force --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
*/

/*
forge script script/DeployEthSepoliaTestEnv.s.sol --rpc-url $ETH_SEPOLIA_RPC_URL --private-key $TESTNET_PRIVATE_KEY --verify --resume
*/

// note: 50 runs to deploy and verify NodeFactory

contract DeployTestEnv is Script {
    bytes32 SALT = keccak256(abi.encodePacked(block.timestamp));

    address feeRecipient;
    ERC20Mock asset;
    ERC4626Mock vault;
    ERC4626Mock vault2;
    ERC4626Mock vault3;

    function run() external {
        // Read environment values
        // uint256 privateKey = vm.envUint("TESTNET_PRIVATE_KEY");
        // address owner = vm.addr(privateKey);
        address owner = 0x1F3D49c350BE3e63940c22f0560eEE3c34A717F9;

        // Begin the first broadcast
        vm.startBroadcast();

        // address registry = 0x6BAbB09399e90DcAb7c18ac2475063592106cc2D;
        // NodeFactory factory = new NodeFactory(registry);
        // INodeRegistry(address(registry)).setRegistryType(address(factory), RegistryType.FACTORY, true);

        address factory = 0x3C31258b8596425Db4fE36CCE1781690f5E5a11C;
        address quoter = 0x3e787b5cDa5C5C1a0fC3F631f4491297c8fDA820;
        address router4626 = 0x6732d4bE44F7dE210AEeF3b827f0aD9eDc006098;
        address router7540 = 0x746D4Bc9b9Ae0F7072d32871FA27dAF643F660C2;

        address mockAsset = 0x8503b4452Bf6238cC76CdbEE223b46d7196b1c93;

        address mockVault = 0xa1455Ae7e7a02Bba075f6Db5ABEbE0A769FE53b3;
        address mockVault2 = 0xb89C710974c4347485a6B1897f5408173F2525f1;
        address mockVault3 = 0x67EA2B841FE0675714F838bf00bBEfd32989f161;
        address cfgLiquidityPool = 0xaB1a5Ed468E3bda75Dab425b2261D6064A71D580;

        INode node = deployNodeWithAddresses(factory, mockAsset, owner, mockVault, router4626, quoter, owner);

        node.updateComponentAllocation(address(mockVault), 0.2 ether, 0, address(router4626));
        node.addComponent(address(mockVault2), 0.2 ether, 0, address(router4626));
        node.addComponent(address(mockVault3), 0.2 ether, 0, address(router4626));
        node.addRouter(address(router7540));
        node.addComponent(address(cfgLiquidityPool), 0.3 ether, 0, address(router7540));

        vm.stopBroadcast();
    }

    // Initialize the registry using helper functions.
    function initializeRegistry(
        NodeRegistry registry,
        NodeFactory factory,
        ERC4626Router router4626,
        QuoterV1 quoter,
        address rebalancer
    ) internal {
        registry.initialize(
            _toArray(address(factory)),
            _toArray(address(router4626)),
            _toArray(address(quoter)),
            _toArray(rebalancer),
            feeRecipient,
            0,
            0,
            0.01 ether
        );
    }

    // Configure the router so that the vault is whitelisted.
    function configureComponents(ERC4626Router router4626) internal {
        router4626.setWhitelistStatus(address(vault), true);
        router4626.setWhitelistStatus(address(vault2), true);
        router4626.setWhitelistStatus(address(vault3), true);
    }

    // Deploy a node using the factory.
    function deployNode(
        NodeFactory factoryAddr,
        ERC20Mock assetToken,
        address ownerAddress,
        ERC4626Mock vaultAddr,
        ERC4626Router router4626,
        QuoterV1 quoterAddr,
        address rebalancer
    ) internal returns (INode node) {
        (node,) = factoryAddr.deployFullNode(
            "Test Node",
            "TNODE",
            address(assetToken),
            ownerAddress,
            _toArray(address(vaultAddr)),
            _defaultComponentAllocations(1, address(router4626)),
            0.1 ether,
            rebalancer,
            address(quoterAddr),
            SALT
        );
    }

    function deployNodeWithAddresses(
        address factoryAddr,
        address assetTokenAddr,
        address ownerAddress,
        address vaultAddr,
        address routerAddr,
        address quoterAddr,
        address rebalancer
    ) internal returns (INode node) {
        // Cast addresses to their respective contract types
        INodeFactory factory = INodeFactory(factoryAddr);

        // Deploy the node using the factory
        (node,) = factory.deployFullNode(
            "Test Node",
            "TNODE",
            assetTokenAddr,
            ownerAddress,
            _toArray(vaultAddr),
            _defaultComponentAllocations(1, routerAddr),
            0.1 ether,
            rebalancer,
            quoterAddr,
            SALT
        );
    }

    // Fund test addresses and perform a deposit.
    function fundTestAddresses(ERC20Mock asset_, INode node, address deployer, address user) internal {
        asset.mint(user, 1000000 ether);
        asset.mint(deployer, 1000000 ether);
        asset.approve(address(node), type(uint256).max);
        node.deposit(1000 ether, deployer);
    }

    // Helper to turn an address into a one-element array.
    function _toArray(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }

    // Return default component allocations.
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
}
