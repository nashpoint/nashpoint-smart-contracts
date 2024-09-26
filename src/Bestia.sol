// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

// TODO: ERC 165 & ERC 7575 supported and tested
// TODO: create multiple factories so we can have different token types - even a meta factory
// TODO: pull out all of the assets with 0 target in your tests. should work without
// TODO: global rebalancing toggle???? opt in or out for managers
// TODO: go through every single function and think about incentives from speculator vs investor
// TODO: implement ternaries where you can

// NOTE: re factory. it might make sense to have a factory that deploys a contract that can have parameters changed, and another factory that is more permanent. Prioritize flexibility for now but think about this more later.

// NOTE: Most tests currently require Vaults A, B & C; and liquidityPool
// TEMP: some of these contracts addresses are hardcoded inside functions while refactoring

import {IERC7540} from "src/interfaces/IERC7540.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IEscrow} from "src/Escrow.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

// TEMP: Delete before deploying
import {console2} from "forge-std/Test.sol";

// TODO: 7540 Spec Finalization Plan
// DONE: - mint()
// - redeem()
// - overload withdraw()
// - overload redeem()
// - ERC-165
// - ERC-7575
// - controller and operator checks in withdraw and redeem
// - requestRedeem: approvals and operators (not sure what is missing yet)

contract Bestia is ERC4626, Ownable {
    /*//////////////////////////////////////////////////////////////
                              DATA
    //////////////////////////////////////////////////////////////*/

    // CONSTANTS
    // TODO: create detailed notes for for managers to read
    uint256 public maxDiscount; // percentage  = 2e16
    uint256 public targetReserveRatio; // percentage  = 10e16
    uint256 public maxDelta; // percentage  = 1e16
    uint256 public asyncMaxDelta; //percentage = 3e16

    // these should be hardcoded
    int256 public constant scalingFactor = -5e18; // negative integer
    uint256 public constant internalPrecision = 1e18; // todo: convert all assets to this precision

    bool public instantLiquidationsEnabled = true; // todo: also set by manager
    bool public swingPricingEnabled = false; // set by manager
    bool public liquidateReserveBelowTarget = true;

    // Requests for nodes are non-fungible and all have ID = 0
    uint256 private constant REQUEST_ID = 0;

    // PRBMath Types and Conversions
    SD59x18 maxDiscountSD;
    SD59x18 targetReserveRatioSD;
    SD59x18 scalingFactorSD;

    // ADDRESSES
    address public banker;
    IEscrow public escrow;
    IERC20Metadata public depositAsset;

    // COMPONENTS DATA
    struct Component {
        // TODO: decide on a plan for upgradeability
        // -- 1. adding a component, you must also add the module it requires
        // -- 2. module factory - standardize module creation for devs
        address component;
        uint256 targetRatio;
        bool isAsync; // note: simple binary is too limited, needs to scale over time
        address shareToken;
    }

    // 7540 WITHDRAWAL REQUESTS
    struct Request {
        address controller;
        uint256 sharesPending;
        uint256 sharesClaimable;
        uint256 assetsClaimable;
        uint256 sharesAdjusted; // compute share value after swing price applied
    }

    // NOTE: the order that components are added to the protocol determines their withdrawal order
    // This will require a lot of manager controls. see list of TODO's in COMPONENTS section
    // NOTE: components MUST be ordered: 1. synchronous assets, 2. asynchronous assets
    // Otherwise instantUserLiquidation() will revert
    Component[] public components;
    mapping(address => uint256) public componentIndex;

    // 7540 Arrays
    Request[] public redeemRequests;
    mapping(address => uint256) public controllerToRedeemIndex;

    // 7540 MAPPINGS
    mapping(address => mapping(address => bool)) private _operators;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _banker,
        uint256 _maxDiscount,
        uint256 _targetReserveRatio,
        uint256 _maxDelta,
        uint256 _asyncMaxDelta,
        address _owner
    ) ERC20(_name, _symbol) ERC4626(IERC20Metadata(_asset)) Ownable(_owner) {
        depositAsset = IERC20Metadata(_asset);
        banker = _banker;
        maxDiscount = _maxDiscount;
        targetReserveRatio = _targetReserveRatio;
        maxDelta = _maxDelta;
        asyncMaxDelta = _asyncMaxDelta;

        // PRBMath Types and Conversions
        maxDiscountSD = sd(int256(maxDiscount));
        targetReserveRatioSD = sd(int256(targetReserveRatio));
        scalingFactorSD = sd(scalingFactor);
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

    ////// 7540 EVENTS //////
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                            ERROR HANDLING
    ////////////////////////////////////////////////////////////////*/

    // ERRORS
    // TODO: rename these errors to be more descriptive and include contract name
    // TODO: add returns values
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
    error CannotRedeemZeroShares();
    error DepositToEscrowFailed();
    error UserLiquidationsDisabled();
    error CannotLiquidate();

    // ERC-7540 ERRORS
    error NoRedeemRequestForController();
    error ExceededMaxWithdraw(address controller, uint256 assets, uint256 maxAssets);

    /*//////////////////////////////////////////////////////////////
                        USER DEPOSIT LOGIC 
    //////////////////////////////////////////////////////////////*/

    // TODO: Overload Deposit & Mint Functions (7540 Spec):
    // deposit(uint256 assets, address receiver, address controller)
    // mint(uint256 shares, address receiver, address controller)

    // totalAssets() override function
    // -- must add async component for call to bestia.totalAssets to succeed
    // -- TODO: refactor totalAssets to avoid this issue later
    function totalAssets() public view override returns (uint256) {
        // todo: delete temp variables here when you refactor this
        IERC4626 tempVaultA = IERC4626(components[0].component);
        IERC4626 tempVaultB = IERC4626(components[1].component);
        IERC4626 tempVaultC = IERC4626(components[2].component);
        IERC7540 tempLiquidityPool = IERC7540(components[3].component);

        // gets the cash reserve
        uint256 cashReserve = depositAsset.balanceOf(address(this));

        // gets value of async assets
        uint256 asyncAssets = getAsyncAssets(address(tempLiquidityPool));

        // gets the liquid assets balances
        uint256 liquidAssets = tempVaultA.convertToAssets(tempVaultA.balanceOf(address(this)))
            + tempVaultB.convertToAssets(tempVaultB.balanceOf(address(this)))
            + tempVaultC.convertToAssets(tempVaultC.balanceOf(address(this)));

        return cashReserve + asyncAssets + liquidAssets;
    }

    // TODO: Think about logical BUG
    // We are basing the discount on the reserve ratio after the transaction.
    // This means while the RR is below target. There is actually an incentive to break
    // up a deposit into smaller transactions to receive a greater discount.
    // TODO: fix this by changing the logic to increase the size of the discount proportional to the
    // amount that the deposit closes the gap to the target reserve ratio
    function deposit(uint256 _assets, address receiver) public override returns (uint256) {
        uint256 internalAssets = _assets;
        uint256 maxAssets = maxDeposit(receiver);
        if (internalAssets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, _assets, maxAssets);
        }

        // gets the expected reserve ratio after tx
        int256 reserveRatioAfterTX = int256(
            Math.mulDiv(depositAsset.balanceOf(address(this)) + internalAssets, 1e18, totalAssets() + internalAssets)
        );

        // gets the assets to be returned to the user after applying swingfactor to tx
        uint256 adjustedAssets = Math.mulDiv(internalAssets, (1e18 + getSwingFactor(reserveRatioAfterTX)), 1e18);

        // cache the shares to mint for swing factor applied
        uint256 sharesToMint = convertToShares(adjustedAssets);

        // recieves deposited assets but mints adjusted shares based on swing factor applied
        _deposit(_msgSender(), receiver, _assets, sharesToMint);

        return (sharesToMint);
    }

    // TODO: mint function
    function mint(uint256 _shares, address receiver) public override returns (uint256) {
        uint256 _assets = convertToAssets(_shares);
        deposit(_assets, receiver);

        return _assets;
    }

    // swing price curve equation
    // getSwingFactor() converts from int to uint
    // TODO: change to private internal later and change test use a wrapper function in test contract
    function getSwingFactor(int256 _reserveRatioAfterTX) public view returns (uint256 swingFactor) {
        if (!swingPricingEnabled) {
            return 0;
        }
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

    /*//////////////////////////////////////////////////////////////
                        ASYNC USER WITHDRAWAL LOGIC (7540)
    //////////////////////////////////////////////////////////////*/

    // CONTROLLER
    // How can I use this? What is really the point of it?
    // TODO: figure out how the controller and operator role relate to integrators

    // user requests to redeem their funds from the vault. they send their shares to the escrow contract
    function requestRedeem(uint256 shares, address controller, address _owner) external returns (uint256) {
        require(shares > 0, "Cannot request redeem of 0 shares");
        require(balanceOf(_owner) >= shares, "Insufficient shares");
        require(_owner == msg.sender || isOperator(_owner, msg.sender), "Not authorized");

        // Transfer ERC4626 share tokens from owner back to vault
        require(IERC20((address(this))).transferFrom(_owner, address(escrow), shares), "Transfer failed");

        // get the cash balance of the node and asset value of the redeem request
        uint256 balance = depositAsset.balanceOf(address(this));
        uint256 assets = convertToAssets(shares);

        // gets the expected reserve ratio after tx
        int256 reserveRatioAfterTX = int256(Math.mulDiv(balance - assets, 1e18, totalAssets() - assets));

        // gets the assets to be returned to the user after applying swingfactor to tx
        uint256 adjustedAssets = Math.mulDiv(assets, (1e18 - getSwingFactor(reserveRatioAfterTX)), 1e18);

        uint256 sharesToBurn = convertToShares(adjustedAssets);

        uint256 index = controllerToRedeemIndex[controller];

        if (index > 0) {
            // TODO: come back to this as def can be gamed
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

        return REQUEST_ID;
    }

    // view function to see redeem requests that cannot yet be withdrawn
    function pendingRedeemRequest(uint256, address controller) public view returns (uint256 shares) {
        uint256 index = controllerToRedeemIndex[controller];
        require(index > 0, "No pending redemption for controller");
        return redeemRequests[index - 1].sharesPending;
    }

    // view function to see redeem requests that can be withdrawn
    function claimableRedeemRequest(uint256, address controller) public view returns (uint256 shares) {
        uint256 index = controllerToRedeemIndex[controller];
        require(index > 0, "No claimable redemption for controller");
        return redeemRequests[index - 1].sharesClaimable;
    }

    function isOperator(address controller, address operator) public view returns (bool status) {
        return _operators[controller][operator];
    }

    function setOperator(address operator, bool approved) public returns (bool success) {
        _operators[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    // Banker only function to process redemptions from reserve
    function fulfilRedeemFromReserve(address _controller) public onlyBanker {
        uint256 index = controllerToRedeemIndex[_controller];
        uint256 balance = depositAsset.balanceOf(address(this));

        // Ensure there is a pending request for this controller
        if (index == 0) {
            revert NoRedeemRequestForController();
        }

        Request storage request = redeemRequests[index - 1];
        address escrowAddress = address(escrow);

        // note: this introduces a potential bug where you have to set the withdrawal asset value
        // at the time the deposit is requested
        // possibly could be fixed by making the liquidation request based on the sum of adjustedShares
        uint256 sharesPending = request.sharesPending;
        uint256 sharesAdjusted = request.sharesAdjusted;

        uint256 assets = convertToAssets(sharesAdjusted);

        // get reserve ratio after tx
        uint256 reserveRatioAfterTx = Math.mulDiv(balance - assets, 1e18, totalAssets() - assets);

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

        // Burn the shares on escrow
        _burn(escrowAddress, sharesPending);

        // Transfer tokens to Escrow
        IERC20(asset()).transfer(escrowAddress, assets);

        // Call deposit function on Escrow
        escrow.deposit(asset(), assets);
        emit WithdrawalFundsSentToEscrow(escrowAddress, asset(), assets);

        // update balances in Request
        request.sharesPending -= sharesPending; // shares removed from pending
        request.sharesClaimable += sharesPending; // shares added to claimable
        request.assetsClaimable += assets; // assets added to claimable
        request.sharesAdjusted -= sharesAdjusted; // shares removed from adjusted
    }

    ////////////////////////// OVERRIDES ///////////////////////////

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

    function withdraw(uint256 assets, address receiver, address controller) public override returns (uint256 shares) {
        // TODO: need some kind of security check on controller / operator / msg.sender here

        uint256 _index = controllerToRedeemIndex[controller];

        // Ensure there is a pending request for this controller
        require(_index > 0, "No pending request for this controller");

        uint256 maxAssets = maxWithdraw(controller);
        uint256 maxShares = maxRedeem(controller);
        if (assets > maxAssets) {
            revert ExceededMaxWithdraw(controller, assets, maxAssets);
        }

        Request storage request = redeemRequests[_index - 1];
        address escrowAddress = address(escrow);

        shares = (assets * maxShares) / maxAssets;

        request.sharesClaimable -= shares;
        request.assetsClaimable -= assets;

        // using transferFrom as shares already burned when redeem made claimable
        IERC20(asset()).transferFrom(escrowAddress, receiver, assets);

        return shares;
    }

    // TODO: implement this later
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        // TODO: need some kind of security check on controller / operator / msg.sender here
    }

    function previewWithdraw(uint256) public view virtual override returns (uint256) {
        revert("ERC7540: previewWithdraw not available for async vault");
    }

    function previewRedeem(uint256) public view virtual override returns (uint256) {
        revert("ERC7540: previewRedeem not available for async vault");
    }

    /*//////////////////////////////////////////////////////////////
                    ASYNC ASSET MANAGEMENT LOGIC (7540)
    //////////////////////////////////////////////////////////////*/

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

        // Add claimable deposits assets
        try IERC7540(_component).claimableDepositRequest(0, address(this)) returns (uint256 claimableAssets) {
            assets += claimableAssets;
        } catch {}

        // Add pending redemptions (convert shares to assets)
        try IERC7540(_component).pendingRedeemRequest(0, address(this)) returns (uint256 pendingRedeemShares) {
            assets += IERC7540(_component).convertToAssets(pendingRedeemShares);
        } catch {}

        // Add claimable redemptions (convert shares to assets)
        try IERC7540(_component).claimableRedeemRequest(0, address(this)) returns (uint256 claimableRedeemShares) {
            assets += IERC7540(_component).convertToAssets(claimableRedeemShares);
        } catch {}

        return assets;
    }

    // TODO: Check for reused code between this and investInSync vault.
    function investInAsyncVault(address _component) external onlyBanker returns (uint256 cashInvested) {
        if (!isComponent(_component)) {
            revert NotAComponent();
        }

        if (!isAsync(_component)) {
            revert IsNotAsyncVault();
        }

        uint256 totalAssets_ = totalAssets();
        uint256 idealCashReserve = totalAssets_ * targetReserveRatio / 1e18;
        uint256 currentCash = depositAsset.balanceOf(address(this));

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

    function mintClaimableShares(address _component) public onlyBanker returns (uint256) {
        uint256 claimableShares = IERC7540(_component).maxMint(address(this));

        IERC7540(_component).mint(claimableShares, address(this));

        emit AsyncSharesMinted(_component, claimableShares);
        return claimableShares;
    }

    // requests withdrawal from async vault
    function requestAsyncWithdrawal(address _component, uint256 _shares) public onlyBanker {
        IERC20 shareToken = IERC20(getComponentShareAddress(_component));
        if (_shares > shareToken.balanceOf(address(this))) {
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
        if (_assets > IERC7540(_component).maxWithdraw(address(this))) {
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

    /*//////////////////////////////////////////////////////////////
                SYNCHRONOUS ASSET MANAGEMENT LOGIC (4626)
    //////////////////////////////////////////////////////////////*/

    // TODO: need a fallback managerLiquidation() function that can instantly liquidate and top up reserve
    // note: think about this... even that fact that it is on the contract changes the game theory for speculators vs long term investors

    // called by banker to deposit excess reserve into strategies
    // TODO: refactor this into something more efficient and include getDepositAmount logic
    function investInSyncVault(address _component) external onlyBanker returns (uint256 cashInvested) {
        if (!isComponent(_component)) {
            revert NotAComponent();
        }
        if (isAsync(_component)) {
            revert IsAsyncVault();
        }

        // temp: delete after you fix logic
        IERC7540 tempLiquidityPool = IERC7540(components[3].component);
        if (isAsyncAssetsBelowMinimum(address(tempLiquidityPool))) {
            revert AsyncAssetBelowMinimum();
        }

        uint256 totalAssets_ = totalAssets();
        uint256 idealCashReserve = totalAssets_ * targetReserveRatio / 1e18;
        uint256 currentCash = depositAsset.balanceOf(address(this));

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

    // banker to use this function to liquidate underlying vault to meet redeem requests
    function liquidateSyncVaultPosition(address _component, uint256 shares)
        public
        onlyBanker
        returns (uint256 assetsReturned)
    {
        if (!isComponent(_component)) {
            revert NotAComponent();
        }

        if (isAsync(_component)) {
            revert IsAsyncVault();
        }

        if (ERC4626(_component).balanceOf(address(this)) < shares) {
            revert TooManySharesRequested();
        }

        if (shares == 0) {
            revert CannotRedeemZeroShares();
        }

        // Preview the expected assets from redemption
        uint256 expectedAssets = ERC4626(_component).previewRedeem(shares);

        // Perform the edemption
        uint256 assets = ERC4626(_component).redeem(shares, address(this), address(this));

        // Ensure assets returned is within an acceptable range of expectedAssets
        require(assets >= expectedAssets, "Redeemed assets less than expected");

        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                        COMPONENT MANAGEMENT
    ////////////////////////////////////////////////////////////////*/

    // TODO: create a set components function
    // -- must revert if percentages !=100 OR async before synchronous in order
    // TODO: create a function to swap order by move a component within the index
    // TODO: create function to completely reorder the components using a list of (valid) addresses
    // TODO: create a read function that will return the withdrawal position of a component as a uint
    // TODO: create a read function that will return the withdrawal order as a list of addressess

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

    /*//////////////////////////////////////////////////////////////
                        ESCROW INTERACTIONS
    ////////////////////////////////////////////////////////////////*/

    function executeEscrowDeposit(address _tokenAddress, uint256 _amount) external onlyBanker {
        IERC20 token = IERC20(_tokenAddress);
        address escrowAddress = address(escrow);

        // Transfer tokens to Escrow
        if (!token.transfer(escrowAddress, _amount)) {
            revert DepositToEscrowFailed();
        }

        // Call deposit function on Escrow
        escrow.deposit(_tokenAddress, _amount);

        emit WithdrawalFundsSentToEscrow(escrowAddress, _tokenAddress, _amount);
    }

    function setEscrow(address _escrow) public onlyOwner {
        escrow = IEscrow(_escrow);
    }

    /*//////////////////////////////////////////////////////////////
                        BANKER AND PERMISSIONS
    ////////////////////////////////////////////////////////////////*/

    function setBanker(address _banker) public onlyOwner {
        banker = _banker;
    }

    modifier onlyBanker() {
        require(msg.sender == banker, "Issuer: Only banker can call this function");
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
                        UTILITY & OVERRIDE FUNCTIONS  
                    (TEMP: Might move or delete these later)
    ////////////////////////////////////////////////////////////////*/

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
}
