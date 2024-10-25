// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRebalancer} from "../libraries/BaseRebalancer.sol";
import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title ERC7540Rebalancer
 * @dev Rebalancer for ERC7540 vaults
 */
contract ERC7540Rebalancer is BaseRebalancer {

    /* CONSTRUCTOR */

    constructor(address node_, address owner) BaseRebalancer(node_, owner) {}

    /* EXTERNAL FUNCTIONS */
}
