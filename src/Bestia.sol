// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {IERC7540} from "src/interfaces/IERC7540.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";
import {console2} from "lib/forge-std/src/Test.sol";

contract Bestia is ERC4626, Ownable {
    // State Constants
    uint256 public constant maxDiscount = 2e16; // percentage
    uint256 public constant targetReserveRatio = 10e16; // percentage
    uint256 public constant maxDelta = 1e16; // percentage
    uint256 public constant asyncMaxDelta = 3e16; //percentage
    int256 public constant scalingFactor = -5e18; // negative integer

    uint256 pendingDeposits;

    // PRBMath Types and Conversions
    SD59x18 maxDiscountSD = sd(int256(maxDiscount));
    SD59x18 targetReserveRatioSD = sd(int256(targetReserveRatio));
    SD59x18 scalingFactorSD = sd(scalingFactor);

    address public banker;
    IERC4626 public vaultA;
    IERC4626 public vaultB;
    IERC4626 public vaultC;
    IERC4626 public tempRWA; // temp file, leave here for tests until you replace with 7540
    IERC7540 public liquidityPool; // real rwa
    IERC20Metadata public usdc; // using 18 instead of 6 decimals here

    // COMPONENTS DATA
    struct Component {
        address component;
        uint256 targetRatio;
        bool isAsync;
    }

    Component[] public components;
    mapping(address => uint256) public componentIndex;

    // EVENTS
    event CashInvested(uint256 amount, address depositedTo);
    event DepositRequested(uint256 amount, address depositedTo);
    event InvestedToRWA(uint256 amount, address depositedTo);
    event ComponentAdded(address _component, uint256 _ratio); // TODO: add bool

    // ERRORS
    error ReserveBelowTargetRatio();
    error NotEnoughReserveCash();
    error NotAComponent();
    error ComponentWithinTargetRange();
    error IsAsyncVault();
    error IsNotAsyncVault();

    // MODIFIERS
    modifier onlyBanker() {
        require(msg.sender == banker, "Issuer: Only banker can call this function");
        _;
    }

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _vaultA,
        address _vaultB,
        address _vaultC,
        address _tempRWA, // temp delete
        address _liquidityPool,
        address _banker
    ) ERC20(_name, _symbol) ERC4626(IERC20Metadata(_asset)) Ownable(msg.sender) {
        vaultA = IERC4626(_vaultA);
        vaultB = IERC4626(_vaultB);
        vaultC = IERC4626(_vaultC);
        tempRWA = IERC4626(_tempRWA); // temp delete
        liquidityPool = IERC7540(_liquidityPool);
        usdc = IERC20Metadata(_asset);
        banker = _banker;
    }

    // total assets override function
    function totalAssets() public view override returns (uint256) {
        uint256 depositAssetBalance = usdc.balanceOf(address(this));

        uint256 investedAssets = vaultA.convertToAssets(vaultA.balanceOf(address(this)))
            + vaultB.convertToAssets(vaultB.balanceOf(address(this)))
            + vaultC.convertToAssets(vaultC.balanceOf(address(this)))
            + tempRWA.convertToAssets(tempRWA.balanceOf(address(this)))
        // tracks the assets that are requested to be deposited
        + pendingDeposits;

        return depositAssetBalance + investedAssets;
    }

    function getAsyncVaultAssets(address _component) public view returns (uint256 assets) {
        uint256 vaultAssets;

        try IERC7540(_component).pendingDepositRequest(0, address(this)) returns (uint256 pendingAssets) {
            vaultAssets += pendingAssets;
        } catch {}

        try IERC7540(_component).claimableDepositRequest(0, address(this)) returns (uint256 claimableAssets) {
            vaultAssets += claimableAssets;
        } catch {}

        // Add more try-catch blocks here for other asset types if needed

        return vaultAssets;
    }

    // TODO: override deposit function
    function adjustedDeposit(uint256 _assets, address receiver) public returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (_assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, _assets, maxAssets);
        }

        // gets the expected reserve ratio after tx
        int256 reserveRatioAfterTX =
            int256(Math.mulDiv(usdc.balanceOf(address(this)) + _assets, 1e18, totalAssets() + _assets));

        // gets the assets to be returned to the user after applying swingfactor to tx
        uint256 adjustedAssets = Math.mulDiv(_assets, (1e18 + getSwingFactor(reserveRatioAfterTX)), 1e18);

        // cache the shares to mint for swing factor applied
        uint256 sharesToMint = convertToShares(adjustedAssets);

        // recieves deposited assets but mints more shares based on swing factor applied
        _deposit(_msgSender(), receiver, _assets, sharesToMint);

        return (sharesToMint);
    }

    // TODO: override withdraw function
    function adjustedWithdraw(uint256 _assets, address receiver, address _owner) public returns (uint256) {
        uint256 balance = usdc.balanceOf(address(this));
        if (_assets > balance) {
            revert NotEnoughReserveCash();
        }

        uint256 maxAssets = maxWithdraw(_owner);
        if (_assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(_owner, _assets, maxAssets);
        }

        // gets the expected reserve ratio after tx
        int256 reserveRatioAfterTX = int256(Math.mulDiv(balance - _assets, 1e18, totalAssets() - _assets));

        // gets the assets to be returned to the user after applying swingfactor to tx
        uint256 adjustedAssets = Math.mulDiv(_assets, (1e18 - getSwingFactor(reserveRatioAfterTX)), 1e18);

        // cache the share value associated with no swing factor
        uint256 sharesToBurn = previewWithdraw(_assets);

        // returns the adjustedAssets to user but burns the correct amount of shares
        _withdraw(_msgSender(), receiver, _owner, adjustedAssets, sharesToBurn);

        return sharesToBurn;
    }

    // swing price curve equation
    // getSwingFactor() converts from int to uint
    // TODO: change to private internal later and change test use a wrapper function in test contract
    function getSwingFactor(int256 _reserveRatioAfterTX) public view returns (uint256 swingFactor) {
        // checks if withdrawal will exceed available reserve
        if (_reserveRatioAfterTX <= 0) {
            revert NotEnoughReserveCash();

            // else if reserve exceeds target after deposit no swing factor is applied
        } else if (uint256(_reserveRatioAfterTX) >= targetReserveRatio) {
            return 0;

            // else swing factor is applied
        } else {
            SD59x18 reserveRatioAfterTX = sd(int256(_reserveRatioAfterTX));

            SD59x18 result = maxDiscountSD * exp(scalingFactorSD.div(targetReserveRatioSD).mul(reserveRatioAfterTX));

            return uint256(result.unwrap());
        }
    }

    // called by banker to deposit excess reserve into strategies
    // TODO: refactor this into something more efficient and include getDepositAmount logic
    function investCash(address _component) external onlyBanker returns (uint256 cashInvested) {
        if (!isComponent(_component)) {
            revert NotAComponent();
        }

        if (isAsync(_component)) {
            revert IsAsyncVault();
        }

        uint256 totalAssets_ = totalAssets();
        uint256 idealCashReserve = totalAssets_ * targetReserveRatio / 1e18;
        uint256 currentCash = usdc.balanceOf(address(this));

        // checks if available reserve exceeds target ratio
        if (currentCash < idealCashReserve) {
            revert ReserveBelowTargetRatio();
        }

        // gets deposit amount
        uint256 depositAmount = getDepositAmount(_component);

        // checks if asset is within acceptable range of target
        if (depositAmount < (totalAssets_ * maxDelta / 1e18)) {
            revert ComponentWithinTargetRange();
        }

        // get max transaction size that will maintain reserve ratio
        uint256 availableReserve = currentCash - idealCashReserve;

        // limits the depositAmount to this transaction size
        if (depositAmount > availableReserve) {
            depositAmount = availableReserve;
        }

        ERC4626(_component).deposit(depositAmount, address(this));

        emit CashInvested(depositAmount, address(_component));
        return (depositAmount);
    }

    function investInAsyncVault(address _component) external onlyBanker returns (uint256 cashInvested) {
        if (!isComponent(_component)) {
            revert NotAComponent();
        }

        if (!isAsync(_component)) {
            revert IsNotAsyncVault();
        }

        uint256 totalAssets_ = totalAssets();
        uint256 idealCashReserve = totalAssets_ * targetReserveRatio / 1e18;
        uint256 currentCash = usdc.balanceOf(address(this));

        // checks if available reserve exceeds target ratio
        if (currentCash < idealCashReserve) {
            revert ReserveBelowTargetRatio();
        }

        // gets deposit amount
        uint256 depositAmount = getDepositAmount(_component);

        // Check if the current allocation is below the lower bound
        uint256 currentAllocation = (ERC20(_component).balanceOf(address(this)) + pendingDeposits) * 1e18 / totalAssets_;
        uint256 lowerBound = getComponentRatio(_component) - asyncMaxDelta;

        if (currentAllocation >= lowerBound) {
            revert ComponentWithinTargetRange();
        }

        // get max transaction size that will maintain reserve ratio
        uint256 availableReserve = currentCash - idealCashReserve;

        // limits the depositAmount to this transaction size
        if (depositAmount > availableReserve) {
            depositAmount = availableReserve;
        }

        // append this value to pendingDeposits
        pendingDeposits += depositAmount;

        IERC7540(_component).requestDeposit(depositAmount, address(this), address(this));

        emit DepositRequested(depositAmount, address(_component));
        return (depositAmount);
    }

    // TODO: refactor this into investCash() and make it all more efficient
    // function getDepositAmount(address _component) public view returns (uint256 depositAmount) {

    //     if (!isAsync(_component)) {
    //         // calculate target holdings for that component
    //         uint256 targetHoldings = totalAssets() * getComponentRatio(_component) / 1e18;
    //         uint256 currentBalance = ERC20(_component).balanceOf(address(this));

    //         uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
    //         return (delta);
    //     }

    //     if (isAsync(_component)) {
    //         // calculate target holdings for that component
    //         uint256 targetHoldings = totalAssets() * getComponentRatio(_component) / 1e18;
    //         uint256 currentBalance = ERC20(_component).balanceOf(address(this));

    //         uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
    //         return (delta);
    //     }
    // }

    function getDepositAmount(address _component) public view returns (uint256 depositAmount) {
        uint256 targetHoldings = totalAssets() * getComponentRatio(_component) / 1e18;
        uint256 currentBalance;

        if (isAsync(_component)) {
            currentBalance = ERC20(_component).balanceOf(address(this)) + pendingDeposits;
        } else {
            currentBalance = ERC20(_component).balanceOf(address(this));
        }

        uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
        return delta;
    }

    function addComponent(address _component, uint256 _targetRatio, bool _isAsync) public {
        uint256 index = componentIndex[_component];

        if (index > 0) {
            components[index - 1].targetRatio = _targetRatio;
            components[index - 1].isAsync = _isAsync;
        } else {
            Component memory newComponent =
                Component({component: _component, targetRatio: _targetRatio, isAsync: _isAsync});

            components.push(newComponent);
            componentIndex[_component] = components.length;
        }
    }

    function isComponent(address _component) public view returns (bool) {
        return componentIndex[_component] != 0;
    }

    function getComponentRatio(address _component) public view returns (uint256) {
        uint256 index = componentIndex[_component];
        require(index != 0, "Component does not exist");
        return components[index - 1].targetRatio;
    }

    function isAsync(address _component) public view returns (bool) {
        uint256 index = componentIndex[_component];
        require(index != 0, "Component does not exist");
        return components[index - 1].isAsync;
    }

    function setBanker(address _banker) public onlyOwner {
        banker = _banker;
    }
}
