// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../ERC20Mock.sol";
import {ERC7540Mock} from "../ERC7540Mock.sol";

/**
 * @title ERC7540LinearYieldVault
 * @notice Async vault mock with deterministic linear yield accrual.
 */
contract ERC7540LinearYieldVault is ERC7540Mock {
    uint256 public immutable ratePerSecond; // scaled by 1e18
    uint256 public lastReport;
    ERC20Mock internal immutable underlyingMock;

    constructor(IERC20 asset_, string memory name_, string memory symbol_, address manager_, uint256 ratePerSecond_)
        ERC7540Mock(asset_, name_, symbol_, manager_)
    {
        underlyingMock = ERC20Mock(address(asset_));
        ratePerSecond = ratePerSecond_;
        lastReport = block.timestamp;
    }

    function requestDeposit(uint256 assets, address controller, address owner) public override returns (uint256) {
        _syncYield();
        return super.requestDeposit(assets, controller, owner);
    }

    function processPendingDeposits() public override {
        _syncYield();
        super.processPendingDeposits();
    }

    function mint(uint256 shares, address receiver, address controller) public override returns (uint256 assets) {
        _syncYield();
        return super.mint(shares, receiver, controller);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        _syncYield();
        return super.withdraw(assets, receiver, owner);
    }

    function requestRedeem(uint256 shares, address controller, address owner) public override returns (uint256) {
        _syncYield();
        return super.requestRedeem(shares, controller, owner);
    }

    function processPendingRedemptions() public override {
        _syncYield();
        super.processPendingRedemptions();
    }

    function _syncYield() internal {
        uint256 elapsed = block.timestamp - lastReport;
        if (elapsed == 0 || ratePerSecond == 0) {
            lastReport = block.timestamp;
            return;
        }

        uint256 base = IERC20(asset).balanceOf(address(this));
        uint256 interest = (base * ratePerSecond * elapsed) / 1e18;
        if (interest > 0) {
            underlyingMock.mint(address(this), interest);
        }
        lastReport = block.timestamp;
    }
}
