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

    // ==============================================================
    // ONEINCH Properties
    // ==============================================================

    string constant ONEINCH_01 = "ONEINCH_01: Asset Token Balance Of Node Must Increase After Successful Swap";
    string constant ONEINCH_02 = "ONEINCH_02: All Incentive Token Input Must Be Used During Swap";

    // ==============================================================
    // NODE Properties (NODE_01 - NODE_07: Active Invariants)
    // ==============================================================

    string constant NODE_01 = "NODE_01: User Share Balance Must Increase After Successful Deposit/Mint";
    string constant NODE_02 = "NODE_02: Escrow Share Balance Must Increase By The Redemption Request Amount";
    string constant NODE_03 = "NODE_03: Escrow Share Balance Must Decrease After A Redeem Is Finalized";
    string constant NODE_04 = "NODE_04: User Asset Balance Must Increase By Requested Asset Amount After Withdraw";
    string constant NODE_05 = "NODE_05: Escrow Asset Balance Must Be Greater Than Or Equal To Sum Of All claimableAssets of All Requests";
    string constant NODE_06 = "NODE_06: A Component's Asset Holding Ratio Against Total Should Not Exceed Component's Target After Invest";
    string constant NODE_07 = "NODE_07: A Node's Reserve Should Not Decrease Below Target Reserve After Invest";

    // ==============================================================
    // NODE Properties (NODE_08 - NODE_13: Deposit Invariants)
    // ==============================================================

    string constant NODE_08 = "NODE_08: Minted Shares Must Be Greater Than Zero After Deposit";
    string constant NODE_09 = "NODE_09: Receiver Share Balance Must Increase By Minted Shares After Deposit";
    string constant NODE_10 = "NODE_10: Receiver Asset Balance Must Decrease By Deposited Assets";
    string constant NODE_11 = "NODE_11: Node Asset Balance Must Increase By Deposited Assets";
    string constant NODE_12 = "NODE_12: Node Total Assets Must Increase By Deposited Assets";
    string constant NODE_13 = "NODE_13: Node Total Supply Must Increase By Minted Shares";

    // ==============================================================
    // NODE Properties (NODE_14 - NODE_19: Mint Invariants)
    // ==============================================================

    string constant NODE_14 = "NODE_14: Assets Spent Must Be Greater Than Zero After Mint";
    string constant NODE_15 = "NODE_15: Receiver Share Balance Must Increase By Minted Shares";
    string constant NODE_16 = "NODE_16: Receiver Asset Balance Must Decrease By Assets Spent";
    string constant NODE_17 = "NODE_17: Node Asset Balance Must Increase By Assets Spent";
    string constant NODE_18 = "NODE_18: Node Total Assets Must Increase By Assets Spent";
    string constant NODE_19 = "NODE_19: Node Total Supply Must Increase By Requested Shares";

    // ==============================================================
    // NODE Properties (NODE_20 - NODE_24: Request Redeem Invariants)
    // ==============================================================

    string constant NODE_20 = "NODE_20: Owner Share Balance Must Decrease By Requested Shares";
    string constant NODE_21 = "NODE_21: Escrow Share Balance Must Increase By Requested Shares";
    string constant NODE_22 = "NODE_22: Pending Redeem Must Increase By Requested Shares";
    string constant NODE_23 = "NODE_23: Claimable Redeem Must Remain Unchanged After Request";
    string constant NODE_24 = "NODE_24: Claimable Assets Must Remain Unchanged After Request";

    // ==============================================================
    // NODE Properties (NODE_25 - NODE_29: Fulfill Redeem Invariants)
    // ==============================================================

    string constant NODE_25 = "NODE_25: Pending Redeem Must Decrease After Fulfill";
    string constant NODE_26 = "NODE_26: Claimable Assets Must Increase After Fulfill";
    string constant NODE_27 = "NODE_27: Claimable Redeem Must Increase After Fulfill";
    string constant NODE_28 = "NODE_28: Node Asset Balance Must Decrease After Fulfill";
    string constant NODE_29 = "NODE_29: Escrow Asset Balance Must Increase After Fulfill";

    // ==============================================================
    // NODE Properties (NODE_30 - NODE_33: Withdraw Invariants)
    // ==============================================================

    string constant NODE_30 = "NODE_30: Claimable Assets Must Decrease By Withdrawn Amount";
    string constant NODE_31 = "NODE_31: Claimable Redeem Must Decrease By Burned Shares";
    string constant NODE_32 = "NODE_32: Receiver Asset Balance Must Increase By Withdrawn Amount";
    string constant NODE_33 = "NODE_33: Escrow Asset Balance Must Decrease By Withdrawn Amount";

    // ==============================================================
    // NODE Properties (NODE_34 - NODE_35: Operator/Approve Invariants)
    // ==============================================================

    string constant NODE_34 = "NODE_34: Operator Approval Status Must Match Requested Status";
    string constant NODE_35 = "NODE_35: Allowance Must Match Approved Amount";

    // ==============================================================
    // NODE Properties (NODE_36 - NODE_41: Transfer Invariants)
    // ==============================================================

    string constant NODE_36 = "NODE_36: Sender Share Balance Must Decrease By Transfer Amount";
    string constant NODE_37 = "NODE_37: Receiver Share Balance Must Increase By Transfer Amount";
    string constant NODE_38 = "NODE_38: Total Supply Must Remain Unchanged After Transfer";
    string constant NODE_39 = "NODE_39: Owner Share Balance Must Decrease By TransferFrom Amount";
    string constant NODE_40 = "NODE_40: Receiver Share Balance Must Increase By TransferFrom Amount";
    string constant NODE_41 = "NODE_41: Allowance Must Decrease By TransferFrom Amount";

    // ==============================================================
    // NODE Properties (NODE_42 - NODE_45: Redeem Invariants)
    // ==============================================================

    string constant NODE_42 = "NODE_42: Claimable Redeem Must Decrease By Redeemed Shares";
    string constant NODE_43 = "NODE_43: Claimable Assets Must Decrease By Returned Assets";
    string constant NODE_44 = "NODE_44: Receiver Asset Balance Must Increase By Returned Assets";
    string constant NODE_45 = "NODE_45: Escrow Asset Balance Must Decrease By Returned Assets";

    // ==============================================================
    // NODE Properties (NODE_46 - NODE_48: Ownership/Initialize Invariants)
    // ==============================================================

    string constant NODE_46 = "NODE_46: Renounce Ownership Must Always Revert";
    string constant NODE_47 = "NODE_47: Transfer Ownership Must Always Revert";
    string constant NODE_48 = "NODE_48: Initialize Must Always Revert (Already Initialized)";

    // ==============================================================
    // NODE Properties (NODE_49 - NODE_54: Fee/Config Invariants)
    // ==============================================================

    string constant NODE_49 = "NODE_49: Annual Management Fee Must Match Set Value";
    string constant NODE_50 = "NODE_50: Max Deposit Size Must Match Set Value";
    string constant NODE_51 = "NODE_51: Node Owner Fee Address Must Match Set Value";
    string constant NODE_52 = "NODE_52: Quoter Address Must Match Set Value";
    string constant NODE_53 = "NODE_53: Rebalance Cooldown Must Match Set Value";
    string constant NODE_54 = "NODE_54: Rebalance Window Must Match Set Value";

    // ==============================================================
    // NODE Properties (NODE_55 - NODE_60: Component Invariants)
    // ==============================================================

    string constant NODE_55 = "NODE_55: Component Must Be Registered After Add";
    string constant NODE_56 = "NODE_56: Component Target Weight Must Match Set Value";
    string constant NODE_57 = "NODE_57: Component Max Delta Must Match Set Value";
    string constant NODE_58 = "NODE_58: Component Router Must Match Set Value";
    string constant NODE_59 = "NODE_59: Component Must Be Unregistered After Remove";
    string constant NODE_60 = "NODE_60: Component Queue Length Must Match After Set";

    // ==============================================================
    // NODE Properties (NODE_61 - NODE_62: Rescue Tokens Invariants)
    // ==============================================================

    string constant NODE_61 = "NODE_61: Node Balance Must Decrease By Rescued Amount";
    string constant NODE_62 = "NODE_62: Recipient Balance Must Increase By Rescued Amount";

    // ==============================================================
    // NODE Properties (NODE_63 - NODE_64: Policies Invariants)
    // ==============================================================

    string constant NODE_63 = "NODE_63: Policy Must Be Registered After Add";
    string constant NODE_64 = "NODE_64: Policy Must Be Unregistered After Remove";

    // ==============================================================
    // NODE Properties (NODE_65 - NODE_68: Rebalancer/Router Invariants)
    // ==============================================================

    string constant NODE_65 = "NODE_65: Rebalancer Must Be Registered After Add";
    string constant NODE_66 = "NODE_66: Rebalancer Must Be Unregistered After Remove";
    string constant NODE_67 = "NODE_67: Router Must Be Registered After Add";
    string constant NODE_68 = "NODE_68: Router Must Be Unregistered After Remove";

    // ==============================================================
    // NODE Properties (NODE_69 - NODE_73: Rebalance Invariants)
    // ==============================================================

    string constant NODE_69 = "NODE_69: Last Rebalance Timestamp Must Not Decrease";
    string constant NODE_70 = "NODE_70: Cache Must Be Valid After Rebalance";
    string constant NODE_71 = "NODE_71: Component Ratios Must Be Valid After Rebalance";
    string constant NODE_72 = "NODE_72: Fee Flow Must Balance (Owner + Protocol = Node Delta)";
    string constant NODE_73 = "NODE_73: Total Assets Must Not Increase After Rebalance";

    // ==============================================================
    // NODE Properties (NODE_74 - NODE_77: Pay Management Fees Invariants)
    // ==============================================================

    string constant NODE_74 = "NODE_74: Fee Payment Flow Must Balance";
    string constant NODE_75 = "NODE_75: Fee Return Value Must Match Actual Transfer";
    string constant NODE_76 = "NODE_76: Last Payment Timestamp Must Increase When Fees Paid";
    string constant NODE_77 = "NODE_77: Last Payment Timestamp Must Stay Same When No Fees";

    // ==============================================================
    // NODE Properties (NODE_78 - NODE_82: Update/Execute Invariants)
    // ==============================================================

    string constant NODE_78 = "NODE_78: Total Assets Cache Must Match After Update";
    string constant NODE_79 = "NODE_79: Node Balance Delta Must Equal Execution Fee";
    string constant NODE_80 = "NODE_80: Protocol Balance Delta Must Equal Execution Fee";
    string constant NODE_81 = "NODE_81: Allowance After Execute Must Match Requested";
    string constant NODE_82 = "NODE_82: Node Asset Balance Must Stay Same After Execute";

    // ==============================================================
    // NODE Properties (NODE_83 - NODE_88: Finalize Redemption Invariants)
    // ==============================================================

    string constant NODE_83 = "NODE_83: Pending Redeem Must Decrease By Finalized Shares";
    string constant NODE_84 = "NODE_84: Claimable Redeem Must Increase By Finalized Shares";
    string constant NODE_85 = "NODE_85: Claimable Assets Must Increase By Returned Assets";
    string constant NODE_86 = "NODE_86: Escrow Asset Balance Must Increase By Returned Assets";
    string constant NODE_87 = "NODE_87: Node Asset Balance Must Decrease By Returned Assets";
    string constant NODE_88 = "NODE_88: Shares Exiting Must Decrease By Adjusted Shares";

    // ==============================================================
    // NODE Properties (NODE_89 - NODE_91: Target Reserve/Swing Pricing Invariants)
    // ==============================================================

    string constant NODE_89 = "NODE_89: Target Reserve Ratio Must Match Set Value";
    string constant NODE_90 = "NODE_90: Swing Pricing Status Must Match Set Value";
    string constant NODE_91 = "NODE_91: Max Swing Factor Must Match Set Value";

    // ==============================================================
    // NODE Properties (NODE_92 - NODE_94: Router Config Invariants)
    // ==============================================================

    string constant NODE_92 = "NODE_92: Router Blacklist Status Must Match Set Value";
    string constant NODE_93 = "NODE_93: Router Whitelist Status Must Match Set Value";
    string constant NODE_94 = "NODE_94: Router Tolerance Must Match Set Value";

    // ==============================================================
    // DIGIFT Properties (DIGIFT_01 - DIGIFT_18)
    // ==============================================================

    string constant DIGIFT_01 = "DIGIFT_01: Global Pending Deposit Must Match Forwarded Amount";
    string constant DIGIFT_02 = "DIGIFT_02: Global Pending Redeem Must Match Forwarded Amount";
    string constant DIGIFT_03 = "DIGIFT_03: No Pending Deposits Must Remain After Settle";
    string constant DIGIFT_04 = "DIGIFT_04: No Pending Redemptions Must Remain After Settle";
    string constant DIGIFT_05 = "DIGIFT_05: Asset Allowance Must Match Approved Amount";
    string constant DIGIFT_06 = "DIGIFT_06: Adapter Allowance Must Match Approved Amount";
    string constant DIGIFT_07 = "DIGIFT_07: Pending Deposit Request Must Match Requested Amount";
    string constant DIGIFT_08 = "DIGIFT_08: Global Pending Deposit Must Be Zero When No Expected";
    string constant DIGIFT_09 = "DIGIFT_09: Global Pending Redeem Must Be Zero When No Expected";
    string constant DIGIFT_10 = "DIGIFT_10: Global Pending Must Be Zero After Settle";
    string constant DIGIFT_11 = "DIGIFT_11: Withdraw Assets Must Match Max Withdraw";
    string constant DIGIFT_12 = "DIGIFT_12: Node Balance Must Not Decrease After Withdraw";
    string constant DIGIFT_13 = "DIGIFT_13: Max Withdraw Must Be Zero After Withdraw";
    string constant DIGIFT_14 = "DIGIFT_14: Pending Redeem Must Increase After Request";
    string constant DIGIFT_15 = "DIGIFT_15: Balance Must Not Increase After Redeem Request";
    string constant DIGIFT_16 = "DIGIFT_16: Manager/Node Whitelist Status Must Match";
    string constant DIGIFT_17 = "DIGIFT_17: Uint Config Value Must Match Set Value";
    string constant DIGIFT_18 = "DIGIFT_18: Last Price Must Be Greater Than Zero After Update";

    // ==============================================================
    // DIGIFT VERIFIER Properties (DIGIFT_VERIFIER_01 - DIGIFT_VERIFIER_03)
    // ==============================================================

    string constant DIGIFT_VERIFIER_01 = "DIGIFT_VERIFIER_01: Configure Settlement Must Match Expected Values";
    string constant DIGIFT_VERIFIER_02 = "DIGIFT_VERIFIER_02: Whitelist Status Must Match Set Value";
    string constant DIGIFT_VERIFIER_03 = "DIGIFT_VERIFIER_03: Verify Must Return Expected Values";

    // ==============================================================
    // REGISTRY Properties (REGISTRY_01 - REGISTRY_11)
    // ==============================================================

    string constant REGISTRY_01 = "REGISTRY_01: Protocol Fee Address Must Match Set Value";
    string constant REGISTRY_02 = "REGISTRY_02: Protocol Management Fee Must Match Set Value";
    string constant REGISTRY_03 = "REGISTRY_03: Protocol Execution Fee Must Match Set Value";
    string constant REGISTRY_04 = "REGISTRY_04: Protocol Max Swing Factor Must Match Set Value";
    string constant REGISTRY_05 = "REGISTRY_05: Policies Root Must Match Set Value";
    string constant REGISTRY_06 = "REGISTRY_06: Registry Type Status Must Match Set Value";
    string constant REGISTRY_07 = "REGISTRY_07: Node Must Be Registered After Add";
    string constant REGISTRY_08 = "REGISTRY_08: Owner Must Match After Transfer";
    string constant REGISTRY_09 = "REGISTRY_09: Renounce Ownership Must Always Revert";
    string constant REGISTRY_10 = "REGISTRY_10: Initialize Must Always Revert (Already Initialized)";
    string constant REGISTRY_11 = "REGISTRY_11: Upgrade Must Revert For Unauthorized Callers";

    // ==============================================================
    // FACTORY Properties (FACTORY_01 - FACTORY_07)
    // ==============================================================

    string constant FACTORY_01 = "FACTORY_01: Deployed Node Address Must Not Be Zero";
    string constant FACTORY_02 = "FACTORY_02: Deployed Escrow Address Must Not Be Zero";
    string constant FACTORY_03 = "FACTORY_03: Node Escrow Link Must Match Deployed Escrow";
    string constant FACTORY_04 = "FACTORY_04: Node Asset Must Match Init Args Asset";
    string constant FACTORY_05 = "FACTORY_05: Node Owner Must Match Init Args Owner";
    string constant FACTORY_06 = "FACTORY_06: Node Total Supply Must Be Zero After Deploy";
    string constant FACTORY_07 = "FACTORY_07: Node Must Be Registered In Registry After Deploy";

    // ==============================================================
    // REWARD ROUTER Properties - Fluid (REWARD_FLUID_01 - REWARD_FLUID_05)
    // ==============================================================

    string constant REWARD_FLUID_01 = "REWARD_FLUID_01: Claim Recipient Must Be Node Address";
    string constant REWARD_FLUID_02 = "REWARD_FLUID_02: Claim Cumulative Amount Must Match Params";
    string constant REWARD_FLUID_03 = "REWARD_FLUID_03: Claim Position ID Must Match Params";
    string constant REWARD_FLUID_04 = "REWARD_FLUID_04: Claim Cycle Must Match Params";
    string constant REWARD_FLUID_05 = "REWARD_FLUID_05: Claim Proof Hash Must Match Params";

    // ==============================================================
    // REWARD ROUTER Properties - Incentra (REWARD_INCENTRA_01 - REWARD_INCENTRA_03)
    // ==============================================================

    string constant REWARD_INCENTRA_01 = "REWARD_INCENTRA_01: Last Earner Must Be Node Address";
    string constant REWARD_INCENTRA_02 = "REWARD_INCENTRA_02: Campaign Addresses Hash Must Match";
    string constant REWARD_INCENTRA_03 = "REWARD_INCENTRA_03: Rewards Hash Must Match";

    // ==============================================================
    // REWARD ROUTER Properties - Merkl (REWARD_MERKL_01 - REWARD_MERKL_04)
    // ==============================================================

    string constant REWARD_MERKL_01 = "REWARD_MERKL_01: Users Hash Must Match Params";
    string constant REWARD_MERKL_02 = "REWARD_MERKL_02: Tokens Hash Must Match Params";
    string constant REWARD_MERKL_03 = "REWARD_MERKL_03: Amounts Hash Must Match Params";
    string constant REWARD_MERKL_04 = "REWARD_MERKL_04: Proofs Hash Must Match Params";
}
