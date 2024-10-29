// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {Ownable, Ownable2Step} from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import {IERC7540} from "./interfaces/IERC7540.sol";
import {INode} from "./interfaces/INode.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";

/// @title Quoter
/// @author ODND Studios
contract Quoter is IQuoter, Ownable2Step {
    /* IMMUTABLES */
    /// @dev Reference to the Node contract this quoter serves
    INode public immutable node;

    /* STORAGE */
    mapping(address => bool) public isErc4626;
    mapping(address => bool) public isErc7540;

    constructor(
        address node_,
        address owner_
    ) Ownable(owner_) {
        if (node_ == address(0)) revert ErrorsLib.ZeroAddress();
        node = INode(node_);
    }

    /* OWNER FUNCTIONS */
    function setErc4626(address component, bool value) external onlyOwner {
        isErc4626[component] = value;
    }

    function setErc7540(address component, bool value) external onlyOwner {
        isErc7540[component] = value;
    }

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc IQuoter
    function getPrice() external view returns (uint128) {}

    /// @inheritdoc IQuoter
    function getTotalAssets() external view returns (uint256) {
        uint256 reserveAssets = IERC20(node.asset()).balanceOf(address(node));

        uint256 componentAssets = 0;
        address[] memory components = node.getComponents();
        uint256 componentsLength = components.length;
        for (uint256 i = 0; i < componentsLength; i++) {
            if (isErc4626[components[i]]) {
                componentAssets = componentAssets + _getErc4626Assets(components[i]);
            } else if (isErc7540[components[i]]) {
                componentAssets = componentAssets + _getErc7540Assets(components[i]);
            } else {
                revert ErrorsLib.InvalidComponent();
            }
        }

        return reserveAssets + componentAssets;
    }

    /* INTERNAL FUNCTIONS */
    function _getErc4626Assets(address component) internal view returns (uint256) {
        return IERC4626(component).convertToAssets(IERC4626(component).balanceOf(address(node)));
    }

    function _getErc7540Assets(address component) internal view returns (uint256) {
        uint256 shareBalance = IERC20(node.share()).balanceOf(address(node));
        uint256 assets = IERC4626(component).convertToAssets(shareBalance);

        assets += IERC7540(component).pendingDepositRequest(0, address(node));
        assets += IERC7540(component).claimableDepositRequest(0, address(node));
        assets += IERC7540(component).pendingRedeemRequest(0, address(node));
        assets += IERC7540(component).claimableRedeemRequest(0, address(node));

        return assets;
    }
}
