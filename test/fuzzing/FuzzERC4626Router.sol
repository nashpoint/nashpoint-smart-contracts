// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsERC4626Router.sol";
import "./helpers/postconditions/PostconditionsERC4626Router.sol";

import {ERC4626Router} from "../../src/routers/ERC4626Router.sol";
import {BaseComponentRouter} from "../../src/libraries/BaseComponentRouter.sol";

contract FuzzERC4626Router is PreconditionsERC4626Router, PostconditionsERC4626Router {
    function fuzz_router4626_invest(uint256 componentSeed, uint256 amountSeed) public {
        _forceActor(rebalancer, componentSeed);
        RouterInvestParams memory params = router4626InvestPreconditions(componentSeed, amountSeed);

        address[] memory actors = new address[](1);
        actors[0] = address(node);
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(ERC4626Router.invest.selector, address(node), params.component, params.minSharesOut),
            currentActor
        );

        router4626InvestPostconditions(success, returnData, params, actors);
    }

    function fuzz_router4626_liquidate(uint256 componentSeed, uint256 sharesSeed) public {
        _forceActor(rebalancer, componentSeed);
        RouterLiquidateParams memory params = router4626LiquidatePreconditions(componentSeed, sharesSeed);

        address[] memory actors = new address[](1);
        actors[0] = address(node);
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(
                ERC4626Router.liquidate.selector, address(node), params.component, params.shares, params.minAssetsOut
            ),
            currentActor
        );

        router4626LiquidatePostconditions(success, returnData, params, actors);
    }

    function fuzz_router4626_fulfillRedeem(uint256 controllerSeed, uint256 componentSeed) public {
        _forceActor(rebalancer, componentSeed);
        RouterFulfillParams memory params = router4626FulfillPreconditions(controllerSeed, componentSeed);

        address[] memory actors = new address[](2);
        actors[0] = address(node);
        actors[1] = address(escrow);
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(
                ERC4626Router.fulfillRedeemRequest.selector,
                address(node),
                params.controller,
                params.component,
                params.minAssetsOut
            ),
            currentActor
        );

        router4626FulfillPostconditions(success, returnData, params, actors);
    }

    function fuzz_router4626_batchWhitelist(uint256 seed) public {
        _forceActor(owner, seed);
        RouterBatchWhitelistParams memory params = router4626BatchWhitelistPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(
                BaseComponentRouter.batchSetWhitelistStatus.selector, params.components, params.statuses
            ),
            currentActor
        );

        router4626BatchWhitelistPostconditions(success, returnData, params);
    }

    function fuzz_router4626_setWhitelist(uint256 seed, bool status) public {
        _forceActor(owner, seed);
        RouterSingleStatusParams memory params = router4626SingleWhitelistPreconditions(seed, status);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(BaseComponentRouter.setWhitelistStatus.selector, params.component, params.status),
            currentActor
        );

        router4626SingleWhitelistPostconditions(success, returnData, params, false);
    }

    function fuzz_router4626_setBlacklist(uint256 seed, bool status) public {
        _forceActor(owner, seed);
        RouterSingleStatusParams memory params = router4626SingleWhitelistPreconditions(seed, status);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(BaseComponentRouter.setBlacklistStatus.selector, params.component, params.status),
            currentActor
        );

        router4626SingleWhitelistPostconditions(success, returnData, params, true);
    }

    function fuzz_router4626_setTolerance(uint256 seed) public {
        _forceActor(owner, seed);
        RouterToleranceParams memory params = router4626TolerancePreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router4626),
            abi.encodeWithSelector(BaseComponentRouter.setTolerance.selector, params.newTolerance),
            currentActor
        );

        router4626TolerancePostconditions(success, returnData, params);
    }
}
