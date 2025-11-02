// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/preconditions/PreconditionsERC7540Router.sol";
import "./helpers/postconditions/PostconditionsERC7540Router.sol";

import {ERC7540Router} from "../../src/routers/ERC7540Router.sol";
import {BaseComponentRouter} from "../../src/libraries/BaseComponentRouter.sol";

contract FuzzERC7540Router is PreconditionsERC7540Router, PostconditionsERC7540Router {
    function fuzz_router7540_invest(uint256 componentSeed, uint256 amountSeed) public {
        _forceActor(rebalancer, componentSeed);
        RouterAsyncInvestParams memory params = router7540InvestPreconditions(componentSeed, amountSeed);

        address[] memory actors = new address[](1);
        actors[0] = address(node);
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(ERC7540Router.investInAsyncComponent.selector, address(node), params.component),
            currentActor
        );

        router7540InvestPostconditions(success, returnData, params, actors);
    }

    function fuzz_router7540_mintClaimable(uint256 componentSeed) public {
        _forceActor(rebalancer, componentSeed);
        RouterMintClaimableParams memory params = router7540MintClaimablePreconditions(componentSeed);

        address[] memory actors = new address[](1);
        actors[0] = address(node);
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(ERC7540Router.mintClaimableShares.selector, address(node), params.component),
            currentActor
        );

        router7540MintClaimablePostconditions(success, returnData, params, actors);
    }

    function fuzz_router7540_requestWithdrawal(uint256 componentSeed, uint256 shareSeed) public {
        _forceActor(rebalancer, componentSeed);
        RouterRequestAsyncWithdrawalParams memory params =
            router7540RequestWithdrawalPreconditions(componentSeed, shareSeed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(
                ERC7540Router.requestAsyncWithdrawal.selector, address(node), params.component, params.shares
            ),
            currentActor
        );

        router7540RequestWithdrawalPostconditions(success, returnData, params);
    }

    function fuzz_router7540_executeWithdrawal(uint256 componentSeed, uint256 assetsSeed) public {
        _forceActor(rebalancer, componentSeed);
        RouterExecuteAsyncWithdrawalParams memory params =
            router7540ExecuteWithdrawalPreconditions(componentSeed, assetsSeed);

        address[] memory actors = new address[](1);
        actors[0] = address(node);
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(
                ERC7540Router.executeAsyncWithdrawal.selector, address(node), params.component, params.assets
            ),
            currentActor
        );

        router7540ExecuteWithdrawalPostconditions(success, returnData, params, actors);
    }

    function fuzz_router7540_fulfillRedeem(uint256 controllerSeed, uint256 componentSeed) public {
        _forceActor(rebalancer, componentSeed);
        RouterFulfillAsyncParams memory params = router7540FulfillPreconditions(controllerSeed, componentSeed);

        address[] memory actors = new address[](2);
        actors[0] = address(node);
        actors[1] = address(escrow);
        _before(actors);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(
                ERC7540Router.fulfillRedeemRequest.selector, address(node), params.controller, params.component
            ),
            currentActor
        );

        router7540FulfillPostconditions(success, returnData, params, actors);
    }

    function fuzz_router7540_batchWhitelist(uint256 seed) public {
        _forceActor(owner, seed);
        RouterBatchWhitelistParams memory params = router7540BatchWhitelistPreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(
                BaseComponentRouter.batchSetWhitelistStatus.selector, params.components, params.statuses
            ),
            currentActor
        );

        router7540BatchWhitelistPostconditions(success, returnData, params);
    }

    function fuzz_router7540_setWhitelist(uint256 seed, bool status) public {
        _forceActor(owner, seed);
        RouterSingleStatusParams memory params = router7540SingleStatusPreconditions(seed, status);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(BaseComponentRouter.setWhitelistStatus.selector, params.component, params.status),
            currentActor
        );

        router7540SingleStatusPostconditions(success, returnData, params, false);
    }

    function fuzz_router7540_setBlacklist(uint256 seed, bool status) public {
        _forceActor(owner, seed);
        RouterSingleStatusParams memory params = router7540SingleStatusPreconditions(seed, status);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(BaseComponentRouter.setBlacklistStatus.selector, params.component, params.status),
            currentActor
        );

        router7540SingleStatusPostconditions(success, returnData, params, true);
    }

    function fuzz_router7540_setTolerance(uint256 seed) public {
        _forceActor(owner, seed);
        RouterToleranceParams memory params = router7540TolerancePreconditions(seed);

        (bool success, bytes memory returnData) = fl.doFunctionCall(
            address(router7540),
            abi.encodeWithSelector(BaseComponentRouter.setTolerance.selector, params.newTolerance),
            currentActor
        );

        router7540TolerancePostconditions(success, returnData, params);
    }
}
