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
forge script script/DeployNode.s.sol --rpc-url $ARBITRUM_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --force --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
*/

/*
forge script script/DeployNode.s.sol --rpc-url $ARBITRUM_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --verify --resume
*/

// note: 50 runs to deploy and verify NodeFactory

contract DeployTestEnv is Script {
    bytes32 SALT = keccak256(abi.encodePacked(block.timestamp));

    address feeRecipient;
    address owner = 0x1F3D49c350BE3e63940c22f0560eEE3c34A717F9;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant yUsdcaAddress = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1; // yearn
    address constant fUsdcAddress = 0x1A996cb54bb95462040408C06122D45D6Cdb6096; // fluid
    address constant sdUSDCV3Address = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6; // gearbox
    address constant farmUsdcCompoundV3Address = 0x7b33c028fdcd6425c60b7d2A1a54eC10bFdF14B8; // compound
    address constant farmUsdcAaveV3Address = 0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c; // aave
    address constant revertUsdcV3VaultAddress = 0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825; // revert

    address constant factory = 0xBf748c4b72F295ec796BDE1209057F837ecc683c;
    address constant quoter = 0x1EcCf86A82c4Cc13971c06CE8d8418a88a9Ab70A;
    address constant router4626 = 0x3e6abee646A2160a7C8dF5e4e8bfA43F8D0b2Da1;

    uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address hotWallet = vm.envAddress("METAMASK_HOT_WALLET");

    function run() external {
        SALT = bytes32(abi.encodePacked(block.timestamp));
        uint64 targetReserveRatio = 0.1 ether;

        address[] memory addresses = _toArraySix(
            yUsdcaAddress,
            fUsdcAddress,
            sdUSDCV3Address,
            farmUsdcCompoundV3Address,
            farmUsdcAaveV3Address,
            revertUsdcV3VaultAddress
        );

        ComponentAllocation[] memory componentAllocations =
            _setEvenComponentAllocations(targetReserveRatio, uint64(addresses.length), 0.01 ether);

        vm.startBroadcast();

        INodeFactory(factory).deployFullNode(
            "USDC Node",
            "nUSDC",
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
