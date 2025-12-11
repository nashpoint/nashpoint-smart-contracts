// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Mock} from "../ERC20Mock.sol";

/**
 * @title ERC4626LinearYieldVault
 * @notice ERC4626 vault whose share price increases linearly over time.
 * @dev Yield is minted deterministically using the underlying ERC20Mock.
 */
contract ERC4626LinearYieldVault is ERC4626 {
    uint256 public immutable ratePerSecond; // scaled by 1e18 = 100% per second
    uint256 public lastReport;
    ERC20Mock internal immutable underlyingMock;

    constructor(address underlying, string memory name_, string memory symbol_, uint256 ratePerSecond_)
        ERC20(name_, symbol_)
        ERC4626(IERC20(underlying))
    {
        underlyingMock = ERC20Mock(underlying);
        ratePerSecond = ratePerSecond_;
        lastReport = block.timestamp;
    }

    function totalAssets() public view override returns (uint256) {
        uint256 base = super.totalAssets();
        uint256 elapsed = block.timestamp - lastReport;
        if (elapsed == 0 || ratePerSecond == 0) {
            return base;
        }
        uint256 interest = (base * ratePerSecond * elapsed) / 1e18;
        return base + interest;
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        _syncYield();
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        _syncYield();
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        _syncYield();
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        _syncYield();
        return super.redeem(shares, receiver, owner);
    }

    function _syncYield() internal {
        uint256 elapsed = block.timestamp - lastReport;
        if (elapsed == 0 || ratePerSecond == 0) {
            lastReport = block.timestamp;
            return;
        }

        uint256 base = super.totalAssets();
        uint256 interest = (base * ratePerSecond * elapsed) / 1e18;
        if (interest > 0) {
            underlyingMock.mint(address(this), interest);
        }
        lastReport = block.timestamp;
    }
}
