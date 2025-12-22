// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {stdJson} from "forge-std/StdJson.sol";
import {Script, console} from "forge-std/Script.sol";

import {Environment} from "./Utils.sol";

import {Node} from "src/Node.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";

import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import {MerklRouter} from "src/routers/MerklRouter.sol";
import {IncentraRouter} from "src/routers/IncentraRouter.sol";
import {FluidRewardsRouter} from "src/routers/FluidRewardsRouter.sol";
import {OneInchV6RouterV1} from "src/routers/OneInchV6RouterV1.sol";

import {CapPolicy} from "src/policies/CapPolicy.sol";
import {GatePolicyBlacklist} from "src/policies/GatePolicyBlacklist.sol";
import {GatePolicyWhitelist} from "src/policies/GatePolicyWhitelist.sol";
import {NodePausingPolicy} from "src/policies/NodePausingPolicy.sol";
import {ProtocolPausingPolicy} from "src/policies/ProtocolPausingPolicy.sol";

import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftAdapter} from "src/adapters/digift/DigiftAdapter.sol";
import {DigiftAdapterFactory} from "src/adapters/digift/DigiftAdapterFactory.sol";

// NOTE: --rpc-url should be specified since deployment of the Node contract implies the creation of external NodeLib library
// according to https://github.com/foundry-rs/foundry/issues/8410 it is not supported
// Error: Multi chain deployment does not support library linking at the moment.

// NOTE: to verify NodeLib library add this to libraries in foundry.toml corresponding profile and run verification again

// NOTE: specify FOUNDRY_PROFILE and --rpc-url
// source .env && FOUNDRY_PROFILE= forge script script/01_DeployCore.s.sol:DeployCore -vvv --broadcast --rpc-url --verify

contract DeployCore is Script {
    using stdJson for string;

    function run() external {
        string memory path = Environment.getContractsPath(vm);
        uint256 privateKey = Environment.getPrivateKey(vm);
        Environment.Config memory config = Environment.getConfig(vm);

        Environment.Contracts memory contracts;

        vm.startBroadcast(privateKey);

        // Node related contracts

        contracts.nodeRegistryImplementation = address(new NodeRegistry());
        bytes memory nodeRegistryInitializationPayload =
            abi.encodeWithSelector(NodeRegistry.initialize.selector, config.protocolOwner, config.protocolOwner, 0, 0);
        contracts.nodeRegistryProxy =
            address(new ERC1967Proxy(contracts.nodeRegistryImplementation, nodeRegistryInitializationPayload));

        contracts.nodeImplementation = address(new Node(contracts.nodeRegistryProxy));
        contracts.nodeFactory = address(new NodeFactory(contracts.nodeRegistryProxy, contracts.nodeImplementation));

        // Routers

        contracts.erc4626Router = address(new ERC4626Router(contracts.nodeRegistryProxy));
        contracts.erc7540Router = address(new ERC7540Router(contracts.nodeRegistryProxy));

        if (config.merkl) {
            contracts.merklRouter = address(new MerklRouter(contracts.nodeRegistryProxy));
        }
        if (config.oneInch) {
            contracts.oneInchRouter = address(new OneInchV6RouterV1(contracts.nodeRegistryProxy));
        }
        if (config.incentraDistributor != address(0)) {
            contracts.incentraRouter =
                address(new IncentraRouter(contracts.nodeRegistryProxy, config.incentraDistributor));
        }
        if (config.fluidRewardsDistributor != address(0)) {
            contracts.fluidRewardsRouter =
                address(new FluidRewardsRouter(contracts.nodeRegistryProxy, config.fluidRewardsDistributor));
        }

        // Policies

        contracts.capPolicy = address(new CapPolicy(contracts.nodeRegistryProxy));
        contracts.gatePolicyBlacklist = address(new GatePolicyBlacklist(contracts.nodeRegistryProxy));
        contracts.gatePolicyWhitelist = address(new GatePolicyWhitelist(contracts.nodeRegistryProxy));
        contracts.nodePausingPolicy = address(new NodePausingPolicy(contracts.nodeRegistryProxy));
        contracts.protocolPausingPolicy = address(new ProtocolPausingPolicy(contracts.nodeRegistryProxy));

        // Digift

        if (config.digiftSubRedManagement != address(0)) {
            contracts.digiftEventVerifier = address(new DigiftEventVerifier(contracts.nodeRegistryProxy));
            contracts.digiftAdapterImplementation = address(
                new DigiftAdapter(
                    config.digiftSubRedManagement, contracts.nodeRegistryProxy, contracts.digiftEventVerifier
                )
            );
            contracts.digiftAdapterFactory =
                address(new DigiftAdapterFactory(contracts.digiftAdapterImplementation, config.protocolOwner));
        }

        vm.stopBroadcast();

        string memory objectKey = "json";
        string memory routersKey = "routers";
        string memory policiesKey = "policies";
        string memory digiftKey = "digift";
        string memory json =
            stdJson.serialize(objectKey, "nodeRegistryImplementation", contracts.nodeRegistryImplementation);
        json = stdJson.serialize(objectKey, "nodeRegistryProxy", contracts.nodeRegistryProxy);
        json = stdJson.serialize(objectKey, "nodeImplementation", contracts.nodeImplementation);
        json = stdJson.serialize(objectKey, "nodeFactory", contracts.nodeFactory);

        string memory routers = stdJson.serialize(routersKey, "erc4626Router", contracts.erc4626Router);
        routers = stdJson.serialize(routersKey, "erc7540Router", contracts.erc7540Router);

        if (contracts.merklRouter != address(0)) {
            routers = stdJson.serialize(routersKey, "merklRouter", contracts.merklRouter);
        }
        if (contracts.oneInchRouter != address(0)) {
            routers = stdJson.serialize(routersKey, "oneInchRouter", contracts.oneInchRouter);
        }
        if (contracts.incentraRouter != address(0)) {
            routers = stdJson.serialize(routersKey, "incentraRouter", contracts.incentraRouter);
        }
        if (contracts.fluidRewardsRouter != address(0)) {
            routers = stdJson.serialize(routersKey, "fluidRewardsRouter", contracts.fluidRewardsRouter);
        }

        json = stdJson.serialize(objectKey, "routers", routers);

        string memory policies = stdJson.serialize(policiesKey, "capPolicy", contracts.capPolicy);
        policies = stdJson.serialize(policiesKey, "gatePolicyBlacklist", contracts.gatePolicyBlacklist);
        policies = stdJson.serialize(policiesKey, "gatePolicyWhitelist", contracts.gatePolicyWhitelist);
        policies = stdJson.serialize(policiesKey, "nodePausingPolicy", contracts.nodePausingPolicy);
        policies = stdJson.serialize(policiesKey, "protocolPausingPolicy", contracts.protocolPausingPolicy);

        json = stdJson.serialize(objectKey, "policies", policies);

        if (contracts.digiftEventVerifier != address(0)) {
            string memory digift = stdJson.serialize(digiftKey, "eventVerifier", contracts.digiftEventVerifier);
            digift = stdJson.serialize(digiftKey, "adapterImplementation", contracts.digiftAdapterImplementation);
            digift = stdJson.serialize(digiftKey, "adapterFactory", contracts.digiftAdapterFactory);
            json = stdJson.serialize(objectKey, "digift", digift);
        }

        stdJson.write(json, path);
    }
}
