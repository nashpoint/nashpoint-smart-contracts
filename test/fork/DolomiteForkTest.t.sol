// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC4626BaseTest} from "./ERC4626BaseTest.sol";

import {ChainlinkAggregatorMock, AggregatorMock} from "test/mocks/ChainlinkAggregatorMock.sol";

contract DolomiteForkTest is ERC4626BaseTest {
    ChainlinkAggregatorMock chainlinkAggregatorMock;

    // this should be altered since it prices USDC using chainlink and checks for stale price data
    address chainlinkPriceOracleV3 = 0x8FA6d763CA105B3C88fd01317db2E66021208451;
    // storage slot with ChainlinkOracle contract on that contract
    bytes32 oracleInfosBaseSlot = keccak256(abi.encode(0xaf88d065e77c8cC2239327C5EDb3A432268e5831, 0));

    function _setupErc4626Test() internal override {
        erc4626Vault = IERC4626(0x444868B6e8079ac2c55eea115250f92C2b2c4D14); // Dolomite USDC Vault

        AggregatorMock aggregator = new AggregatorMock();
        chainlinkAggregatorMock = new ChainlinkAggregatorMock(address(aggregator));
        // set the price to 1 USD
        chainlinkAggregatorMock.setAnswer(1000000000);

        // exchange real Chainlink oracle with the Mock
        vm.store(
            chainlinkPriceOracleV3, oracleInfosBaseSlot, bytes32(uint256(uint160(address(chainlinkAggregatorMock))))
        );
    }

    function _warpHook() internal override {
        // update price to bypass checks on Dolomite vault
        chainlinkAggregatorMock.setUpdatedAt(block.timestamp);
    }
}
