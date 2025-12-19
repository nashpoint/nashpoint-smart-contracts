// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Vm, VmSafe} from "forge-std/Vm.sol";

import {stdJson} from "forge-std/StdJson.sol";

library Environment {
    using stdJson for string;

    struct Config {
        bool merkl;
        bool oneInch;
        address incentraDistributor;
        address fluidRewardsDistributor;
        address protocolOwner;
        address digiftSubRedManagement;
        address usdc;
        address iSNR;
        address iSNRPriceOracle;
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
        config.digiftSubRedManagement = json.readAddressOr(".digiftSubRedManagement", address(0));
        config.incentraDistributor = json.readAddressOr(".incentraDistributor", address(0));
        config.fluidRewardsDistributor = json.readAddressOr(".fluidRewardsDistributor", address(0));
        config.merkl = json.readBoolOr(".merkl", false);
        config.oneInch = json.readBoolOr(".oneInch", false);
        config.usdc = json.readAddressOr(".usdc", address(0));
        config.iSNR = json.readAddressOr(".iSNR", address(0));
        config.iSNRPriceOracle = json.readAddressOr(".iSNRPriceOracle", address(0));
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
        contracts.erc4626Router = json.readAddress(".erc4626Router");
        contracts.erc7540Router = json.readAddress(".erc7540Router");
        contracts.merklRouter = json.readAddressOr(".merklRouter", address(0));
        contracts.oneInchRouter = json.readAddressOr(".oneInchRouter", address(0));
        contracts.incentraRouter = json.readAddressOr(".incentraRouter", address(0));
        contracts.fluidRewardsRouter = json.readAddressOr(".fluidRewardsRouter", address(0));
        contracts.capPolicy = json.readAddress(".capPolicy");
        contracts.gatePolicyBlacklist = json.readAddress(".gatePolicyBlacklist");
        contracts.gatePolicyWhitelist = json.readAddress(".gatePolicyWhitelist");
        contracts.nodePausingPolicy = json.readAddress(".nodePausingPolicy");
        contracts.protocolPausingPolicy = json.readAddress(".protocolPausingPolicy");
        contracts.digiftEventVerifier = json.readAddressOr(".digiftEventVerifier", address(0));
        contracts.digiftAdapterImplementation = json.readAddressOr(".digiftAdapterImplementation", address(0));
        contracts.digiftAdapterFactory = json.readAddressOr(".digiftAdapterFactory", address(0));
    }

    function setRpc(Vm vm_) internal {
        string memory profile = vm_.envString("FOUNDRY_PROFILE");
        if (equal(profile, "default")) {
            revert("Environment::FOUNDRY_PROFILE is default");
        }
        vm_.createSelectFork(profile);
    }
}
