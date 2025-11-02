// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FuzzBase} from "@perimetersec/fuzzlib/src/FuzzBase.sol";
import "forge-std/Test.sol";

/**
 * @title FuzzActors
 * @notice Manages deterministic actor addresses for the fuzzing suite
 * @dev Provides a single initialization entrypoint to avoid re-creating actors
 */
contract FuzzActors is FuzzBase, Test {
    // ==============================================================
    // CORE ACTORS
    // ==============================================================
    address internal owner;
    address internal rebalancer;
    address internal protocolFeesAddress;
    address internal vaultSeeder;
    address internal poolManager;
    address internal randomUser;

    // ==============================================================
    // USER ACTORS (ROTATED VIA FUZZING)
    // ==============================================================
    address internal USER1;
    address internal USER2;
    address internal USER3;
    address internal USER4;
    address internal USER5;
    address internal USER6;

    address[] internal USERS;

    /**
     * @notice Lazily initializes all actor addresses
     * @dev Safe to call multiple times – runs only on first invocation
     */
    function _initUsers() internal {
        if (USERS.length != 0) {
            return;
        }

        owner = makeAddr("Owner");
        rebalancer = makeAddr("Rebalancer");
        protocolFeesAddress = makeAddr("ProtocolFees");
        vaultSeeder = makeAddr("VaultSeeder");
        poolManager = makeAddr("PoolManager");
        randomUser = makeAddr("RandomUser");

        USER1 = makeAddr("User1");
        USER2 = makeAddr("User2");
        USER3 = makeAddr("User3");
        USER4 = makeAddr("User4");
        USER5 = makeAddr("User5");
        USER6 = makeAddr("User6");

        USERS = new address[](8);
        USERS[0] = USER1;
        USERS[1] = USER2;
        USERS[2] = USER3;
        USERS[3] = USER4;
        USERS[4] = USER5;
        USERS[5] = USER6;
        USERS[6] = owner;
        USERS[7] = rebalancer;
    }
}
