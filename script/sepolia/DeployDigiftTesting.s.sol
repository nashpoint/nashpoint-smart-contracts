// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {DigiftAdapter} from "src/adapters/digift/DigiftAdapter.sol";
import {DigiftAdapterFactory} from "src/adapters/digift/DigiftAdapterFactory.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";

import {NodeRegistryMock, RegistryType} from "test/mocks/NodeRegistryMock.sol";
import {ERC20MockOwnable} from "test/mocks/ERC20MockOwnable.sol";
import {SubRedManagementMock} from "test/mocks/SubRedManagementMock.sol";
import {PriceOracleMock} from "test/mocks/PriceOracleMock.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/sepolia/DeployDigiftTesting.s.sol:DeployDigiftTesting --rpc-url ${ETH_SEPOLIA_RPC_URL} --broadcast --legacy -vvv --with-gas-price 25000000000

contract DeployDigiftTesting is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        NodeRegistryMock nodeRegistry = new NodeRegistryMock();
        address usdc = 0xc40fA5d8CF408BAA63019137033D2698377fB243;
        address iSNR = 0x3c4A0E537ED48430A7574a04b100B27E010Ec700;
        DigiftEventVerifier eventVerifier = new DigiftEventVerifier(address(nodeRegistry));
        address subRedManagement = 0x99c967aDa4b3Ab4E011EF2379d58E11816bd219b;
        PriceOracleMock assetPriceOracle = new PriceOracleMock(8);
        address dFeedPriceOracle = 0x743Be7f24caA96DF8cf27413b43a5D916E4d0C29;

        assetPriceOracle.setLatestRoundData(
            18446744073709556890, 99974000, 1759880855, 1759880855, 18446744073709556890
        );

        address digiftWrapperImpl =
            address(new DigiftAdapter(subRedManagement, address(nodeRegistry), address(eventVerifier)));

        DigiftAdapterFactory factory = new DigiftAdapterFactory(digiftWrapperImpl, deployer);
        DigiftAdapter digiftWrapper = factory.deploy(
            DigiftAdapter.InitArgs(
                "iSNR Wrapper",
                "wiSNR",
                usdc,
                address(assetPriceOracle),
                iSNR,
                dFeedPriceOracle,
                // 0.1%
                1e15,
                // 1%
                1e16,
                4 days,
                4 days,
                1000e6,
                1e18
            )
        );

        nodeRegistry.setRegistryType(deployer, RegistryType.NODE, true);
        digiftWrapper.setManager(deployer, true);
        digiftWrapper.setNode(deployer, true);

        eventVerifier.setWhitelist(address(digiftWrapper), true);

        vm.stopBroadcast();

        console.log("nodeRegistry");
        console.log(address(nodeRegistry));
        console.log("usdc");
        console.log(address(usdc));
        console.log("iSNR");
        console.log(address(iSNR));
        console.log("eventVerifier");
        console.log(address(eventVerifier));
        console.log("subRedManagement");
        console.log(address(subRedManagement));
        console.log("assetPriceOracle");
        console.log(address(assetPriceOracle));
        console.log("dFeedPriceOracle");
        console.log(address(dFeedPriceOracle));
        console.log("digiftWrapper");
        console.log(address(digiftWrapper));
        console.log("digiftWrapperImpl");
        console.log(digiftWrapperImpl);
        console.log("digiftWrapperFactory");
        console.log(address(factory));
    }
}
