// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PropertiesDescriptions {
    // ==============================================================
    // Global Properties (GLOB)
    // These properties define invariants that must hold true across all market states and operations
    // ==============================================================

    string constant GLOB_01 = "GLOB_01: Sample Global Invariant";

    // ==============================================================
    // Invariant Properties (INV)
    // These properties define invariants that must hold true as a sample
    // ==============================================================

    string constant INV_01 = "INV_01: Sample Invariant";

    string constant ERR_01 = "ERR_01: Unexpected Error";

    string constant ONEINCH_01 = "ONEINCH_01: Asset Token Balance Of Node Must Increase After Successful Swap";

    string constant ONEINCH_02 = "ONEINCH_02: All Incentive Token Input Must Be Used During Swap";

    string constant NODE_01 = "NODE_01: User Share Balance Must Increase After Successful Deposit/Mint";

    string constant NODE_02 = "NODE_02: Escrow Share Balance Must Increase By The Redemption Request Amount";

    string constant NODE_03 = "NODE_03: Escrow Share Balance Must Decrease After A Redeem Is Finalized";

    string constant NODE_04 = "NODE_04: User Asset Balance Must Increase By Requested Asset Amount After Withdraw";

    string constant NODE_05 = "NODE_05: Escrow Asset Balance Must Be Greater Than Or Equal To Sum Of All claimableAssets of All Requests";

    string constant NODE_06 = "NODE_06: A Component's Asset Holding Ratio Against Total Should Not Exceed Component's Target After Invest";

    string constant NODE_07 = "NODE_07: A Node's Reserve Should Not Decrease Below Target Reserve After Invest";

}
