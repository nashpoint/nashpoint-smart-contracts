// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {MathLib} from "src/libraries/MathLib.sol";

/// @title WTPriceOracle
/// @author ODND Studios
/// @notice Owner-managed oracle with guarded operator price updates
contract WTPriceOracle is Ownable, Pausable {
    /// @notice Reverts when a caller is not an authorized operator
    /// @param caller The unauthorized caller
    error NotOperator(address caller);

    /// @notice Reverts when a caller is not an authorized pauser
    /// @param caller The unauthorized caller
    error NotPauser(address caller);

    /// @notice Reverts when a zero price is provided
    error ZeroPrice();

    /// @notice Reverts when the description is empty
    error EmptyDescription();

    /// @notice Reverts when cooldown is zero
    error InvalidCooldown();

    /// @notice Reverts when the configured price deviation is zero or above 100%
    /// @param priceDeviationValue The invalid price deviation value
    error InvalidPriceDeviation(uint64 priceDeviationValue);

    /// @notice Number of decimals used by the oracle answer
    uint8 private immutable _decimals;

    /// @notice Timestamp of the last successful price update
    uint64 private _updatedAt;

    /// @notice Latest stored price value
    uint64 private _price;

    /// @notice Minimum delay required between operator-driven price updates, in seconds
    uint64 public cooldown;

    /// @notice Maximum price deviation allowed (1e18 = 100%)
    uint64 public priceDeviation;

    /// @notice Human-readable oracle description
    string private _description;

    /// @notice Mapping of addresses allowed to submit price updates
    mapping(address => bool) public operators;

    /// @notice Mapping of addresses allowed to manually pause the oracle
    mapping(address => bool) public pausers;

    /// @notice Emitted when the stored price is updated
    /// @param oldPrice The previous price value
    /// @param newPrice The new price value
    event UpdatePrice(uint64 oldPrice, uint64 newPrice);

    /// @notice Emitted when an operator's authorization changes
    /// @param operator The operator address
    /// @param status The new authorization status
    event OperatorChange(address indexed operator, bool status);

    /// @notice Emitted when a pauser's authorization changes
    /// @param pauser The pauser address
    /// @param status The new authorization status
    event PauserChange(address indexed pauser, bool status);

    /// @notice Emitted when the cooldown value changes
    /// @param oldValue The previous cooldown
    /// @param newValue The new cooldown
    event CooldownChange(uint64 oldValue, uint64 newValue);

    /// @notice Emitted when the price deviation value changes
    /// @param oldValue The previous price deviation
    /// @param newValue The new price deviation
    event PriceDeviationChange(uint64 oldValue, uint64 newValue);

    /// @notice Initializes the oracle with its initial price and risk parameters
    /// @param owner_ Address that will own the oracle
    /// @param price_ Initial oracle price
    /// @param decimals_ Number of decimals in the reported price
    /// @param description_ Human-readable oracle description
    /// @param cooldown_ Minimum delay between operator updates
    /// @param priceDeviation_ Maximum allowed operator price deviation
    constructor(
        address owner_,
        uint64 price_,
        uint8 decimals_,
        string memory description_,
        uint64 cooldown_,
        uint64 priceDeviation_
    ) Ownable(owner_) {
        require(price_ != 0, ZeroPrice());
        require(bytes(description_).length != 0, EmptyDescription());
        require(cooldown_ != 0, InvalidCooldown());
        require(priceDeviation_ != 0 && priceDeviation_ <= 1e18, InvalidPriceDeviation(priceDeviation_));

        _updatedAt = uint64(block.timestamp);
        _price = price_;
        _decimals = decimals_;
        _description = description_;
        cooldown = cooldown_;
        priceDeviation = priceDeviation_;
    }

    /// @notice Updates the price through an authorized operator
    /// @dev Pauses the oracle if the update is attempted during cooldown or outside the allowed range
    /// @param price_ The proposed new price
    function updatePriceByOperator(uint64 price_) external whenNotPaused {
        require(operators[msg.sender], NotOperator(msg.sender));
        bool cooldownActive = isCooldownActive();
        bool withinRange = MathLib.withinRange(uint256(_price), uint256(price_), priceDeviation);
        if (cooldownActive || !withinRange) {
            _pause();
        } else {
            _updatePrice(price_);
        }
    }

    /// @notice Returns whether operator updates are currently blocked by the cooldown
    function isCooldownActive() public view returns (bool) {
        return _updatedAt + cooldown > block.timestamp;
    }

    /// @notice Updates the oracle price directly as the owner
    /// @param price_ The new price
    function updatePriceByOwner(uint64 price_) external onlyOwner {
        _updatePrice(price_);
    }

    function _updatePrice(uint64 price_) internal {
        require(price_ != 0, ZeroPrice());
        _updatedAt = uint64(block.timestamp);
        uint64 oldPrice = _price;
        _price = price_;
        emit UpdatePrice(oldPrice, price_);
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external view returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        whenNotPaused
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (uint80(0), int256(uint256(_price)), _updatedAt, _updatedAt, uint80(0));
    }

    /// @notice Pauses the oracle
    /// @dev Callable by the owner or any authorized pauser
    function pause() external {
        require(pausers[msg.sender] || msg.sender == owner(), NotPauser(msg.sender));
        _pause();
    }

    /// @notice Unpauses the oracle
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets an operator authorization status
    /// @param operator The operator address
    /// @param status The new authorization status
    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit OperatorChange(operator, status);
    }

    /// @notice Sets a pauser authorization status
    /// @param pauser The pauser address
    /// @param status The new authorization status
    function setPauser(address pauser, bool status) external onlyOwner {
        pausers[pauser] = status;
        emit PauserChange(pauser, status);
    }

    /// @notice Sets the operator update cooldown
    /// @param cooldown_ The new cooldown in seconds
    function setCooldown(uint64 cooldown_) external onlyOwner {
        require(cooldown_ != 0, InvalidCooldown());
        emit CooldownChange(cooldown, cooldown_);
        cooldown = cooldown_;
    }

    /// @notice Sets the maximum allowed operator price deviation
    /// @param priceDeviation_ The new deviation value, scaled by 1e18
    function setPriceDeviation(uint64 priceDeviation_) external onlyOwner {
        require(priceDeviation_ != 0 && priceDeviation_ <= 1e18, InvalidPriceDeviation(priceDeviation_));
        emit PriceDeviationChange(priceDeviation, priceDeviation_);
        priceDeviation = priceDeviation_;
    }
}
