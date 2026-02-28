// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Vm, VmSafe} from "forge-std/Vm.sol";

import {stdJson} from "forge-std/StdJson.sol";

library Environment {
    using stdJson for string;

    struct DigiftConfig {
        address subRedManagement;
        address iSNRPriceOracle;
        address iSNR;
    }

    struct WTConfig {
        address receiverAddress;
        address senderAddress;
        address CRDYX;
    }

    struct Config {
        bool merkl;
        bool oneInch;
        address incentraDistributor;
        address fluidRewardsDistributor;
        address protocolOwner;
        address usdc;
        address usdcPriceOracle;
        DigiftConfig digift;
        WTConfig wt;
    }

    struct Contracts {
        address nodeRegistryImplementation;
        address nodeRegistryProxy;
        address nodeImplementation;
        address nodeFactory;
        address erc4626Router;
        address erc7540Router;
        address merklRouter;
        address oneInchRouter;
        address incentraRouter;
        address fluidRewardsRouter;
        address capPolicy;
        address gatePolicyBlacklist;
        address gatePolicyWhitelist;
        address nodePausingPolicy;
        address protocolPausingPolicy;
        address digiftEventVerifier;
        address digiftAdapterImplementation;
        address digiftAdapterFactory;
        address transferEventVerifier;
        address wtAdapterImplementation;
        address wtAdapterFactory;
    }

    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function toUpperCase(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        for (uint256 i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c >= 97 && c <= 122) {
                b[i] = bytes1(c - 32);
            }
        }
        return string(b);
    }

    function getPrivateKey(VmSafe vmSafe_) internal view returns (uint256) {
        string memory profile = vmSafe_.envString("FOUNDRY_PROFILE");
        if (equal(profile, "default")) {
            revert("Environment::FOUNDRY_PROFILE is default");
        }
        return vmSafe_.envUint(string.concat(toUpperCase(profile), "_PRIVATE_KEY"));
    }

    function getConfig(VmSafe vmSafe_) internal view returns (Config memory config) {
        string memory profile = vmSafe_.envString("FOUNDRY_PROFILE");
        if (equal(profile, "default")) {
            revert("Environment::FOUNDRY_PROFILE is default");
        }
        string memory configPath = string.concat("config/", profile, ".json");
        string memory json = vmSafe_.readFile(configPath);
        config.protocolOwner = json.readAddress(".protocolOwner");
        config.wt.receiverAddress = json.readAddressOr(".wt.receiverAddress", address(0));
        config.wt.senderAddress = json.readAddressOr(".wt.senderAddress", address(0));
        config.wt.CRDYX = json.readAddressOr(".wt.CRDYX", address(0));
        config.digift.subRedManagement = json.readAddressOr(".digift.subRedManagement", address(0));
        config.digift.iSNR = json.readAddressOr(".digift.iSNR", address(0));
        config.digift.iSNRPriceOracle = json.readAddressOr(".digift.iSNRPriceOracle", address(0));
        config.incentraDistributor = json.readAddressOr(".incentraDistributor", address(0));
        config.fluidRewardsDistributor = json.readAddressOr(".fluidRewardsDistributor", address(0));
        config.merkl = json.readBoolOr(".merkl", false);
        config.oneInch = json.readBoolOr(".oneInch", false);
        config.usdc = json.readAddressOr(".usdc", address(0));
        config.usdcPriceOracle = json.readAddressOr(".usdcPriceOracle", address(0));
    }

    function getContractsPath(VmSafe vmSafe_) internal view returns (string memory) {
        string memory profile = vmSafe_.envString("FOUNDRY_PROFILE");
        if (equal(profile, "default")) {
            revert("Environment::FOUNDRY_PROFILE is default");
        }
        return string.concat("deployments/", profile, ".json");
    }

    function getContracts(VmSafe vmSafe_) internal view returns (Contracts memory contracts) {
        string memory path = getContractsPath(vmSafe_);
        string memory json = vmSafe_.readFile(path);
        contracts.nodeRegistryImplementation = json.readAddress(".nodeRegistryImplementation");
        contracts.nodeRegistryProxy = json.readAddress(".nodeRegistryProxy");
        contracts.nodeImplementation = json.readAddress(".nodeImplementation");
        contracts.nodeFactory = json.readAddress(".nodeFactory");
        contracts.erc4626Router = json.readAddressOr(".routers.erc4626Router", address(0));
        contracts.erc7540Router = json.readAddressOr(".routers.erc7540Router", address(0));
        contracts.merklRouter = json.readAddressOr(".routers.merklRouter", address(0));
        contracts.oneInchRouter = json.readAddressOr(".routers.oneInchRouter", address(0));
        contracts.incentraRouter = json.readAddressOr(".routers.incentraRouter", address(0));
        contracts.fluidRewardsRouter = json.readAddressOr(".routers.fluidRewardsRouter", address(0));
        contracts.capPolicy = json.readAddressOr(".policies.capPolicy", address(0));
        contracts.gatePolicyBlacklist = json.readAddressOr(".policies.gatePolicyBlacklist", address(0));
        contracts.gatePolicyWhitelist = json.readAddressOr(".policies.gatePolicyWhitelist", address(0));
        contracts.nodePausingPolicy = json.readAddressOr(".policies.nodePausingPolicy", address(0));
        contracts.protocolPausingPolicy = json.readAddressOr(".policies.protocolPausingPolicy", address(0));
        contracts.digiftEventVerifier = json.readAddressOr(".digift.eventVerifier", address(0));
        contracts.digiftAdapterImplementation = json.readAddressOr(".digift.adapterImplementation", address(0));
        contracts.digiftAdapterFactory = json.readAddressOr(".digift.adapterFactory", address(0));
        contracts.transferEventVerifier = json.readAddressOr(".wt.transferEventVerifier", address(0));
        contracts.wtAdapterImplementation = json.readAddressOr(".wt.adapterImplementation", address(0));
        contracts.wtAdapterFactory = json.readAddressOr(".wt.adapterFactory", address(0));
    }

    function setRpc(Vm vm_) internal {
        string memory profile = vm_.envString("FOUNDRY_PROFILE");
        if (equal(profile, "default")) {
            revert("Environment::FOUNDRY_PROFILE is default");
        }
        vm_.createSelectFork(profile);
    }
}
