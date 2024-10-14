// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {IERC7540} from "src/interfaces/IERC7540.sol";
import {IERC7540Redeem} from "src/interfaces/IERC7540Redeem.sol";
import {IEscrow} from "src/Escrow.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

// temp: delete before deploying
import {console2} from "forge-std/Test.sol";

contract Node is ERC4626, ERC165, Ownable, IERC7540Redeem, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                    DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice parameter values set by node owner to control rebalancing and swing pricing
    ///     maxDiscount: Maximum discount applied by swing pricing.
    ///     targetReserveRatio: Target reserve ratio to maintain in the vault.
    ///     maxDelta: Max allowable deviation for synchronous assets from target ratio.
    ///     asyncMaxDelta: Max allowable deviation for asynchronous assets from target ratio.
    ///     instantLiquidationsEnabled: Controls whether instant liquidations are allowed.
    ///     swingPricingEnabled: Enables/disables swing pricing.
    ///     liquidateReserveBelowTarget: rebalancer can use reserve below target ratio to fulfilRedeem
    /// @notice hardcoded values:
    ///     scalingFactor: Used in swing pricing calculations. Fixed at -5e18.
    ///     internalPrecision: Precision used for internal asset calculations, fixed at 1e18.

    uint256 public maxDiscount;
    uint256 public targetReserveRatio;
    uint256 public maxDelta;
    uint256 public asyncMaxDelta;
    bool public instantLiquidationsEnabled = true;
    bool public swingPricingEnabled = false;
    bool public liquidateReserveBelowTarget = true;
    int256 public immutable SCALING_FACTOR = -5e18;
    uint256 public immutable WAD = 1e18;

    /// @dev Requests for nodes are non-fungible and all have ID = 0 (ERC-7540)
    uint256 private constant REQUEST_ID = 0;

    /// @notice key addresses
    ///     rebalancer: initial rebalancer address set by constructor
    ///     escrow: address used for storing pending shares and claimable assets
    address public rebalancer;
    IEscrow public escrow;

    /// @dev PRBMath types and conversions: used for swing price calculations
    SD59x18 maxDiscountSD;
    SD59x18 targetReserveRatioSD;
    SD59x18 scalingFactorSD;

    /// @dev holds information about each asset in the node
    struct Component {
        address component;
        uint256 targetRatio;
        bool isAsync; // todo: make this more flexible when we add modules
        address shareToken;
    }

    /// @dev holds data for withdrawal requests (ERC-7540)
    /// @notice sharesAdjusted holds reduced share value after swing price applied
    struct Request {
        address controller;
        uint256 sharesPending;
        uint256 sharesClaimable;
        uint256 assetsClaimable;
        uint256 sharesAdjusted;
    }

    /// @dev components array & mapping to index of component addresses
    Component[] public components;
    mapping(address => uint256) public componentIndex;

    /// @dev requests array & mapping to index of controllers redeeming
    Request[] public redeemRequests;
    mapping(address => uint256) public controllerToRedeemIndex;

    /// @dev mapping of valid operators set by controllers (users depositing in the node)
    /// @notice enables a controller to grant permission to operator to execute async redeems
    mapping(address => mapping(address => bool)) private _operators;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the contract with initial values and settings.
     * @dev Initializes ERC20, ERC4626, and Ownable inheritance. Configures initial parameters and rebalancer.
     * @param _asset The address of the ERC20 token used for deposits.
     * @param _name The name of the ERC20 token.
     * @param _symbol The symbol of the ERC20 token.
     * @param _rebalancer The address of the rebalancer.
     * @param _maxDiscount The maximum discount for swing pricing.
     * @param _targetReserveRatio The target ratio for the cash reserve.
     * @param _maxDelta The maximum delta allowed for the asset allocation.
     * @param _asyncMaxDelta The maximum delta for asynchronous assets.
     * @param _owner The address of the contract owner.
     */
    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _rebalancer,
        uint256 _maxDiscount,
        uint256 _targetReserveRatio,
        uint256 _maxDelta,
        uint256 _asyncMaxDelta,
        address _owner
    ) ERC20(_name, _symbol) ERC4626(IERC20Metadata(_asset)) Ownable(_owner) {
        require(_rebalancer != address(0), "Rebalancer address cannot be zero");

        rebalancer = _rebalancer;
        maxDiscount = _maxDiscount;
        targetReserveRatio = _targetReserveRatio;
        maxDelta = _maxDelta;
        asyncMaxDelta = _asyncMaxDelta;

        // PRBMath Types and Conversions
        maxDiscountSD = sd(int256(maxDiscount));
        targetReserveRatioSD = sd(int256(targetReserveRatio));
        scalingFactorSD = sd(SCALING_FACTOR);
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CashInvested(uint256 amount, address depositedTo);
    event DepositRequested(uint256 amount, address depositedTo);
    event ComponentAdded(address component, uint256 ratio, bool isAsync, address shareToken);
    event AsyncSharesMinted(address component, uint256 shares);
    event AsyncWithdrawalRequested(address component, uint256 shares);
    event AsyncWithdrawalExecuted(address component, uint256 assets);
    event WithdrawalFundsSentToEscrow(address escrow, address token, uint256 assets);
    event SwingPricingStatusUpdated(bool status);
    event LiquidateReserveBelowTargetStatus(bool status);
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                            ERROR HANDLING
    ////////////////////////////////////////////////////////////////*/

    error ReserveBelowTargetRatio();
    error AsyncAssetBelowMinimum();
    error NotEnoughReserveCash();
    error InvalidNumberToGetSwingFactor(int256 value);
    error NotAComponent();
    error ComponentWithinTargetRange();
    error IsAsyncVault();
    error IsNotAsyncVault();
    error NoClaimableDeposit();
    error TooManySharesRequested();
    error TooManyAssetsRequested();
    error CannotRedeemZeroShares();
    error DepositToEscrowFailed();
    error UserLiquidationsDisabled();
    error CannotLiquidate();
    error NoRedeemRequestForController();
    error ExceededMaxWithdraw(address controller, uint256 assets, uint256 maxAssets);
    error ExceededMaxRedeem(address controller, uint256 shares, uint256 maxShares);
    error ExceedsMaxVaultDeposit(address component, uint256 depositAmount, uint256 maxDepositAmount);

    /*//////////////////////////////////////////////////////////////
                        USER DEPOSIT LOGIC 
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice A Swing Factor is applied to deposits that rewards users who deposit while the cash
     * reserve is below target ratio with a discount on their share price. The swing factor is applied
     * in the function getSwingFactor() that take a value for the reserve ratio after the deposit.
     * @dev The swing factor relies on the PRBMath library: https://github.com/PaulRBerg/prb-math to
     * handle e^ exponents and other computations.
     * @dev the user deposit/mint logic follows standard ERC-4626 interface.
     */
    function totalAssets() public view override returns (uint256) {
        // gets the cash reserve
        uint256 cashReserve = IERC20(asset()).balanceOf(address(this));

        // set investedAssets to zero and start cycle through components array
        uint256 investedAssets = 0;
        uint256 length = components.length;
        for (uint256 i = 0; i < length; i++) {
            Component memory component = components[i];

            // if not async use 4626 interface to store assets
            if (!component.isAsync) {
                IERC4626 syncAsset = IERC4626(component.component);
                investedAssets += syncAsset.convertToAssets(syncAsset.balanceOf(address(this)));

                /// @notice Async asset can be in several states - pending, claimable, deposit, withdrawal. getAsyncAssets converts a position in any of those states to assets value based on  current price
            } else {
                investedAssets += getAsyncAssets(address(component.component));
            }
        }

        return cashReserve + investedAssets;
    }

    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        // Handle initial deposit separately to avoid divide by zero
        uint256 sharesToMint;
        if (totalAssets() == 0 && totalSupply() == 0) {
            // This is the first deposit
            sharesToMint = convertToShares(assets);
            _deposit(_msgSender(), receiver, assets, sharesToMint);
            return sharesToMint;
        }

        // Revert if the deposit exceeds the maximum allowed deposit for the receiver.
        if (assets > maxDeposit(receiver)) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxDeposit(receiver));
        }

        uint256 reserveCash = IERC20(asset()).balanceOf(address(this));
        uint256 investedAssets = totalAssets() - reserveCash;
        uint256 targetReserve = Math.mulDiv(investedAssets, WAD, (WAD - targetReserveRatio)) - investedAssets;

        // get the absolute value of delta between actual and target reserve
        uint256 reserveDeltaAbs = 0;
        if (reserveCash < targetReserve) {
            reserveDeltaAbs = targetReserve - reserveCash;
        }

        // subtract the value of the new deposit to get the reserve delta after
        // if new deposit exceeds the reserve delta, the reserve delta after will be zero
        uint256 deltaAfter = 0;
        if (reserveDeltaAbs > assets) {
            deltaAfter = reserveDeltaAbs - assets;
        } else {
            deltaAfter = 0;
        }

        // get the absolute value of the delta closed and divide by target reserve to get the percentage of the reserve delta that was closed by the deposit
        uint256 deltaClosedAbs = reserveDeltaAbs - deltaAfter;
        uint256 deltaClosedPercent = Math.mulDiv(deltaClosedAbs, WAD, targetReserve);

        int256 inverseValue = int256(Math.mulDiv((WAD - deltaClosedPercent), targetReserveRatio, WAD));

        // Adjust the deposited assets based on the swing pricing factor.
        uint256 adjustedAssets = Math.mulDiv(assets, (WAD + getSwingFactor(inverseValue)), WAD);

        // Calculate the number of shares to mint based on the adjusted assets.
        sharesToMint = convertToShares(adjustedAssets);

        // Mint shares for the receiver.
        _deposit(_msgSender(), receiver, assets, sharesToMint);

        // todo: emit an event to match 4626

        return (sharesToMint);
    }

    /// @notice reuses the same logic as deposit()
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        uint256 assets = convertToAssets(shares);
        deposit(assets, receiver);

        return assets;
    }

    /// @notice reserveImpact is a different value based on what transaction is executed
    ///     for deposits: input value is reserve delta closed by transaction
    ///     for withdrawals: input value is reserve ratio after transaction
    /// @dev getSwingFactor() converts from int to uint to use PRBMath SD59x18 type
    // todo: change to private internal later and change test use a wrapper function in test contract
    function getSwingFactor(int256 reserveImpact) public view returns (uint256 swingFactor) {
        if (!swingPricingEnabled) {
            return 0;
        }
        // checks if a negative number
        if (reserveImpact < 0) {
            revert InvalidNumberToGetSwingFactor(reserveImpact);

            // else if reserve exceeds target after deposit no swing factor is applied
        } else if (uint256(reserveImpact) >= targetReserveRatio) {
            return 0;

            // else swing factor is applied
        } else {
            SD59x18 reserveImpactSd = sd(int256(reserveImpact));

            SD59x18 result = maxDiscountSD * exp(scalingFactorSD.mul(reserveImpactSd).div(targetReserveRatioSD));

            return uint256(result.unwrap());
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ASYNC USER WITHDRAWAL LOGIC (7540)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice node.sol is a asynchronous ERC-7540 withdrawal vault. To remove funds, controllers must
     * request a redemption to receive their deposited funds & accrued interest. When a user requests
     * a redemptions, their shares are transfered to the escrow.sol address specific to this node.
     * Their request will remain in a pending state until a rebalancer address makes funds available
     * or withdrawal. At this time, the request is made claimable, and the shares previously
     * transfered to escrow are burned and the corresponding amount of assets are transfered to the
     * escrow where the controller can withdraw.
     *
     * @dev This ensure totalAssets() and totalSupply of the node address are in sync
     * @dev A controller can also whitelist an operator to execute this withdrawal function
     * @dev the amount of assets available for withdrawal is stored in maxWithdraw and maxRedeem
     * @dev redeem() and withdaw() will both revert if the controller address has no claimable assets
     *
     * @notice Swing Pricing is applied to redemptions requests based on the amount of reserve asset
     * that will remain in the vault when all pendingRedemptions have been liquidated. This ensures
     * withdrawing users will always pay for the liquidity they use per swing factor logic
     */

    // user requests to redeem their funds from the vault. they send their shares to the escrow contract
    function requestRedeem(uint256 shares, address controller, address _owner)
        external
        nonReentrant
        returns (uint256)
    {
        require(shares > 0, "Cannot request redeem of 0 shares");
        require(balanceOf(_owner) >= shares, "Insufficient shares");
        require(_owner == msg.sender || isOperator(_owner, msg.sender), "msg.sender is not owner");

        // get the cash balance of the node and pending redemptions
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        uint256 pendingRedemptions = getPendingRedeemAssets();

        // check if pending redemptions exceed current cash balance
        // if not subtract pending redemptions from balance
        if (pendingRedemptions > balance) {
            balance = 0;
        } else {
            balance = balance - pendingRedemptions;
        }

        // get the asset value of the redeem request
        uint256 assets = convertToAssets(shares);

        // gets the expected reserve ratio after tx
        // check redemption (assets) exceed current cash balance
        // if not get reserve ratio
        int256 reserveRatioAfterTX;
        if (assets > balance) {
            reserveRatioAfterTX = 0;
        } else {
            reserveRatioAfterTX = int256(Math.mulDiv(balance - assets, WAD, totalAssets() - assets));
        }

        // gets the assets to be returned to the user after applying swingfactor to tx
        uint256 adjustedAssets = Math.mulDiv(assets, (WAD - getSwingFactor(reserveRatioAfterTX)), WAD);

        uint256 sharesToBurn = convertToShares(adjustedAssets);

        uint256 index = controllerToRedeemIndex[controller];

        if (index > 0) {
            redeemRequests[index - 1].sharesPending += shares;
        } else {
            Request memory newRequest = Request({
                controller: controller,
                sharesPending: shares,
                sharesClaimable: 0,
                assetsClaimable: 0,
                sharesAdjusted: sharesToBurn
            });

            redeemRequests.push(newRequest);
            controllerToRedeemIndex[controller] = redeemRequests.length;
        }

        emit RedeemRequest(controller, _owner, REQUEST_ID, msg.sender, shares);

        // Transfer ERC4626 share tokens from owner back to vault
        IERC20(address(this)).safeTransferFrom(_owner, address(escrow), shares);

        return REQUEST_ID;
    }

    // view function to see redeem requests that cannot yet be withdrawn
    function pendingRedeemRequest(uint256, address controller) public view returns (uint256 shares) {
        uint256 index = controllerToRedeemIndex[controller];
        if (index > 0) {
            return redeemRequests[index - 1].sharesPending;
        } else {
            return 0;
        }
    }

    // view function to see redeem requests that can be withdrawn
    function claimableRedeemRequest(uint256, address controller) public view returns (uint256 shares) {
        uint256 index = controllerToRedeemIndex[controller];
        if (index > 0) {
            return redeemRequests[index - 1].sharesClaimable;
        } else {
            return 0;
        }
    }

    // check if controller has set an operator
    function isOperator(address controller, address operator) public view returns (bool status) {
        return _operators[controller][operator];
    }

    // controller sets operator
    function setOperator(address operator, bool approved) public returns (bool success) {
        emit OperatorSet(msg.sender, operator, approved);
        _operators[msg.sender][operator] = approved;
        return true;
    }

    /// @dev rebalancer only function to process redemptions from reserve
    function fulfilRedeemFromReserve(address _controller) public onlyRebalancer {
        uint256 index = controllerToRedeemIndex[_controller];
        uint256 balance = IERC20(asset()).balanceOf(address(this));

        // Ensure there is a pending request for this controller
        if (index == 0) {
            revert NoRedeemRequestForController();
        }

        Request storage request = redeemRequests[index - 1];
        address escrowAddress = address(escrow);

        uint256 sharesPending = request.sharesPending;
        uint256 sharesAdjusted = request.sharesAdjusted;

        uint256 assets = convertToAssets(sharesAdjusted);

        // get reserve ratio after tx
        uint256 reserveRatioAfterTx = Math.mulDiv(balance - assets, WAD, totalAssets() - assets);

        // first checks if manager has enabled liquidate below target
        // -- will revert if withdawal will reduce reserve below target ratio
        // -- if passes, it demonstrate that withdrawal amount < total reserve balance
        if (!liquidateReserveBelowTarget) {
            if (reserveRatioAfterTx < targetReserveRatio) {
                revert NotEnoughReserveCash();
            }
        }

        // check that current reserve is enough for redeem
        if (assets > balance) {
            revert NotEnoughReserveCash();
        }

        // update balances in Request
        request.sharesPending -= sharesPending; // shares removed from pending
        request.sharesClaimable += sharesPending; // shares added to claimable
        request.assetsClaimable += assets; // assets added to claimable
        request.sharesAdjusted -= sharesAdjusted; // shares removed from adjusted

        // Burn the shares on escrow
        _burn(escrowAddress, sharesPending);

        emit WithdrawalFundsSentToEscrow(escrowAddress, asset(), assets);

        // Transfer tokens to Escrow
        IERC20(asset()).safeTransfer(escrowAddress, assets);

        // Call deposit function on Escrow
        escrow.deposit(asset(), assets);
    }

    ////////////////////////// OVERRIDES ///////////////////////////

    /**
     * @dev these functions override ERC-4626 functions per ERC-7540 spec as they now relate to
     * redeem requests in a claimable state:
     * 1. maxWithdraw()
     * 2. maxRedeem()
     * 3. withdraw()
     * 4. redeem()
     *
     * See: https://eips.ethereum.org/EIPS/eip-7540
     */
    function maxWithdraw(address controller) public view override returns (uint256 maxAssets) {
        uint256 index = controllerToRedeemIndex[controller];
        if (index == 0) {
            revert NoRedeemRequestForController();
        } else {
            return redeemRequests[index - 1].assetsClaimable;
        }
    }

    function maxRedeem(address controller) public view override returns (uint256 maxShares) {
        uint256 index = controllerToRedeemIndex[controller];
        if (index == 0) {
            revert NoRedeemRequestForController();
        } else {
            return redeemRequests[index - 1].sharesClaimable;
        }
    }

    function withdraw(uint256 assets, address receiver, address controller)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        // grab the index for the controller
        uint256 _index = controllerToRedeemIndex[controller];

        // Ensure there is a pending request for this controller
        require(_index > 0, "No pending request for this controller");

        // Ensure that the msg.sender is the controller or operator for a controller
        require(controller == msg.sender || isOperator(controller, msg.sender), "Not authorized");

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);
        if (assets > maxAssets) {
            revert ExceededMaxWithdraw(controller, assets, maxAssets);
        }

        Request storage request = redeemRequests[_index - 1];

        shares = Math.mulDiv(assets, maxShares, maxAssets);

        request.sharesClaimable -= shares;
        request.assetsClaimable -= assets;

        escrow.withdraw(receiver, asset(), assets);

        // Need to emit anything?
        // TODO: overriding withdraw (4626) so need some event logic

        return shares;
    }

    function redeem(uint256 shares, address receiver, address controller)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        // grab the index for the controller
        uint256 _index = controllerToRedeemIndex[controller];

        // Ensure there is a pending request for this controller
        require(_index > 0, "No pending request for this controller");

        // Ensure that the msg.sender is the controller or operator for a controller
        require(controller == msg.sender || isOperator(controller, msg.sender), "Not authorized");

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);
        if (shares > maxShares) {
            revert ExceededMaxRedeem(controller, shares, maxShares);
        }

        Request storage request = redeemRequests[_index - 1];
        address escrowAddress = address(escrow);

        assets = Math.mulDiv(shares, maxAssets, maxShares);

        request.sharesClaimable -= shares;
        request.assetsClaimable -= assets;

        // using transferFrom as shares already burned when redeem made claimable
        IERC20(asset()).safeTransferFrom(escrowAddress, receiver, assets);

        // Need to emit anything?
        // TODO: overriding withdraw (4626) so need some event logic

        return assets;
    }

    function previewWithdraw(uint256) public view virtual override returns (uint256) {
        revert("ERC7540: previewWithdraw not available for async vault");
    }

    function previewRedeem(uint256) public view virtual override returns (uint256) {
        revert("ERC7540: previewRedeem not available for async vault");
    }

    /*//////////////////////////////////////////////////////////////
                ASYNC ASSET MANAGEMENT LOGIC (ERC-7540)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev this section contains all of the functions to define a value (in asset() terms) for any Async vault, and all of the functions to execute the investment strategy: requesting deposits and redemptions, executing the transfer of funds. Write functions can only be called by an authorized rebalancer account
     */

    // todo: check how much gas this uses. might need to cache data instead
    function getAsyncAssets(address component) public view returns (uint256 assets) {
        // Get the asset value of any shares already minted
        IERC20 shareToken = IERC20(getComponentShareAddress(component));
        uint256 shareBalance = shareToken.balanceOf(address(this));
        assets = IERC7540(component).convertToAssets(shareBalance);

        // Add pending deposits (in assets)
        try IERC7540(component).pendingDepositRequest(0, address(this)) returns (uint256 pendingDepositAssets) {
            assets += pendingDepositAssets;
        } catch {}

        // Add claimable deposits assets
        try IERC7540(component).claimableDepositRequest(0, address(this)) returns (uint256 claimableAssets) {
            assets += claimableAssets;
        } catch {}

        // Add pending redemptions (convert shares to assets)
        try IERC7540(component).pendingRedeemRequest(0, address(this)) returns (uint256 pendingRedeemShares) {
            assets += IERC7540(component).convertToAssets(pendingRedeemShares);
        } catch {}

        // Add claimable redemptions (convert shares to assets)
        try IERC7540(component).maxWithdraw(address(this)) returns (uint256 claimableAssets) {
            assets += claimableAssets;
        } catch {}

        return assets;
    }

    function investInAsyncVault(address component) external onlyRebalancer returns (uint256 cashInvested) {
        if (!isComponent(component)) {
            revert NotAComponent();
        }

        if (!isAsync(component)) {
            revert IsNotAsyncVault();
        }

        uint256 totalAssets_ = totalAssets();
        uint256 idealCashReserve = Math.mulDiv(totalAssets_, targetReserveRatio, WAD);
        uint256 currentCash = IERC20(asset()).balanceOf(address(this));

        // checks if available reserve exceeds target ratio
        if (currentCash < idealCashReserve) {
            revert ReserveBelowTargetRatio();
        }

        // gets deposit amount
        uint256 depositAmount = getInvestmentSize(component);

        // Check if the current allocation is below the lower bound
        uint256 currentAllocation = Math.mulDiv(getAsyncAssets(component), WAD, totalAssets_);
        uint256 lowerBound = getComponentRatio(component) - asyncMaxDelta;

        if (currentAllocation >= lowerBound) {
            revert ComponentWithinTargetRange();
        }

        // get max transaction size that will maintain reserve ratio
        uint256 availableReserve = currentCash - idealCashReserve;

        // limits the depositAmount to this transaction size
        if (depositAmount > availableReserve) {
            depositAmount = availableReserve;
        }

        emit DepositRequested(depositAmount, address(component));

        IERC20(asset()).safeIncreaseAllowance(component, depositAmount);
        (uint256 requestId) = IERC7540(component).requestDeposit(depositAmount, address(this), address(this));

        // checks request ID is returned successfully
        require(requestId == 0, "No requestId returned");

        return (depositAmount);
    }

    function mintClaimableShares(address component) public onlyRebalancer returns (uint256) {
        uint256 claimableShares = IERC7540(component).maxMint(address(this));

        emit AsyncSharesMinted(component, claimableShares);

        uint256 assets = IERC7540(component).mint(claimableShares, address(this));
        require(assets > 0, "No claimable shares minted");

        return claimableShares;
    }

    // requests withdrawal from async vault
    function requestAsyncWithdrawal(address component, uint256 _shares) public onlyRebalancer {
        IERC20 shareToken = IERC20(getComponentShareAddress(component));
        if (_shares > shareToken.balanceOf(address(this))) {
            revert TooManySharesRequested();
        }
        if (!isComponent(component)) {
            revert NotAComponent();
        }
        if (!isAsync(component)) {
            revert IsNotAsyncVault();
        }

        emit AsyncWithdrawalRequested(component, _shares);

        uint256 requestId = IERC7540(component).requestRedeem(_shares, address(this), (address(this)));
        require(requestId == 0, "No requestId returned");

        // todo: decide on return value (if any)
    }

    // withdraws claimable assets from async vault
    function executeAsyncWithdrawal(address component, uint256 assets) public onlyRebalancer {
        if (assets > IERC7540(component).maxWithdraw(address(this))) {
            revert TooManyAssetsRequested();
        }
        if (!isComponent(component)) {
            revert NotAComponent();
        }
        if (!isAsync(component)) {
            revert IsNotAsyncVault();
        }

        emit AsyncWithdrawalExecuted(component, assets);

        uint256 shares = IERC7540(component).withdraw(assets, address(this), address(this));
        require(shares > 0, "async withdrawal not executed");
    }

    /*//////////////////////////////////////////////////////////////
                SYNCHRONOUS ASSET MANAGEMENT LOGIC (4626)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev these two write functions relate to investing in a standard ERC-4626 synchronous vault. They can only be called by an authorized rebalancer account
     */

    // called by rebalancer to deposit excess reserve into strategies
    function investInSyncVault(address component) external onlyRebalancer returns (uint256 cashInvested) {
        if (!isComponent(component)) {
            revert NotAComponent();
        }
        if (isAsync(component)) {
            revert IsAsyncVault();
        }

        // checks all async vaults to see if they are below range will revert if true for any True
        // ensures
        uint256 length = components.length;
        for (uint256 i = 0; i < length; i++) {
            Component memory _component = components[i];
            if (_component.isAsync) {
                if (isAsyncAssetsBelowMinimum(address(_component.component))) {
                    revert AsyncAssetBelowMinimum();
                }
            }
        }

        uint256 totalAssets_ = totalAssets();
        uint256 idealCashReserve = Math.mulDiv(totalAssets_, targetReserveRatio, WAD);
        uint256 currentCash = IERC20(asset()).balanceOf(address(this));

        // checks if available reserve exceeds target ratio
        if (currentCash < idealCashReserve) {
            revert ReserveBelowTargetRatio();
        }

        // gets deposit amount
        uint256 depositAmount = getInvestmentSize(component);

        // checks if asset is within acceptable range of target
        if (depositAmount < Math.mulDiv(totalAssets_, maxDelta, WAD)) {
            revert ComponentWithinTargetRange();
        }

        // get max transaction size that will maintain reserve ratio
        uint256 availableReserve = currentCash - idealCashReserve;

        // limits the depositAmount to this transaction size
        if (depositAmount > availableReserve) {
            depositAmount = availableReserve;

            // Get the maximum deposit allowed by the component vault
            uint256 maxDepositAmount = ERC4626(component).maxDeposit(address(this));
            if (depositAmount > maxDepositAmount) {
                revert ExceedsMaxVaultDeposit(component, depositAmount, maxDepositAmount);
            }
        }

        emit CashInvested(depositAmount, address(component));

        // Approve the _component vault to spend depositAsset tokens & deposit to vault
        IERC20(asset()).safeIncreaseAllowance(component, depositAmount);
        uint256 shares = ERC4626(component).deposit(depositAmount, address(this));
        require(shares > 0, "synchronous deposit not executed");

        return (depositAmount);
    }

    // rebalancer to use this function to liquidate underlying vault to meet redeem requests
    function liquidateSyncVaultPosition(address component, uint256 shares)
        public
        onlyRebalancer
        returns (uint256 assetsReturned)
    {
        if (!isComponent(component)) {
            revert NotAComponent();
        }

        if (isAsync(component)) {
            revert IsAsyncVault();
        }

        if (ERC4626(component).balanceOf(address(this)) < shares) {
            revert TooManySharesRequested();
        }

        if (shares == 0) {
            revert CannotRedeemZeroShares();
        }

        // Preview the expected assets from redemption
        uint256 expectedAssets = ERC4626(component).previewRedeem(shares);

        // Perform the edemption
        uint256 assets = ERC4626(component).redeem(shares, address(this), address(this));

        // Ensure assets returned is within an acceptable range of expectedAssets
        require(assets >= expectedAssets, "Redeemed assets less than expected");

        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                        COMPONENT MANAGEMENT
    ////////////////////////////////////////////////////////////////*/

    /* 
    * The order in which components are added to the protocol determines their withdrawal order.
    * This requires careful management by the node owner 
    * Components must be ordered as follows:
    * 1. Synchronous assets
    * 2. Asynchronous assets
    * Failure to maintain this order will cause functions that interate through component array to revert.
    * note: formerly this logic was applied to "instant user liquidations", now removed
    * todo: add this functionality to constraints on balancer liquidation ability
    */

    function addComponent(address component, uint256 targetRatio, bool _isAsync, address shareToken) public onlyOwner {
        uint256 index = componentIndex[component];

        if (index > 0) {
            components[index - 1].targetRatio = targetRatio;
            components[index - 1].isAsync = _isAsync;
        } else {
            Component memory newComponent =
                Component({component: component, targetRatio: targetRatio, isAsync: _isAsync, shareToken: shareToken});

            components.push(newComponent);
            componentIndex[component] = components.length;
        }
        emit ComponentAdded(component, targetRatio, _isAsync, shareToken);
    }

    function isComponent(address component) public view returns (bool) {
        return componentIndex[component] != 0;
    }

    function getComponentRatio(address component) public view returns (uint256) {
        uint256 index = componentIndex[component];
        require(index != 0, "Component does not exist");
        return components[index - 1].targetRatio;
    }

    function getComponentShareAddress(address component) public view returns (address) {
        uint256 index = componentIndex[component];
        require(index != 0, "Component does not exist");
        return components[index - 1].shareToken;
    }

    function isAsync(address component) public view returns (bool) {
        uint256 index = componentIndex[component];
        require(index != 0, "Component does not exist");
        return components[index - 1].isAsync;
    }

    function isAsyncAssetsBelowMinimum(address component) public view returns (bool) {
        uint256 targetRatio = getComponentRatio(component);
        if (targetRatio == 0) return false; // Always in range if target is 0
        return Math.mulDiv(getAsyncAssets(component), WAD, totalAssets()) < getComponentRatio(component) - asyncMaxDelta;
    }

    /*//////////////////////////////////////////////////////////////
                        ESCROW INTERACTIONS
    ////////////////////////////////////////////////////////////////*/

    /**
     * @notice Escrow.sol receives shares for pending redeems and assets for claimable redeems.
     * @dev calling escrow.deposit() emits an event on escrow contract, not a write function so no
     * security checks
     */
    function executeEscrowDeposit(address tokenAddress, uint256 amount) external onlyRebalancer {
        IERC20 token = IERC20(tokenAddress);
        address escrowAddress = address(escrow);

        emit WithdrawalFundsSentToEscrow(escrowAddress, tokenAddress, amount);

        token.safeTransfer(escrowAddress, amount);

        // Call deposit function on Escrow
        escrow.deposit(tokenAddress, amount);
    }

    function setEscrow(address _escrow) public onlyOwner {
        escrow = IEscrow(_escrow);
    }

    /*//////////////////////////////////////////////////////////////
                        REBALANCER AND PERMISSIONS
    ////////////////////////////////////////////////////////////////*/

    function setRebalancer(address _rebalancer, bool allowed) public onlyOwner {
        // todo: create a mapping to hold valid rebalancer addresses
        // note: also need to hold valid rebalancer address on the factory contract
    }

    modifier onlyRebalancer() {
        require(msg.sender == rebalancer, "Issuer: Only rebalancer can call this function");
        _;
    }

    function enableSwingPricing(bool status) public onlyOwner {
        swingPricingEnabled = status;

        emit SwingPricingStatusUpdated(status);
    }

    function enableLiquiateReserveBelowTarget(bool status) public onlyOwner {
        liquidateReserveBelowTarget = status;

        emit LiquidateReserveBelowTargetStatus(status);
    }

    /*//////////////////////////////////////////////////////////////
                        UTILITY / DELETE / REHOUSE
    ////////////////////////////////////////////////////////////////*/

    // logic is used to create investment size for both sync and async assets
    // might be better to just move that logic into each function for readability
    function getInvestmentSize(address component) public view returns (uint256 depositAmount) {
        uint256 targetHoldings = Math.mulDiv(totalAssets(), getComponentRatio(component), WAD);

        uint256 currentBalance;

        if (isAsync(component)) {
            currentBalance = getAsyncAssets(component);
        } else {
            currentBalance = ERC20(component).balanceOf(address(this));
        }

        uint256 delta = targetHoldings > currentBalance ? targetHoldings - currentBalance : 0;
        return delta;
    }

    function getPendingRedeemAssets() public view returns (uint256 pendingAssets) {
        pendingAssets = 0;

        uint256 length = redeemRequests.length;
        for (uint256 i; i < length; i++) {
            Request memory request = redeemRequests[i];
            pendingAssets += convertToAssets(request.sharesPending);
        }
        return pendingAssets;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC-7575 SUPPORT
    //////////////////////////////////////////////////////////////*/

    function share() external view returns (address) {
        return address(this);
    }

    /*//////////////////////////////////////////////////////////////
                              ERC-165 SUPPORT
    //////////////////////////////////////////////////////////////*/

    // Override the supportsInterface function

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC7540Redeem).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
