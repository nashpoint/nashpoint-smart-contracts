// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {DigiftAdapter} from "../../../../src/adapters/digift/DigiftAdapter.sol";

contract PostconditionsDigiftAdapterFactory is PostconditionsBase {
    function digiftFactoryDeployPostconditions(
        bool success,
        bytes memory returnData,
        DigiftFactoryDeployParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "DIGIFT_FACTORY_DEPLOY_SHOULD_SUCCEED");

            address deployedAdapter = abi.decode(returnData, (address));
            // fl.t(deployedAdapter != address(0), "DIGIFT_FACTORY_DEPLOY_ZERO_ADDRESS");

            DigiftAdapter instance = DigiftAdapter(deployedAdapter);
            // fl.eq(instance.asset(), params.initArgs.asset, "DIGIFT_FACTORY_DEPLOY_ASSET_MISMATCH");
            // fl.eq(instance.stToken(), params.initArgs.stToken, "DIGIFT_FACTORY_DEPLOY_STTOKEN_MISMATCH");
            // fl.eq(
            // address(instance.assetPriceOracle()),
            // params.initArgs.assetPriceOracle,
            // "DIGIFT_FACTORY_DEPLOY_ORACLE_MISMATCH"
            // );
            // fl.eq(uint256(instance.minDepositAmount()), params.initArgs.minDepositAmount, "DIGIFT_FACTORY_MIN_DEPOSIT");
            // fl.eq(uint256(instance.minRedeemAmount()), params.initArgs.minRedeemAmount, "DIGIFT_FACTORY_MIN_REDEEM");
            // fl.eq(uint256(instance.priceDeviation()), params.initArgs.priceDeviation, "DIGIFT_FACTORY_PRICE_DEV");
            // fl.eq(
            // uint256(instance.settlementDeviation()), params.initArgs.settlementDeviation, "DIGIFT_FACTORY_SETTLE_DEV"
            // );
            // fl.eq(
            // uint256(instance.priceUpdateDeviation()),
            // params.initArgs.priceUpdateDeviation,
            // "DIGIFT_FACTORY_PRICE_UPDATE_DEV"
            // );

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "DIGIFT_FACTORY_DEPLOY_SHOULD_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftFactoryOwnershipPostconditions(
        bool success,
        bytes memory returnData,
        DigiftFactoryOwnershipParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "DIGIFT_FACTORY_OWNER_OP_SHOULD_SUCCEED");
            // fl.eq(digiftFactory.owner(), params.newOwner, "DIGIFT_FACTORY_OWNER_MISMATCH");

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "DIGIFT_FACTORY_OWNER_OP_SHOULD_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }

    function digiftFactoryUpgradePostconditions(
        bool success,
        bytes memory returnData,
        DigiftFactoryUpgradeParams memory params
    ) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "DIGIFT_FACTORY_UPGRADE_SHOULD_SUCCEED");
            // fl.eq(digiftFactory.implementation(), params.newImplementation, "DIGIFT_FACTORY_IMPL_MISMATCH");

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "DIGIFT_FACTORY_UPGRADE_SHOULD_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }
}
