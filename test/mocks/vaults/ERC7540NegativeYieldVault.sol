// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../ERC20Mock.sol";
import {ERC7540Mock} from "../ERC7540Mock.sol";

/**
 * @title ERC7540NegativeYieldVault
 * @notice Async vault mock with deterministic linear decay of underlying assets.
 */
contract ERC7540NegativeYieldVault is ERC7540Mock {
    uint256 public immutable decayPerSecond; // scaled by 1e18
    uint256 public lastReport;
    ERC20Mock internal immutable underlyingMock;

    constructor(IERC20 asset_, string memory name_, string memory symbol_, address manager_, uint256 decayPerSecond_)
        ERC7540Mock(asset_, name_, symbol_, manager_)
    {
        underlyingMock = ERC20Mock(address(asset_));
        decayPerSecond = decayPerSecond_;
        lastReport = block.timestamp;
    }

    function requestDeposit(uint256 assets, address controller, address owner) public override returns (uint256) {
        _syncDecay();
        return super.requestDeposit(assets, controller, owner);
    }

    function processPendingDeposits() public override {
        _syncDecay();
        super.processPendingDeposits();
    }

    function mint(uint256 shares, address receiver, address controller) public override returns (uint256 assets) {
        _syncDecay();
        return super.mint(shares, receiver, controller);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        _syncDecay();
        return super.withdraw(assets, receiver, owner);
    }

    function requestRedeem(uint256 shares, address controller, address owner) public override returns (uint256) {
        _syncDecay();
        return super.requestRedeem(shares, controller, owner);
    }

    function processPendingRedemptions() public override {
        _syncDecay();
        super.processPendingRedemptions();
    }

    function _syncDecay() internal {
        uint256 elapsed = block.timestamp - lastReport;
        if (elapsed == 0 || decayPerSecond == 0) {
            lastReport = block.timestamp;
            return;
        }

        uint256 currentBalance = IERC20(asset).balanceOf(address(this));
        uint256 decayAmount = (currentBalance * decayPerSecond * elapsed) / 1e18;
        if (decayAmount > 0) {
            uint256 burnAmount = decayAmount > currentBalance ? currentBalance : decayAmount;
            underlyingMock.burn(address(this), burnAmount);
        }
        lastReport = block.timestamp;
    }
}
