// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {stdJson} from "forge-std/StdJson.sol";

import {DigiftWrapper} from "src/wrappers/digift/DigiftWrapper.sol";
import {ERC20MockOwnable} from "test/mocks/ERC20MockOwnable.sol";
import {SubRedManagementMock} from "test/mocks/SubRedManagementMock.sol";

// source .env && FOUNDRY_PROFILE=deploy forge script script/sepolia/DigiftMockSettleSubscribe.s.sol:DigiftMockSettleSubscribe --rpc-url ${ETH_SEPOLIA_RPC_URL} -vvv --broadcast --legacy --with-gas-price 10000000000

contract DigiftMockSettleSubscribe is Script {
    using stdJson for string;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        string memory json = vm.readFile("deployments/sepolia-mock.json");
        DigiftWrapper digiftWrapper = DigiftWrapper(json.readAddress(".digiftWrapper"));
        SubRedManagementMock subRedManagement = SubRedManagementMock(json.readAddress(".subRedManagement"));

        vm.startBroadcast(privateKey);
        uint256 sharesToMint = digiftWrapper.convertToShares(1000e6);
        {
            address[] memory investorList = new address[](1);
            investorList[0] = address(digiftWrapper);
            uint256[] memory quantityList = new uint256[](1);
            quantityList[0] = sharesToMint;
            address[] memory currencyTokenList = new address[](1);
            currencyTokenList[0] = json.readAddress(".usdc");
            uint256[] memory amountList = new uint256[](1);
            amountList[0] = 0;
            uint256[] memory feeList = new uint256[](1);
            feeList[0] = 0;
            subRedManagement.settleSubscriber(
                json.readAddress(".iSNR"), investorList, quantityList, currencyTokenList, amountList, feeList
            );
        }
        vm.stopBroadcast();
    }
}
