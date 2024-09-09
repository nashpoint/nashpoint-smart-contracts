// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {IERC7540} from "src/interfaces/IERC7540.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

contract Bestia is ERC4626, Ownable {
    // State Constants
    uint256 public constant maxDiscount = 2e16; // percentage
    uint256 public constant targetReserveRatio = 10e16; // percentage
    uint256 public constant maxDelta = 1e16; // percentage
    uint256 public constant asyncMaxDelta = 3e16; //percentage
    int256 public constant scalingFactor = -5e18; // negative integer
    uint256 public constant internalPrecision = 1e18; // convert all assets to this precision

    // PRBMath Types and Conversions
    SD59x18 maxDiscountSD = sd(int256(maxDiscount));
    SD59x18 targetReserveRatioSD = sd(int256(targetReserveRatio));
    SD59x18 scalingFactorSD = sd(scalingFactor);

    address public banker;
    IERC4626 public vaultA;
    IERC4626 public vaultB;
    IERC4626 public vaultC;
    IERC7540 public liquidityPool;
    IERC20Metadata public usdc;

    // COMPONENTS DATA
    struct Component {
        address component;
        uint256 targetRatio;
        bool isAsync;
        address shareToken;
    }

    Component[] public components;
    mapping(address => uint256) public componentIndex;

    // EVENTS
    event CashInvested(uint256 amount, address depositedTo);
    event DepositRequested(uint256 amount, address depositedTo);
    event ComponentAdded(address component, uint256 ratio, bool isAsync, address shareToken);
    event AsyncSharesMinted(address component, uint256 shares);
    event AsyncWithdrawalRequested(address component, uint256 shares);
    event AsyncWithdrawalExecuted(address component, uint256 assets);

    // ERRORS TODO: rename these errors to be more descriptive and include contract name
    error ReserveBelowTargetRatio();
    error AsyncAssetBelowMinimum();
    error NotEnoughReserveCash();
    error NotAComponent();
    error ComponentWithinTargetRange();
    error IsAsyncVault();
    error IsNotAsyncVault();
    error NoClaimableDeposit();
    error TooManySharesRequested();
    error TooManyAssetsRequested();

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
        address _liquidityPool,
        address _banker
    ) ERC20(_name, _symbol) ERC4626(IERC20Metadata(_asset)) Ownable(msg.sender) {
        vaultA = IERC4626(_vaultA);
        vaultB = IERC4626(_vaultB);
        vaultC = IERC4626(_vaultC);
        liquidityPool = IERC7540(_liquidityPool);
        usdc = IERC20Metadata(_asset);
        banker = _banker;
    }

    // total assets override function
    // must add async component for call to bestia.totalAssets to succeed
    // todo: refactor totalAssets to avoid this issue later
    function totalAssets() public view override returns (uint256) {
        // gets the cash reserve
        uint256 cashReserve = usdc.balanceOf(address(this));

        // gets value of async assets
        uint256 asyncAssets = getAsyncAssets(address(liquidityPool));

        // gets the liquid assets balances
        uint256 liquidAssets = vaultA.convertToAssets(vaultA.balanceOf(address(this)))
            + vaultB.convertToAssets(vaultB.balanceOf(address(this)))
            + vaultC.convertToAssets(vaultC.balanceOf(address(this)));

        return cashReserve + asyncAssets + liquidAssets;
    }

    // TODO: check how much gas this uses. might need to cache data instead
    function getAsyncAssets(address _component) public view returns (uint256 assets) {
        // Get the asset value of any shares already minted
        IERC20 shareToken = IERC20(getComponentShareAddress(_component));
        uint256 shareBalance = shareToken.balanceOf(address(this));
        assets = IERC7540(_component).convertToAssets(shareBalance);

        // Add pending deposits (in assets)
        try IERC7540(_component).pendingDepositRequest(0, address(this)) returns (uint256 pendingDepositAssets) {
            assets += pendingDepositAssets;
        } catch {}

        // Add claimable deposits (convert shares to assets)
        try IERC7540(_component).claimableDepositRequest(0, address(this)) returns (uint256 claimableShares) {
            assets += IERC7540(_component).convertToAssets(claimableShares);
        } catch {}

        // Add pending redemptions (convert shares to assets)
        try IERC7540(_component).pendingRedeemRequest(0, address(this)) returns (uint256 pendingRedeemShares) {
            assets += IERC7540(_component).convertToAssets(pendingRedeemShares);
        } catch {}

        // Add claimable redemptions (already in assets)
        try IERC7540(_component).claimableRedeemRequest(0, address(this)) returns (uint256 claimableRedeemAssets) {
            assets += claimableRedeemAssets;
        } catch {}

        return assets;
    }

    function mintClaimableShares(address _component) public onlyBanker returns (uint256) {
        uint256 claimableShares = IERC7540(_component).claimableDepositRequest(0, address(this));
        if (claimableShares == 0) {
            revert NoClaimableDeposit();
        }
        liquidityPool.mint(claimableShares, address(this));

        emit AsyncSharesMinted(_component, claimableShares);
        return claimableShares;
    }

    // requests withdrawal from async vault
    function requestAsyncWithdrawal(address _component, uint256 _shares) public onlyBanker {
        if (_shares > IERC7540(_component).balanceOf(address(this))) {
            revert TooManySharesRequested();
        }
        if (!isComponent(_component)) {
            revert NotAComponent();
        }
        if (!isAsync(_component)) {
            revert IsNotAsyncVault();
        }
        IERC7540(_component).requestRedeem(_shares, address(this), (address(this)));

        emit AsyncWithdrawalRequested(_component, _shares);

        // anything I should return here?
    }

    // withdraws claimable assets from async vault
    function executeAsyncWithdrawal(address _component, uint256 _assets) public onlyBanker {
        if (_assets > IERC7540(_component).claimableRedeemRequest(0, address(this))) {
            revert TooManyAssetsRequested();
        }
        if (!isComponent(_component)) {
            revert NotAComponent();
        }
        if (!isAsync(_component)) {
            revert IsNotAsyncVault();
        }
        IERC7540(_component).withdraw(_assets, address(this), address(this));

        emit AsyncWithdrawalExecuted(_component, _assets);
    }

    // TODO: Think aboout possible logical BUG
    // We are basing the discount on the reserve ratio after the transaction. 
    // This means while the RR is below target. There is actually an incentive to break
    // up a deposit into smaller transactions to receive a greater discount.
    function deposit(uint256 _assets, address receiver) public override returns (uint256) {
        uint256 internalAssets = toInternalPrecision(_assets);
        uint256 maxAssets = maxDeposit(receiver);
        if (internalAssets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, _assets, maxAssets);
        }

        // gets the expected reserve ratio after tx
        int256 reserveRatioAfterTX =
            int256(Math.mulDiv(toInternalPrecision(usdc.balanceOf(address(this))) + internalAssets, 1e18, toInternalPrecision(totalAssets()) + internalAssets));

        // gets the assets to be returned to the user after applying swingfactor to tx
        uint256 adjustedAssets = Math.mulDiv(internalAssets, (1e18 + getSwingFactor(reserveRatioAfterTX)), 1e18);

        // cache the shares to mint for swing factor applied
        uint256 sharesToMint = convertToShares(adjustedAssets);

        // recieves deposited assets but mints adjusted shares based on swing factor applied
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
        if (isAsyncAssetsBelowMinimum(address(liquidityPool))) {
            revert AsyncAssetBelowMinimum();
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

    // TODO: Create a buildTransaction() func that both investCash() and investInAsyncVault() can use
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
        uint256 currentAllocation = getAsyncAssets(_component) * 1e18 / totalAssets_;
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

        IERC7540(_component).requestDeposit(depositAmount, address(this), address(this));

        emit DepositRequested(depositAmount, address(_component));
        return (depositAmount);
    }

    function getDepositAmount(address _component) public view returns (uint256 depositAmount) {
        uint256 targetHoldings = totalAssets() * getComponentRatio(_component) / 1e18;
        uint256 currentBalance;

        if (isAsync(_component)) {
            currentBalance = getAsyncAssets(_component);
        } else {
            currentBalance = ERC20(_component).balanceOf(address(this));
        }

        uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
        return delta;
    }

    function addComponent(address _component, uint256 _targetRatio, bool _isAsync, address _shareToken) public {
        uint256 index = componentIndex[_component];

        if (index > 0) {
            components[index - 1].targetRatio = _targetRatio;
            components[index - 1].isAsync = _isAsync;
        } else {
            Component memory newComponent = Component({
                component: _component,
                targetRatio: _targetRatio,
                isAsync: _isAsync,
                shareToken: _shareToken
            });

            components.push(newComponent);
            componentIndex[_component] = components.length;
        }
        emit ComponentAdded(_component, _targetRatio, _isAsync, _shareToken);
    }

    function isComponent(address _component) public view returns (bool) {
        return componentIndex[_component] != 0;
    }

    function getComponentRatio(address _component) public view returns (uint256) {
        uint256 index = componentIndex[_component];
        require(index != 0, "Component does not exist");
        return components[index - 1].targetRatio;
    }

    function getComponentShareAddress(address _component) public view returns (address) {
        uint256 index = componentIndex[_component];
        require(index != 0, "Component does not exist");
        return components[index - 1].shareToken;
    }

    function isAsync(address _component) public view returns (bool) {
        uint256 index = componentIndex[_component];
        require(index != 0, "Component does not exist");
        return components[index - 1].isAsync;
    }

    function isAsyncAssetsBelowMinimum(address _component) public view returns (bool) {
        uint256 targetRatio = getComponentRatio(_component);
        if (targetRatio == 0) return false; // Always in range if target is 0
        return getAsyncAssets(_component) * 1e18 / totalAssets() < getComponentRatio(_component) - asyncMaxDelta;
    }

    function setBanker(address _banker) public onlyOwner {
        banker = _banker;
    }

    function toInternalPrecision(uint256 amount) internal view returns (uint256) {
        return amount * internalPrecision / (10 ** IERC20Metadata(asset()).decimals());
    }

    function toTokenPrecision(uint256 amount) internal view returns (uint256) {
        return amount * (10 ** IERC20Metadata(asset()).decimals()) / internalPrecision;
    }

    // temp
    // todo: delete after testing
    function _toInternalPrecision(uint256 amount) public view returns (uint256) {
        return toInternalPrecision(amount);
    }

    function previewDeposit(uint256 assets) public view override returns (uint256) {
        uint256 internalAssets = toInternalPrecision(assets);
        return _convertToShares(internalAssets, Math.Rounding.Floor);
    }
}
