// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Mock} from "../ERC20Mock.sol";

/**
 * @title ERC4626NegativeYieldVault
 * @notice ERC4626 vault whose share price decays linearly over time.
 *         The vault burns underlying each interaction to simulate negative yield.
 */
contract ERC4626NegativeYieldVault is ERC4626 {
    uint256 public immutable decayPerSecond; // scaled by 1e18 (100% per second)
    uint256 public lastReport;
    ERC20Mock internal immutable underlyingMock;

    constructor(address underlying, string memory name_, string memory symbol_, uint256 decayPerSecond_)
        ERC20(name_, symbol_)
        ERC4626(IERC20(underlying))
    {
        underlyingMock = ERC20Mock(underlying);
        decayPerSecond = decayPerSecond_;
        lastReport = block.timestamp;
    }

    function totalAssets() public view override returns (uint256) {
        uint256 base = super.totalAssets();
        uint256 elapsed = block.timestamp - lastReport;
        if (elapsed == 0 || decayPerSecond == 0) {
            return base;
        }
        uint256 decayAmount = (base * decayPerSecond * elapsed) / 1e18;
        if (decayAmount >= base) {
            return 0;
        }
        return base - decayAmount;
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        _syncDecay();
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        _syncDecay();
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        _syncDecay();
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        _syncDecay();
        return super.redeem(shares, receiver, owner);
    }

    function _syncDecay() internal {
        uint256 elapsed = block.timestamp - lastReport;
        if (elapsed == 0 || decayPerSecond == 0) {
            lastReport = block.timestamp;
            return;
        }

        uint256 base = super.totalAssets();
        uint256 decayAmount = (base * decayPerSecond * elapsed) / 1e18;
        if (decayAmount > 0) {
            underlyingMock.burn(
                address(this),
                decayAmount > underlyingMock.balanceOf(address(this))
                    ? underlyingMock.balanceOf(address(this))
                    : decayAmount
            );
        }
        lastReport = block.timestamp;
    }
}
