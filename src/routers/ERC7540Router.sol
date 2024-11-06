// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseRouter} from "../libraries/BaseRouter.sol";
import {IERC7540} from "../interfaces/IERC7540.sol";

/**
 * @title ERC7540Router
 * @dev Router for ERC7540 vaults
 */
contract ERC7540Router is BaseRouter {
    /* CONSTRUCTOR */
    constructor(address registry_) BaseRouter(registry_) {}

    /* EXTERNAL FUNCTIONS */
}
