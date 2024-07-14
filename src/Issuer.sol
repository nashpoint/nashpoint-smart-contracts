// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";
import {console2} from "lib/forge-std/src/Test.sol";

contract Issuer is ERC4626, Ownable {
    // State Constants
    uint256 public constant maxDiscount = 2e16; // percentage
    uint256 public constant targetReserveRatio = 10e16; // percentage
    int256 public constant scalingFactor = -5e18; // negative integer

    // PRBMath Types and Conversions
    UD60x18 maxDiscountUD = ud(maxDiscount);
    SD59x18 targetReserveRatioSD = sd(int256(targetReserveRatio));
    SD59x18 scalingFactorSD = sd(scalingFactor);

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

    // function deposit(uint256 assets, address receiver) public override returns (uint256) {
    //     uint256 maxAssets = maxDeposit(receiver);
    //     if (assets > maxAssets) {
    //         revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
    //     }

    //     uint256 discount = getSwingPriceDiscount().unwrap();
    //     uint256 adjustedAssets = Math.mulDiv(assets, discount, 1e18);
    //     uint256 shares = previewDeposit(adjustedAssets);

    //     _deposit(_msgSender(), receiver, assets, shares);

    //     return shares;
    // }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }       

        uint256 discount = getSwingPriceDiscount().unwrap();
        uint256 adjustedAssets = assets - discount ;
        uint256 shares = previewWithdraw(adjustedAssets);

        console2.log("previewWithdraw(assets)", previewWithdraw(assets));
        console2.log("previewWithdraw(adjustedAssets)", previewWithdraw(adjustedAssets));
        console2.log("difference", previewWithdraw(assets) - previewWithdraw(adjustedAssets));

        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    // total assets override function
    function totalAssets() public view override returns (uint256) {
        uint256 depositAssetBalance = usdc.balanceOf(address(this));
        uint256 shares = sUSDC.balanceOf(address(this));
        uint256 investedAssets = sUSDC.convertToAssets(shares);

        return depositAssetBalance + investedAssets;
    }

    function getReservePercent() public view returns (uint256) {
        // returns reserve percentage in 1e18 = 100% level of precision
        uint256 currentReserve = usdc.balanceOf(address(this));
        uint256 assets = totalAssets();
        uint256 reservePercent = Math.mulDiv(currentReserve, 1e18, assets);

        console2.log("Bestia reservePercent", reservePercent);
        return reservePercent;
    }

    // swing price curve equation
    //
    function getSwingPriceDiscount() public view returns (UD60x18 result) {
        uint256 currentReserveRatio = getReservePercent(); // correct
        SD59x18 currentReserveRatioSD = sd(int256(currentReserveRatio)); // correct
        // result: 52631578947368421

        // Scaling factor / target reserve ratio * current reserve ratio
        SD59x18 intermediateValue = scalingFactorSD.div(targetReserveRatioSD).mul(currentReserveRatioSD); // wrong
        // result: -2631578947368421050
        // expected: -2.5e18 (I think)

        // console2.log("Bestia intermediateValue", intermediateValue.unwrap());

        SD59x18 expResult = exp(intermediateValue);

        result = maxDiscountUD.mul(ud(uint256(expResult.unwrap())));
    }

    function getTargetReserve() public view returns (uint256) {
        uint256 assets = totalAssets();
        return Math.mulDiv(assets, targetReserveRatio, 1e18);

        // ALTERNATIVE IMPLEMENTATION FROM MARCO
        // totalBalanceVaultUSD = sUSDC balance x sUSDC price + USDC balance x price
        // currentRatiosUSDC = sUSDC balace x price / totalBalanceVaultUSD
        // delta = abs(currentRatiosUSDC - targetReserveRatio)
    }

    function getRemainingReservePercent() public view returns (uint256) {
        console2.log("Bestia getRemainingReservePercent", 1e18 - getReservePercent());
        return 1e18 - getReservePercent();
    }

    // invest function
    function investCash() external onlyBanker returns (uint256) {
        uint256 cashForInvestment = totalAssets() - getTargetReserve();
        require(cashForInvestment > 0, "Issuer: No cash available for investment");
        sUSDC.deposit(cashForInvestment, address(this));
        emit CashInvested(cashForInvestment, address(sUSDC));

        return cashForInvestment;
    }

    function setBanker(address _banker) public onlyOwner {
        banker = _banker;
    }
}
