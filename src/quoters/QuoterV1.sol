// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IERC7540} from "../interfaces/IERC7540.sol";
import {IERC7575} from "../interfaces/IERC7575.sol";
import {INode} from "../interfaces/INode.sol";
import {IQuoterV1, IQuoter} from "../interfaces/IQuoterV1.sol";

import {BaseQuoter} from "../libraries/BaseQuoter.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MathLib} from "../libraries/MathLib.sol";

/// @title QuoterV1
/// @author ODND Studios
contract QuoterV1 is IQuoterV1, BaseQuoter {
    using MathLib for uint256;

    /* CONSTANTS */
    uint8 internal constant PRICE_DECIMALS = 18;

    /* STORAGE */
    mapping(address => bool) public isErc4626;
    mapping(address => bool) public isErc7540;
    bool public isInitialized;

    /* CONSTRUCTOR */
    constructor(address registry_) BaseQuoter(registry_) {}

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc IQuoterV1
    function initialize(address[] memory erc4626Components_, address[] memory erc7540Components_)
        external
        onlyRegistryOwner
    {
        if (isInitialized) revert ErrorsLib.AlreadyInitialized();

        uint256 erc4626ComponentsLength = erc4626Components_.length;
        for (uint256 i = 0; i < erc4626ComponentsLength; i++) {
            isErc4626[erc4626Components_[i]] = true;
        }

        uint256 erc7540ComponentsLength = erc7540Components_.length;
        for (uint256 i = 0; i < erc7540ComponentsLength; i++) {
            isErc7540[erc7540Components_[i]] = true;
        }

        isInitialized = true;
    }

    /// @inheritdoc IQuoterV1
    function setErc4626(address component, bool value) external onlyRegistryOwner {
        isErc4626[component] = value;
    }

    /// @inheritdoc IQuoterV1
    function setErc7540(address component, bool value) external onlyRegistryOwner {
        isErc7540[component] = value;
    }

    /// @inheritdoc IQuoter
    function getTotalAssets(address node) external view onlyValidNode(node) returns (uint256) {
        return _getTotalAssets(node);
    }

    function getErc7540Assets(address node, address component) external view returns (uint256) {
        return _getErc7540Assets(node, component);
    }

    /* INTERNAL FUNCTIONS */
    function _getErc4626Assets(address node, address component) internal view returns (uint256) {
        uint256 balance = IERC4626(component).balanceOf(node);
        if (balance == 0) return 0;
        return IERC4626(component).convertToAssets(balance);
    }

    function _getErc7540Assets(address node, address component) internal view returns (uint256) {
        uint256 assets;
        address shareToken = IERC7575(component).share();
        uint256 shareBalance = IERC20(shareToken).balanceOf(node);

        if (shareBalance > 0) {
            assets = IERC4626(component).convertToAssets(shareBalance);
        }
        /// @dev in ERC7540 deposits are denominated in assets and redeems are in shares
        assets += IERC7540(component).pendingDepositRequest(0, node);
        assets += IERC7540(component).claimableDepositRequest(0, node);
        assets += IERC4626(component).convertToAssets(IERC7540(component).pendingRedeemRequest(0, node));
        assets += IERC4626(component).convertToAssets(IERC7540(component).claimableRedeemRequest(0, node));

        return assets;
    }

    function _getTotalAssets(address node) internal view returns (uint256) {
        uint256 reserveAssets = IERC20(INode(node).asset()).balanceOf(node);

        uint256 componentAssets;
        address[] memory components = INode(node).getComponents();
        uint256 componentsLength = components.length;

        for (uint256 i = 0; i < componentsLength; i++) {
            if (isErc4626[components[i]]) {
                componentAssets += _getErc4626Assets(node, components[i]);
            } else if (isErc7540[components[i]]) {
                componentAssets += _getErc7540Assets(node, components[i]);
            } else {
                revert ErrorsLib.InvalidComponent();
            }
        }

        return reserveAssets + componentAssets;
    }
}
