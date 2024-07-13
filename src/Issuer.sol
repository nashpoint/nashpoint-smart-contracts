// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {UD60x18, exp, ud} from "lib/prb-math/src/UD60x18.sol";

contract Issuer is ERC4626, Ownable {
    // STATE VARIABLES & CONSTANTS
    uint256 public constant targetReserveRatio = 10; // percentage
    uint256 public constant maxDiscount = 2; // percentage
    uint256 public constant scalingFactor = 5;
    address public banker;
    IERC4626 public sUSDC;
    IERC20Metadata public usdc;

    // EVENTS
    event CashInvested(uint256 amount, address depositedTo);

    // MODIFIERS
    modifier onlyBanker() {
        require(msg.sender == banker, "Issuer: Only banker can call this function");
        _;
    }

    constructor(address _asset, string memory _name, string memory _symbol, address _susdc, address _banker)
        ERC20(_name, _symbol)
        ERC4626(IERC20Metadata(_asset))
        Ownable(msg.sender)
    {
        sUSDC = IERC4626(_susdc);
        usdc = IERC20Metadata(_asset);
        banker = _banker;
    }

    // total assets override function
    function totalAssets() public view override returns (uint256) {
        uint256 depositAssetBalance = usdc.balanceOf(address(this));
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

    // implement this after you can get the actual reserve percentage
    function getSwingPriceDiscount() public view returns (UD60x18 result) {
        uint256 remainingReservePercent = getRemainingReservePercent();
        UD60x18 maxDiscountUD = ud(maxDiscount * 1e18);
        UD60x18 scalingFactorUD = ud(scalingFactor * 1e18);
        UD60x18 targetReserveRatioUD = ud(targetReserveRatio * 1e18);
        UD60x18 remainingReservePercentUD = ud(remainingReservePercent);

        // Perform the calculation using UD60x18 types
        result = maxDiscountUD.mul(exp(scalingFactorUD.div(targetReserveRatioUD).mul(remainingReservePercentUD)));
    }

    // delete later, just example of using PRBMath
    function unsignedLog2(UD60x18 x) external pure returns (UD60x18 result) {
        result = x.log2();
    }

    // exchange rate
    function getExchangeRate() internal pure returns (uint256) {
        // change this later to read oracles
    }

    function getTargetReserve() public view returns (uint256) {
        uint256 assets = totalAssets();
        return Math.mulDiv(assets, targetReserveRatio, 100);
    }

    function getReservePercent() public view returns (uint256) {
        // returns reserve percentage in 1e18 = 100% level of precision
        uint256 currentReserve = usdc.balanceOf(address(this));
        uint256 assets = totalAssets();
        uint256 reservePercent = Math.mulDiv(currentReserve, 1e18, assets);

        return reservePercent;
    }

    function getRemainingReservePercent() public view returns (uint256) {
        return 1e18 - getReservePercent();
    }

    function getMaxDiscount() public view returns (uint256) {
        uint256 assets = totalAssets();
        return Math.mulDiv(assets, maxDiscount, 100);
    }

    function setBanker(address _banker) public onlyOwner {
        banker = _banker;
    }
}
