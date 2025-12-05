// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PropertiesDescriptions {
    string constant ERR_01 = "ERR_01: Unexpected Error";

    // ==============================================================
    // ONEINCH Properties
    // ==============================================================

    string constant ONEINCH_01 =
        "ONEINCH_01: Asset Token Balance Of Node Must Increase After Successful Swap";
    string constant ONEINCH_02 =
        "ONEINCH_02: All Incentive Token Input Must Be Used During Swap";

    // ==============================================================
    // NODE Properties (NODE_01 - NODE_07: Active Invariants)
    // ==============================================================

    string constant NODE_01 =
        "NODE_01: User Share Balance Must Increase After Successful Deposit/Mint";
    string constant NODE_02 =
        "NODE_02: Escrow Share Balance Must Increase By The Redemption Request Amount";
    string constant NODE_03 =
        "NODE_03: Escrow Share Balance Must Decrease After A Redeem Is Finalized";
    string constant NODE_04 =
        "NODE_04: User Asset Balance Must Increase By Requested Asset Amount After Withdraw";
    string constant NODE_05 =
        "NODE_05: Escrow Asset Balance Must Be Greater Than Or Equal To Sum Of All claimableAssets of All Requests";
    string constant NODE_06 =
        "NODE_06: A Component's Asset Holding Ratio Against Total Should Not Exceed Component's Target After Invest";
    string constant NODE_07 =
        "NODE_07: A Node's Reserve Should Not Decrease Below Target Reserve After Invest";

    // ==============================================================
    // NODE Properties (NODE_08 - NODE_11: Deposit Invariants)
    // ==============================================================

    string constant NODE_08 =
        "NODE_08: Receiver Share Balance Must Increase By Minted Shares After Deposit";
    string constant NODE_09 =
        "NODE_09: Node Asset Balance Must Increase By Deposited Assets";
    string constant NODE_10 =
        "NODE_10: Node Total Assets Must Increase By Deposited Assets";
    string constant NODE_11 =
        "NODE_11: Node Total Supply Must Increase By Minted Shares";

    // ==============================================================
    // NODE Properties (NODE_12 - NODE_15: Mint Invariants)
    // ==============================================================

    string constant NODE_12 =
        "NODE_12: Receiver Share Balance Must Increase By Minted Shares";
    string constant NODE_13 =
        "NODE_13: Receiver Asset Balance Must Decrease By Assets Spent";
    string constant NODE_14 =
        "NODE_14: Node Total Assets Must Increase By Assets Spent";
    string constant NODE_15 =
        "NODE_15: Node Total Supply Must Increase By Requested Shares";

    // ==============================================================
    // NODE Properties (NODE_16 - NODE_19: Request Redeem Invariants)
    // ==============================================================

    string constant NODE_16 =
        "NODE_16: Owner Share Balance Must Decrease By Requested Shares";
    string constant NODE_17 =
        "NODE_17: Pending Redeem Must Increase By Requested Shares";
    string constant NODE_18 =
        "NODE_18: Claimable Redeem Must Remain Unchanged After Request";
    string constant NODE_19 =
        "NODE_19: Claimable Assets Must Remain Unchanged After Request";

    // ==============================================================
    // NODE Properties (NODE_20 - NODE_21: Fulfill Redeem Invariants)
    // ==============================================================

    string constant NODE_20 =
        "NODE_20: Pending Redeem Must Decrease After Fulfill";
    string constant NODE_21 =
        "NODE_21: Claimable Redeem Must Increase After Fulfill";

    // ==============================================================
    // NODE Properties (NODE_22 - NODE_23: Withdraw Invariants)
    // ==============================================================

    string constant NODE_22 =
        "NODE_22: Claimable Assets Must Decrease By Withdrawn Amount";
    string constant NODE_23 =
        "NODE_23: Escrow Asset Balance Must Decrease By Withdrawn Amount";

    // ==============================================================
    // NODE Properties (NODE_24 - NODE_28: Finalize Redemption Invariants)
    // ==============================================================

    string constant NODE_24 =
        "NODE_24: Pending Redeem Must Decrease By Finalized Shares";
    string constant NODE_25 =
        "NODE_25: Claimable Redeem Must Increase By Finalized Shares";
    string constant NODE_26 =
        "NODE_26: Claimable Assets Must Increase By Returned Assets";
    string constant NODE_27 =
        "NODE_27: Escrow Asset Balance Must Increase By Returned Assets";
    string constant NODE_28 =
        "NODE_28: Node Asset Balance Must Decrease By Returned Assets";

    // ==============================================================
    // NODE Properties (NODE_29 - NODE_32: Redeem Invariants)
    // ==============================================================

    string constant NODE_29 =
        "NODE_29: Claimable Redeem Must Decrease By Redeemed Shares";
    string constant NODE_30 =
        "NODE_30: Claimable Assets Must Decrease By Returned Assets";
    string constant NODE_31 =
        "NODE_31: Receiver Asset Balance Must Increase By Returned Assets";
    string constant NODE_32 =
        "NODE_32: Escrow Asset Balance Must Decrease By Returned Assets";

    // ==============================================================
    // NODE Properties (NODE_33 - NODE_34: Component Invariants)
    // ==============================================================

    string constant NODE_33 = "NODE_33: Component Must Be Registered After Add";
    string constant NODE_34 =
        "NODE_34: Component Must Be Unregistered After Remove";

    // ==============================================================
    // NODE Properties (NODE_35 - NODE_36: Rescue Tokens Invariants)
    // ==============================================================

    string constant NODE_35 =
        "NODE_35: Node Balance Must Decrease By Rescued Amount";
    string constant NODE_36 =
        "NODE_36: Recipient Balance Must Increase By Rescued Amount";

    // ==============================================================
    // NODE Properties (NODE_37 - NODE_38: Policies Invariants)
    // ==============================================================

    string constant NODE_37 = "NODE_37: Policy Must Be Registered After Add";
    string constant NODE_38 =
        "NODE_38: Policy Must Be Unregistered After Remove";

    // ==============================================================
    // DIGIFT Properties (DIGIFT_01 - DIGIFT_04)
    // ==============================================================

    string constant DIGIFT_01 =
        "DIGIFT_01: Global Pending Deposit Must Match Forwarded Amount";
    string constant DIGIFT_02 =
        "DIGIFT_02: Global Pending Redeem Must Match Forwarded Amount";
    string constant DIGIFT_03 =
        "DIGIFT_03: No Pending Deposits Must Remain After Settle";
    string constant DIGIFT_04 =
        "DIGIFT_04: No Pending Redemptions Must Remain After Settle";

    // ==============================================================
    // REGISTRY Properties (REGISTRY_01 - REGISTRY_06)
    // ==============================================================

    string constant REGISTRY_01 =
        "REGISTRY_01: Protocol Fee Address Must Match Set Value";
    string constant REGISTRY_02 =
        "REGISTRY_02: Protocol Management Fee Must Match Set Value";
    string constant REGISTRY_03 =
        "REGISTRY_03: Protocol Execution Fee Must Match Set Value";
    string constant REGISTRY_04 =
        "REGISTRY_04: Policies Root Must Match Set Value";
    string constant REGISTRY_05 =
        "REGISTRY_05: Registry Type Status Must Match Set Value";
    string constant REGISTRY_06 =
        "REGISTRY_06: Owner Must Match After Transfer";

    // ==============================================================
    // FACTORY Properties (FACTORY_01 - FACTORY_07)
    // ==============================================================

    string constant FACTORY_01 =
        "FACTORY_01: Deployed Node Address Must Not Be Zero";
    string constant FACTORY_02 =
        "FACTORY_02: Deployed Escrow Address Must Not Be Zero";
    string constant FACTORY_03 =
        "FACTORY_03: Node Escrow Link Must Match Deployed Escrow";
    string constant FACTORY_04 =
        "FACTORY_04: Node Asset Must Match Init Args Asset";
    string constant FACTORY_05 =
        "FACTORY_05: Node Owner Must Match Init Args Owner";
    string constant FACTORY_06 =
        "FACTORY_06: Node Total Supply Must Be Zero After Deploy";
    string constant FACTORY_07 =
        "FACTORY_07: Node Must Be Registered In Registry After Deploy";

    // ==============================================================
    // REWARD ROUTER Properties - Fluid (REWARD_FLUID_01 - REWARD_FLUID_05)
    // ==============================================================

    string constant REWARD_FLUID_01 =
        "REWARD_FLUID_01: Claim Recipient Must Be Node Address";
    string constant REWARD_FLUID_02 =
        "REWARD_FLUID_02: Claim Cumulative Amount Must Match Params";
    string constant REWARD_FLUID_03 =
        "REWARD_FLUID_03: Claim Position ID Must Match Params";
    string constant REWARD_FLUID_04 =
        "REWARD_FLUID_04: Claim Cycle Must Match Params";
    string constant REWARD_FLUID_05 =
        "REWARD_FLUID_05: Claim Proof Hash Must Match Params";

    // ==============================================================
    // REWARD ROUTER Properties - Incentra (REWARD_INCENTRA_01 - REWARD_INCENTRA_03)
    // ==============================================================

    string constant REWARD_INCENTRA_01 =
        "REWARD_INCENTRA_01: Last Earner Must Be Node Address";
    string constant REWARD_INCENTRA_02 =
        "REWARD_INCENTRA_02: Campaign Addresses Hash Must Match";
    string constant REWARD_INCENTRA_03 =
        "REWARD_INCENTRA_03: Rewards Hash Must Match";

    // ==============================================================
    // REWARD ROUTER Properties - Merkl (REWARD_MERKL_01 - REWARD_MERKL_04)
    // ==============================================================

    string constant REWARD_MERKL_01 =
        "REWARD_MERKL_01: Users Hash Must Match Params";
    string constant REWARD_MERKL_02 =
        "REWARD_MERKL_02: Tokens Hash Must Match Params";
    string constant REWARD_MERKL_03 =
        "REWARD_MERKL_03: Amounts Hash Must Match Params";
    string constant REWARD_MERKL_04 =
        "REWARD_MERKL_04: Proofs Hash Must Match Params";

    // ==============================================================
    // NODE Properties - Backing Yield (NODE_39 - NODE_40)
    // ==============================================================

    string constant NODE_39 =
        "NODE_39: Component Balance Must Increase By Delta After Gain Backing";
    string constant NODE_40 =
        "NODE_40: Component Balance Must Decrease By Delta After Lose Backing";

    // ==============================================================
    // NODE Properties - Global Invariants (NODE_41)
    // ==============================================================

    string constant NODE_41 =
        "NODE_41: Shares Exiting Must Not Exceed Total Supply";

    // ==============================================================
    // ROUTER4626 Properties (ROUTER4626_01 - ROUTER4626_09)
    // ==============================================================

    string constant ROUTER4626_01 =
        "ROUTER4626_01: Invest Must Return Non-Zero Deposit Amount";
    string constant ROUTER4626_02 =
        "ROUTER4626_02: Node Component Shares Must Not Decrease After Invest";
    string constant ROUTER4626_03 =
        "ROUTER4626_03: Node Asset Balance Must Not Increase After Invest";
    string constant ROUTER4626_04 =
        "ROUTER4626_04: Liquidate Must Return Non-Zero Assets When Expected";
    string constant ROUTER4626_05 =
        "ROUTER4626_05: Node Component Shares Must Not Increase After Liquidate";
    string constant ROUTER4626_06 =
        "ROUTER4626_06: Node Asset Balance Must Not Decrease After Liquidate";
    string constant ROUTER4626_07 =
        "ROUTER4626_07: Fulfill Must Return Non-Zero Assets";
    string constant ROUTER4626_08 =
        "ROUTER4626_08: Escrow Balance Must Not Decrease After Fulfill";
    string constant ROUTER4626_09 =
        "ROUTER4626_09: Node Asset Balance Must Not Increase After Fulfill";

    // ==============================================================
    // ROUTER7540 Properties (ROUTER7540_01 - ROUTER7540_15)
    // ==============================================================

    string constant ROUTER7540_01 =
        "ROUTER7540_01: Invest Must Request Non-Zero Assets";
    string constant ROUTER7540_02 =
        "ROUTER7540_02: Pending Deposit Must Not Decrease After Invest";
    string constant ROUTER7540_03 =
        "ROUTER7540_03: Node Asset Balance Must Not Increase After Invest";
    string constant ROUTER7540_04 =
        "ROUTER7540_04: Node Component Shares Must Increase By Received Shares After Mint";
    string constant ROUTER7540_05 =
        "ROUTER7540_05: Claimable Must Not Increase After Mint";
    string constant ROUTER7540_06 =
        "ROUTER7540_06: Pending Redeem Must Not Decrease After Request Withdrawal";
    string constant ROUTER7540_07 =
        "ROUTER7540_07: Component Share Balance Must Not Increase After Request Withdrawal";
    string constant ROUTER7540_08 =
        "ROUTER7540_08: Execute Withdrawal Must Return Non-Zero Assets";
    string constant ROUTER7540_09 =
        "ROUTER7540_09: Execute Withdrawal Assets Must Match Max Withdraw Before";
    string constant ROUTER7540_10 =
        "ROUTER7540_10: Claimable Must Not Increase After Execute Withdrawal";
    string constant ROUTER7540_11 =
        "ROUTER7540_11: Node Asset Balance Must Not Decrease After Execute Withdrawal";
    string constant ROUTER7540_12 =
        "ROUTER7540_12: Max Withdraw Must Be Zero After Execute Withdrawal";
    string constant ROUTER7540_13 =
        "ROUTER7540_13: Fulfill Redeem Must Return Non-Zero Assets When Expected";
    string constant ROUTER7540_14 =
        "ROUTER7540_14: Escrow Balance Must Not Decrease After Fulfill Redeem";
    string constant ROUTER7540_15 =
        "ROUTER7540_15: Node Asset Balance Must Not Increase After Fulfill Redeem";
    string constant ROUTER7540_16 =
        "ROUTER7540_16: Component Shares Must Not Increase After Fulfill Redeem";

    // ==============================================================
    // ROUTER Settings Properties (ROUTER_01 - ROUTER_03)
    // ==============================================================

    string constant ROUTER_01 =
        "ROUTER_01: Blacklist Status Must Match Set Value";
    string constant ROUTER_02 =
        "ROUTER_02: Whitelist Status Must Match Set Value";
    string constant ROUTER_03 =
        "ROUTER_03: Tolerance Value Must Match Set Value";

    // ==============================================================
    // POOL Properties (POOL_01 - POOL_02)
    // ==============================================================

    string constant POOL_01 =
        "POOL_01: Pending Deposits Must Not Increase After Process";
    string constant POOL_02 =
        "POOL_02: Pending Redemptions Must Be Zero After Process";

    // ==============================================================
    // ONEINCH Extended Properties (ONEINCH_03 - ONEINCH_05)
    // ==============================================================

    string constant ONEINCH_03 =
        "ONEINCH_03: Node Must Receive At Least 99% Of Min Assets Out";
    string constant ONEINCH_04 =
        "ONEINCH_04: Node Must Spend Exact Incentive Amount";
    string constant ONEINCH_05 =
        "ONEINCH_05: Executor Must Receive At Least Incentive Amount";

    // ==============================================================
    // DIGIFT Extended Properties (DIGIFT_05 - DIGIFT_12)
    // ==============================================================

    string constant DIGIFT_05 =
        "DIGIFT_05: Max Mintable Shares Must Be Non-Zero After Settle Deposit";
    string constant DIGIFT_06 =
        "DIGIFT_06: Max Withdrawable Assets Must Be Non-Zero After Settle Redeem";
    string constant DIGIFT_07 =
        "DIGIFT_07: Total Max Withdrawable Must Match Expected Assets";
    string constant DIGIFT_08 =
        "DIGIFT_08: Withdraw Assets Must Match Max Withdraw Before";
    string constant DIGIFT_09 =
        "DIGIFT_09: Node Balance Must Not Decrease After Withdraw";
    string constant DIGIFT_10 =
        "DIGIFT_10: Max Withdraw Must Be Zero After Withdraw";
    string constant DIGIFT_11 =
        "DIGIFT_11: Pending Redeem Must Increase After Request";
    string constant DIGIFT_12 =
        "DIGIFT_12: Balance Must Not Increase After Request Redeem";
}
