// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

contract Issuer is ERC4626 {
    uint256 public constant targetReserveRatio = 10e18;
    uint256 public constant maxDiscount = 1e18;

    constructor(address _asset, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC4626(IERC20Metadata(_asset))
    {}

    // total assets function
    function totalAssets() public view override returns (uint256) {
        IERC20Metadata depositAsset = IERC20Metadata(asset());
        uint256 depositAssetBalance = depositAsset.balanceOf(address(this));

        // need to get the invested assets and the exchange rate
        // sum them to get the total assets

        return depositAssetBalance; // replace this with the correct total assets
    }

    // price curve function
    function priceCurve(uint256 _amount) public view returns (uint256) {
        // function that calculates the price curve
    }

    // invest function
    function invest(uint256 _amount) public { // make this onlyBanker
            // function that allows the banker to invest
    }

    // exchange rate
    function getExchangeRate() internal pure returns (uint256) {
        return 950000000000000000; // This represents 0.95 in fixed-point arithmetic with 18 decimal places
    }
}
