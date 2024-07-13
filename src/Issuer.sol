// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Issuer is ERC4626, Ownable {
    // STATE VARIABLES & CONSTANTS
    uint256 public constant targetReserveRatio = 10; // percentage
    uint256 public constant maxDiscount = 1; // percentage
    address public banker;
    IERC4626 public sUSDC;

    // EVENTS
    event CashInvested(uint256 amount, address depositedTo);

    // MODIFIERS
    modifier onlyBanker() {
        require(msg.sender == banker, "Issuer: Only banker can call this function");
        _;
    }
    // CONSTRUCTOR

    constructor(address _asset, string memory _name, string memory _symbol, address _susdc, address _banker)
        ERC20(_name, _symbol)
        ERC4626(IERC20Metadata(_asset))
        Ownable(msg.sender)
    {
        sUSDC = IERC4626(_susdc);
        banker = _banker;
    }

    // total assets override function
    function totalAssets() public view override returns (uint256) {
        IERC20Metadata depositAsset = IERC20Metadata(asset());
        uint256 depositAssetBalance = depositAsset.balanceOf(address(this));

        uint256 shares = sUSDC.balanceOf(address(this));
        uint256 investedAssets = sUSDC.convertToAssets(shares);

        return depositAssetBalance + investedAssets;
    }

    // invest function
    function investCash() external onlyBanker returns (uint256) {
        uint256 cashForInvestment = totalAssets() - getTargetReserve();
        require(cashForInvestment > 0, "Issuer: No cash available for investment");
        sUSDC.deposit(cashForInvestment, address(this));
        emit CashInvested(cashForInvestment, address(sUSDC));

        return cashForInvestment;
    }

    // exchange rate
    function getExchangeRate() internal pure returns (uint256) {
        // change this later to read oracles
    }

    function getTargetReserve() public view returns (uint256) {
        uint256 assets = totalAssets();
        return Math.mulDiv(assets, targetReserveRatio, 100);
    }

    function getMaxDiscount() public view returns (uint256) {
        uint256 assets = totalAssets();
        return Math.mulDiv(assets, maxDiscount, 100);
    }

    function setBanker(address _banker) public onlyOwner {
        banker = _banker;
    }
}
