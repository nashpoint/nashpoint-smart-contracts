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

// source .env && FOUNDRY_PROFILE=deploy forge script script/sepolia/DeployDigiftMockTesting.s.sol:DeployDigiftMockTesting --rpc-url ${ETH_SEPOLIA_RPC_URL} --broadcast --legacy -vvv --with-gas-price 9000000000

contract DeployDigiftMockTesting is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        NodeRegistryMock nodeRegistry = new NodeRegistryMock();
        ERC20MockOwnable usdc = new ERC20MockOwnable("USDC", "USDC", 6);
        ERC20MockOwnable iSNR = new ERC20MockOwnable("iSNR", "iSNR", 18);
        DigiftEventVerifier eventVerifier = new DigiftEventVerifier(address(nodeRegistry));
        SubRedManagementMock subRedManagement = new SubRedManagementMock();
        PriceOracleMock assetPriceOracle = new PriceOracleMock(8);
        PriceOracleMock dFeedPriceOracle = new PriceOracleMock(18);

        assetPriceOracle.setLatestRoundData(
            18446744073709556890, 99974000, block.timestamp, block.timestamp, 18446744073709556890
        );
        dFeedPriceOracle.setLatestRoundData(0, 232620000000000000000, block.timestamp, block.timestamp, 0);

        address digiftWrapperImpl =
            address(new DigiftAdapter(address(subRedManagement), address(nodeRegistry), address(eventVerifier)));

        DigiftAdapterFactory factory = new DigiftAdapterFactory(digiftWrapperImpl, deployer);
        DigiftAdapter digiftWrapper = factory.deploy(
            DigiftAdapter.InitArgs(
                "iSNR Wrapper",
                "wiSNR",
                address(usdc),
                address(assetPriceOracle),
                address(iSNR),
                address(dFeedPriceOracle),
                // 0.1%
                1e15,
                4 days,
                1000e6,
                1e18
            )
        );

        usdc.mint(deployer, 100000e6);
        usdc.mint(address(subRedManagement), 100000e6);
        iSNR.mint(address(subRedManagement), 1000000000e18);

        nodeRegistry.setRegistryType(deployer, RegistryType.NODE, true);
        digiftWrapper.setManager(deployer, true);
        digiftWrapper.setNode(deployer, true);

        subRedManagement.setManager(deployer, true);
        subRedManagement.setWhitelist(address(digiftWrapper), true);

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
