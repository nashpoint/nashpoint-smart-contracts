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
forge script script/DeployNodeArbitrum.s.sol --rpc-url $ARBITRUM_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --force --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
*/

/*
forge script script/DeployNodeArbitrum.s.sol --rpc-url $ARBITRUM_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --verify --resume
*/

contract DeployTestEnv is Script {
    bytes32 SALT = keccak256(abi.encodePacked(block.timestamp));

    address feeRecipient;
    address owner = 0x1F3D49c350BE3e63940c22f0560eEE3c34A717F9;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant Yearn_yUsdca = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1; // yearn
    address constant Fluid_fUsdc = 0x1A996cb54bb95462040408C06122D45D6Cdb6096; // fluid
    address constant Gearbox_sdUSDCV3A = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6; // gearbox
    address constant Compound_farmUsdcCompoundV3A = 0x7b33c028fdcd6425c60b7d2A1a54eC10bFdF14B8; // compound
    address constant Aave_farmUsdcAaveV3A = 0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c; // aave
    address constant Revert_revertUsdcV3VaultA = 0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825; // revert
    address constant Centrifuge_cfgUsdcJTRSY = 0x16C796208c6E2d397Ec49D69D207a9cB7d072f04; // centrifuge

    address constant factory = 0x60fEd0751f5B3aA4a904FFA5728b4aEfb990dD72;
    address constant quoter = 0x23d933b27E73e949453156A1A31c18633A81411a;
    address constant router4626 = 0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6;
    address constant router7540 = 0x6a200b1Bafc7183741809B35E1B0DE9E4f4c0828;

    uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address hotWallet = vm.envAddress("METAMASK_HOT_WALLET");

    string constant nodeName = "Nashpoint DeFi & RWA Fund";
    string constant nodeSymbol = "RWAFI";

    function run() external {
        SALT = bytes32(abi.encodePacked(block.timestamp));
        uint64 targetReserveRatio = 0.05 ether;

        address[] memory addresses = _toArraySix(            
            Aave_farmUsdcAaveV3A,
            Compound_farmUsdcCompoundV3A,            
            Fluid_fUsdc,
            Gearbox_sdUSDCV3A,            
            Revert_revertUsdcV3VaultA,
            Centrifuge_cfgUsdcJTRSY
        );

        ComponentAllocation[] memory componentAllocations = new ComponentAllocation[](6);

        // Aave_farmUsdcAaveV3A
        componentAllocations[0] = ComponentAllocation({
            targetWeight: 0.0735 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        // Compound_farmUsdcCompoundV3A
        componentAllocations[1] = ComponentAllocation({
            targetWeight: 0.0982 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        // Fluid_fUsdc
        componentAllocations[2] = ComponentAllocation({
            targetWeight: 0.2069 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        // Gearbox_sdUSDCV3A
        componentAllocations[3] = ComponentAllocation({
            targetWeight: 0.0151 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        // Revert_revertUsdcV3VaultA
        componentAllocations[4] = ComponentAllocation({
            targetWeight: 0.4273 ether,
            maxDelta: 0.01 ether,
            router: address(router4626),
            isComponent: true
        });

        // Centrifuge_cfgUsdcJTRSY
        componentAllocations[5] = ComponentAllocation({
            targetWeight: 0.129 ether,
            maxDelta: 0.01 ether,
            router: address(router7540),
            isComponent: true
        });

        vm.startBroadcast();

        INodeFactory(factory).deployFullNode(
            nodeName,
            nodeSymbol,
            usdc,
            hotWallet,
            addresses,
            componentAllocations,
            targetReserveRatio,
            hotWallet,
            quoter,
            SALT
        );

        vm.stopBroadcast();
    }

    function _toArraySix(address addr1, address addr2, address addr3, address addr4, address addr5, address addr6)
        internal
        pure
        returns (address[] memory arr)
    {
        arr = new address[](6);
        arr[0] = addr1;
        arr[1] = addr2;
        arr[2] = addr3;
        arr[3] = addr4;
        arr[4] = addr5;
        arr[5] = addr6;
    }

    function _toArrayFive(address addr1, address addr2, address addr3, address addr4, address addr5)
        internal
        pure
        returns (address[] memory arr)
    {
        arr = new address[](5);
        arr[0] = addr1;
        arr[1] = addr2;
        arr[2] = addr3;
        arr[3] = addr4;
        arr[4] = addr5;
    }

    function _setEvenComponentAllocations(uint64 targetReserveRatio, uint64 count, uint64 maxDelta)
        internal
        pure
        returns (ComponentAllocation[] memory componentAllocations)
    {
        componentAllocations = new ComponentAllocation[](count);
        for (uint64 i = 0; i < count; i++) {
            componentAllocations[i] = ComponentAllocation({
                targetWeight: (1 ether - targetReserveRatio) / count,
                maxDelta: maxDelta,
                router: router4626,
                isComponent: true
            });
        }
    }
}
