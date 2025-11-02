// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {DigiftAdapter} from "../../../../src/adapters/digift/DigiftAdapter.sol";
import {DigiftAdapterFactory} from "../../../../src/adapters/digift/DigiftAdapterFactory.sol";

contract PreconditionsDigiftAdapterFactory is PreconditionsBase {
    function digiftFactoryDeployPreconditions(uint256 seed)
        internal
        returns (DigiftFactoryDeployParams memory params)
    {
        _ensureFactoryOwner();

        params.expectedOwner = digiftFactory.owner();
        params.shouldSucceed = currentActor == params.expectedOwner;
        params.initArgs = _buildInitArgs(seed);
    }

    function digiftFactoryTransferOwnershipPreconditions(uint256 seed)
        internal
        returns (DigiftFactoryOwnershipParams memory params)
    {
        _ensureFactoryOwner();

        params.newOwner = _selectOwnershipCandidate(seed);
        params.shouldSucceed = currentActor == digiftFactory.owner() && params.newOwner != address(0);
    }

    function digiftFactoryRenouncePreconditions() internal returns (DigiftFactoryOwnershipParams memory params) {
        _ensureFactoryOwner();

        params.newOwner = address(0);
        params.shouldSucceed = currentActor == digiftFactory.owner();
    }

    function digiftFactoryUpgradePreconditions(uint256 seed)
        internal
        returns (DigiftFactoryUpgradeParams memory params)
    {
        _ensureFactoryOwner();

        bool provideValidImplementation = seed % 2 == 0;

        if (provideValidImplementation) {
            params.newImplementation =
                address(new DigiftAdapter(address(subRedManagement), address(registry), address(digiftEventVerifier)));
            params.shouldSucceed = currentActor == digiftFactory.owner();
        } else {
            params.newImplementation = address(uint160(seed));
            params.shouldSucceed = false;
        }
    }

    function _buildInitArgs(uint256 seed) internal view returns (DigiftAdapter.InitArgs memory args) {
        uint64 basePriceDeviation = 5e15; // 0.5%
        uint64 baseSettlementDeviation = 1e16; // 1%
        uint64 baseUpdateDeviation = 3 days;

        args = DigiftAdapter.InitArgs({
            name: "Digift Adapter Fuzz",
            symbol: "dGIF",
            asset: address(assetToken),
            assetPriceOracle: address(assetPriceOracleMock),
            stToken: address(stToken),
            dFeedPriceOracle: address(digiftPriceOracleMock),
            priceDeviation: uint64(basePriceDeviation + uint64(seed % 1e15)),
            settlementDeviation: uint64(baseSettlementDeviation + uint64(seed % 1e15)),
            priceUpdateDeviation: uint64(baseUpdateDeviation + uint64(seed % 4 days)),
            minDepositAmount: 1_000e6 + (seed % 1_000_000e6),
            minRedeemAmount: 1e18 + (seed % 1_000e18)
        });
    }

    function _selectOwnershipCandidate(uint256 seed) internal view returns (address) {
        if (seed % 10 == 0) {
            return address(0);
        }

        address[] memory candidates = new address[](USERS.length + 3);
        for (uint256 i = 0; i < USERS.length; i++) {
            candidates[i] = USERS[i];
        }
        candidates[USERS.length] = owner;
        candidates[USERS.length + 1] = rebalancer;
        candidates[USERS.length + 2] = randomUser;

        return candidates[seed % candidates.length];
    }

    function _ensureFactoryOwner() internal {
        if (address(digiftFactory) == address(0)) {
            digiftFactory = new DigiftAdapterFactory(
                address(new DigiftAdapter(address(subRedManagement), address(registry), address(digiftEventVerifier))),
                owner
            );
            return;
        }

        if (digiftFactory.owner() == address(0)) {
            digiftFactory = new DigiftAdapterFactory(digiftFactory.implementation(), owner);
        }
    }
}
