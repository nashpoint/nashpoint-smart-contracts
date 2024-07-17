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
    SD59x18 maxDiscountSD = sd(int256(maxDiscount));
    SD59x18 targetReserveRatioSD = sd(int256(targetReserveRatio));
    SD59x18 scalingFactorSD = sd(scalingFactor);

    address public banker;
    IERC4626 public sUSDC;
    IERC20Metadata public usdc;

    // EVENTS
    event CashInvested(uint256 amount, address depositedTo);

    // ERRORS
    error ReserveBelowTargetRatio();
    error ExceedsAvailableReserve();

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

    function adjustedDeposit(uint256 assets, address receiver) public returns (uint256) {}

    function adjustedWithdraw(uint256 assets, address receiver, address owner) public returns (uint256) {}

    // swing price curve equation
    // function needs to not accept
    function getSwingFactor(uint256 _reserveRatioAfterTX) public view returns (uint256 swingFactor) {
        // uint256 reserveRatioAfterTX = _reserveRatioAfterTX;

        if (_reserveRatioAfterTX < 0) {
            revert ExceedsAvailableReserve();
        } else if (_reserveRatioAfterTX > targetReserveRatio) {
            return 0;
        } else {
            SD59x18 reserveRatioAfterTX = sd(int256(_reserveRatioAfterTX));

            SD59x18 result = maxDiscountSD * exp(scalingFactorSD.div(targetReserveRatioSD).mul(reserveRatioAfterTX));

            return uint256(result.unwrap());
        }
    }

    // invest function
    function investCash() external onlyBanker returns (uint256 cashInvested) {
        uint256 idealCashReserve = totalAssets() * targetReserveRatio / 1e18;

        if (usdc.balanceOf(address(this)) < idealCashReserve) {
            revert ReserveBelowTargetRatio();
        } else {
            uint256 investableCash = usdc.balanceOf(address(this)) - idealCashReserve;
            sUSDC.deposit(investableCash, address(this));

            emit CashInvested(investableCash, address(sUSDC));
            return (investableCash);
        }
    }

    function setBanker(address _banker) public onlyOwner {
        banker = _banker;
    }
}

// use instead of normal deposit function
