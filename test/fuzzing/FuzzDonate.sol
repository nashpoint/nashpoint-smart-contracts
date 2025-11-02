// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsDonate.sol";
import "./helpers/postconditions/PostconditionsDonate.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FuzzDonate is PreconditionsDonate, PostconditionsDonate {
    function fuzz_donate(uint256 tokenSeed, uint256 recipientSeed, uint256 amount) public setCurrentActor(tokenSeed) {
        DonateParams memory params = preconditionsDonate(tokenSeed, recipientSeed, amount);

        _before();

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            params.token,
            abi.encodeWithSelector(IERC20.transfer.selector, params.recipient, params.amount),
            currentActor
        );

        donatePostconditions(success, returnData);
    }
}
