# List of Assertions

| Invariant ID | Invariant Description | Passed | Remediations | Run Count |
| --- | --- | --- | --- | --- |
| **GLOBAL** |  |  |  |  |
| GLOB-01 | Sample Global Invariant |  |  |  |
| INV-01 | Sample Invariant |  |  |  |
| ERR-01 | Unexpected Error |  |  |  |
| **ONEINCH** |  |  |  |  |
| ONEINCH-01 | Asset Token Balance Of Node Must Increase After Successful Swap |  |  |  |
| ONEINCH-02 | All Incentive Token Input Must Be Used During Swap |  |  |  |
| **NODE - Deposit/Mint (Active)** |  |  |  |  |
| NODE-01 | User Share Balance Must Increase After Successful Deposit/Mint |  |  |  |
| NODE-02 | Escrow Share Balance Must Increase By The Redemption Request Amount |  |  |  |
| NODE-03 | Escrow Share Balance Must Decrease After A Redeem Is Finalized |  |  |  |
| NODE-04 | User Asset Balance Must Increase By Requested Asset Amount After Withdraw |  |  |  |
| NODE-05 | Escrow Asset Balance Must Be Greater Than Or Equal To Sum Of All claimableAssets of All Requests |  |  |  |
| NODE-06 | A Component's Asset Holding Ratio Against Total Should Not Exceed Component's Target After Invest |  |  |  |
| NODE-07 | A Node's Reserve Should Not Decrease Below Target Reserve After Invest |  |  |  |
| **NODE - Deposit Invariants** |  |  |  |  |
| NODE-08 | Minted Shares Must Be Greater Than Zero After Deposit |  |  |  |
| NODE-09 | Receiver Share Balance Must Increase By Minted Shares After Deposit |  |  |  |
| NODE-10 | Receiver Asset Balance Must Decrease By Deposited Assets |  |  |  |
| NODE-11 | Node Asset Balance Must Increase By Deposited Assets |  |  |  |
| NODE-12 | Node Total Assets Must Increase By Deposited Assets |  |  |  |
| NODE-13 | Node Total Supply Must Increase By Minted Shares |  |  |  |
| **NODE - Mint Invariants** |  |  |  |  |
| NODE-14 | Assets Spent Must Be Greater Than Zero After Mint |  |  |  |
| NODE-15 | Receiver Share Balance Must Increase By Minted Shares |  |  |  |
| NODE-16 | Receiver Asset Balance Must Decrease By Assets Spent |  |  |  |
| NODE-17 | Node Asset Balance Must Increase By Assets Spent |  |  |  |
| NODE-18 | Node Total Assets Must Increase By Assets Spent |  |  |  |
| NODE-19 | Node Total Supply Must Increase By Requested Shares |  |  |  |
| **NODE - Request Redeem Invariants** |  |  |  |  |
| NODE-20 | Owner Share Balance Must Decrease By Requested Shares |  |  |  |
| NODE-21 | Escrow Share Balance Must Increase By Requested Shares |  |  |  |
| NODE-22 | Pending Redeem Must Increase By Requested Shares |  |  |  |
| NODE-23 | Claimable Redeem Must Remain Unchanged After Request |  |  |  |
| NODE-24 | Claimable Assets Must Remain Unchanged After Request |  |  |  |
| **NODE - Fulfill Redeem Invariants** |  |  |  |  |
| NODE-25 | Pending Redeem Must Decrease After Fulfill |  |  |  |
| NODE-26 | Claimable Assets Must Increase After Fulfill |  |  |  |
| NODE-27 | Claimable Redeem Must Increase After Fulfill |  |  |  |
| NODE-28 | Node Asset Balance Must Decrease After Fulfill |  |  |  |
| NODE-29 | Escrow Asset Balance Must Increase After Fulfill |  |  |  |
| **NODE - Withdraw Invariants** |  |  |  |  |
| NODE-30 | Claimable Assets Must Decrease By Withdrawn Amount |  |  |  |
| NODE-31 | Claimable Redeem Must Decrease By Burned Shares |  |  |  |
| NODE-32 | Receiver Asset Balance Must Increase By Withdrawn Amount |  |  |  |
| NODE-33 | Escrow Asset Balance Must Decrease By Withdrawn Amount |  |  |  |
| **NODE - Operator/Approve Invariants** |  |  |  |  |
| NODE-34 | Operator Approval Status Must Match Requested Status |  |  |  |
| NODE-35 | Allowance Must Match Approved Amount |  |  |  |
| **NODE - Transfer Invariants** |  |  |  |  |
| NODE-36 | Sender Share Balance Must Decrease By Transfer Amount |  |  |  |
| NODE-37 | Receiver Share Balance Must Increase By Transfer Amount |  |  |  |
| NODE-38 | Total Supply Must Remain Unchanged After Transfer |  |  |  |
| NODE-39 | Owner Share Balance Must Decrease By TransferFrom Amount |  |  |  |
| NODE-40 | Receiver Share Balance Must Increase By TransferFrom Amount |  |  |  |
| NODE-41 | Allowance Must Decrease By TransferFrom Amount |  |  |  |
| **NODE - Redeem Invariants** |  |  |  |  |
| NODE-42 | Claimable Redeem Must Decrease By Redeemed Shares |  |  |  |
| NODE-43 | Claimable Assets Must Decrease By Returned Assets |  |  |  |
| NODE-44 | Receiver Asset Balance Must Increase By Returned Assets |  |  |  |
| NODE-45 | Escrow Asset Balance Must Decrease By Returned Assets |  |  |  |
| **NODE - Ownership/Initialize Invariants** |  |  |  |  |
| NODE-46 | Renounce Ownership Must Always Revert |  |  |  |
| NODE-47 | Transfer Ownership Must Always Revert |  |  |  |
| NODE-48 | Initialize Must Always Revert (Already Initialized) |  |  |  |
| **NODE - Fee/Config Invariants** |  |  |  |  |
| NODE-49 | Annual Management Fee Must Match Set Value |  |  |  |
| NODE-50 | Max Deposit Size Must Match Set Value |  |  |  |
| NODE-51 | Node Owner Fee Address Must Match Set Value |  |  |  |
| NODE-52 | Quoter Address Must Match Set Value |  |  |  |
| NODE-53 | Rebalance Cooldown Must Match Set Value |  |  |  |
| NODE-54 | Rebalance Window Must Match Set Value |  |  |  |
| **NODE - Component Invariants** |  |  |  |  |
| NODE-55 | Component Must Be Registered After Add |  |  |  |
| NODE-56 | Component Target Weight Must Match Set Value |  |  |  |
| NODE-57 | Component Max Delta Must Match Set Value |  |  |  |
| NODE-58 | Component Router Must Match Set Value |  |  |  |
| NODE-59 | Component Must Be Unregistered After Remove |  |  |  |
| NODE-60 | Component Queue Length Must Match After Set |  |  |  |
| **NODE - Rescue Tokens Invariants** |  |  |  |  |
| NODE-61 | Node Balance Must Decrease By Rescued Amount |  |  |  |
| NODE-62 | Recipient Balance Must Increase By Rescued Amount |  |  |  |
| **NODE - Policies Invariants** |  |  |  |  |
| NODE-63 | Policy Must Be Registered After Add |  |  |  |
| NODE-64 | Policy Must Be Unregistered After Remove |  |  |  |
| **NODE - Rebalancer/Router Invariants** |  |  |  |  |
| NODE-65 | Rebalancer Must Be Registered After Add |  |  |  |
| NODE-66 | Rebalancer Must Be Unregistered After Remove |  |  |  |
| NODE-67 | Router Must Be Registered After Add |  |  |  |
| NODE-68 | Router Must Be Unregistered After Remove |  |  |  |
| **NODE - Rebalance Invariants** |  |  |  |  |
| NODE-69 | Last Rebalance Timestamp Must Not Decrease |  |  |  |
| NODE-70 | Cache Must Be Valid After Rebalance |  |  |  |
| NODE-71 | Component Ratios Must Be Valid After Rebalance |  |  |  |
| NODE-72 | Fee Flow Must Balance (Owner + Protocol = Node Delta) |  |  |  |
| NODE-73 | Total Assets Must Not Increase After Rebalance |  |  |  |
| **NODE - Pay Management Fees Invariants** |  |  |  |  |
| NODE-74 | Fee Payment Flow Must Balance |  |  |  |
| NODE-75 | Fee Return Value Must Match Actual Transfer |  |  |  |
| NODE-76 | Last Payment Timestamp Must Increase When Fees Paid |  |  |  |
| NODE-77 | Last Payment Timestamp Must Stay Same When No Fees |  |  |  |
| **NODE - Update/Execute Invariants** |  |  |  |  |
| NODE-78 | Total Assets Cache Must Match After Update |  |  |  |
| NODE-79 | Node Balance Delta Must Equal Execution Fee |  |  |  |
| NODE-80 | Protocol Balance Delta Must Equal Execution Fee |  |  |  |
| NODE-81 | Allowance After Execute Must Match Requested |  |  |  |
| NODE-82 | Node Asset Balance Must Stay Same After Execute |  |  |  |
| **NODE - Finalize Redemption Invariants** |  |  |  |  |
| NODE-83 | Pending Redeem Must Decrease By Finalized Shares |  |  |  |
| NODE-84 | Claimable Redeem Must Increase By Finalized Shares |  |  |  |
| NODE-85 | Claimable Assets Must Increase By Returned Assets |  |  |  |
| NODE-86 | Escrow Asset Balance Must Increase By Returned Assets |  |  |  |
| NODE-87 | Node Asset Balance Must Decrease By Returned Assets |  |  |  |
| NODE-88 | Shares Exiting Must Decrease By Adjusted Shares |  |  |  |
| **NODE - Target Reserve/Swing Pricing Invariants** |  |  |  |  |
| NODE-89 | Target Reserve Ratio Must Match Set Value |  |  |  |
| NODE-90 | Swing Pricing Status Must Match Set Value |  |  |  |
| NODE-91 | Max Swing Factor Must Match Set Value |  |  |  |
| **NODE - Router Config Invariants** |  |  |  |  |
| NODE-92 | Router Blacklist Status Must Match Set Value |  |  |  |
| NODE-93 | Router Whitelist Status Must Match Set Value |  |  |  |
| NODE-94 | Router Tolerance Must Match Set Value |  |  |  |
| **DIGIFT ADAPTER** |  |  |  |  |
| DIGIFT-01 | Global Pending Deposit Must Match Forwarded Amount |  |  |  |
| DIGIFT-02 | Global Pending Redeem Must Match Forwarded Amount |  |  |  |
| DIGIFT-03 | No Pending Deposits Must Remain After Settle |  |  |  |
| DIGIFT-04 | No Pending Redemptions Must Remain After Settle |  |  |  |
| DIGIFT-05 | Asset Allowance Must Match Approved Amount |  |  |  |
| DIGIFT-06 | Adapter Allowance Must Match Approved Amount |  |  |  |
| DIGIFT-07 | Pending Deposit Request Must Match Requested Amount |  |  |  |
| DIGIFT-08 | Global Pending Deposit Must Be Zero When No Expected |  |  |  |
| DIGIFT-09 | Global Pending Redeem Must Be Zero When No Expected |  |  |  |
| DIGIFT-10 | Global Pending Must Be Zero After Settle |  |  |  |
| DIGIFT-11 | Withdraw Assets Must Match Max Withdraw |  |  |  |
| DIGIFT-12 | Node Balance Must Not Decrease After Withdraw |  |  |  |
| DIGIFT-13 | Max Withdraw Must Be Zero After Withdraw |  |  |  |
| DIGIFT-14 | Pending Redeem Must Increase After Request |  |  |  |
| DIGIFT-15 | Balance Must Not Increase After Redeem Request |  |  |  |
| DIGIFT-16 | Manager/Node Whitelist Status Must Match |  |  |  |
| DIGIFT-17 | Uint Config Value Must Match Set Value |  |  |  |
| DIGIFT-18 | Last Price Must Be Greater Than Zero After Update |  |  |  |
| **DIGIFT VERIFIER** |  |  |  |  |
| DIGIFT-VERIFIER-01 | Configure Settlement Must Match Expected Values |  |  |  |
| DIGIFT-VERIFIER-02 | Whitelist Status Must Match Set Value |  |  |  |
| DIGIFT-VERIFIER-03 | Verify Must Return Expected Values |  |  |  |
| **REGISTRY** |  |  |  |  |
| REGISTRY-01 | Protocol Fee Address Must Match Set Value |  |  |  |
| REGISTRY-02 | Protocol Management Fee Must Match Set Value |  |  |  |
| REGISTRY-03 | Protocol Execution Fee Must Match Set Value |  |  |  |
| REGISTRY-04 | Protocol Max Swing Factor Must Match Set Value |  |  |  |
| REGISTRY-05 | Policies Root Must Match Set Value |  |  |  |
| REGISTRY-06 | Registry Type Status Must Match Set Value |  |  |  |
| REGISTRY-07 | Node Must Be Registered After Add |  |  |  |
| REGISTRY-08 | Owner Must Match After Transfer |  |  |  |
| REGISTRY-09 | Renounce Ownership Must Always Revert |  |  |  |
| REGISTRY-10 | Initialize Must Always Revert (Already Initialized) |  |  |  |
| REGISTRY-11 | Upgrade Must Revert For Unauthorized Callers |  |  |  |
| **FACTORY** |  |  |  |  |
| FACTORY-01 | Deployed Node Address Must Not Be Zero |  |  |  |
| FACTORY-02 | Deployed Escrow Address Must Not Be Zero |  |  |  |
| FACTORY-03 | Node Escrow Link Must Match Deployed Escrow |  |  |  |
| FACTORY-04 | Node Asset Must Match Init Args Asset |  |  |  |
| FACTORY-05 | Node Owner Must Match Init Args Owner |  |  |  |
| FACTORY-06 | Node Total Supply Must Be Zero After Deploy |  |  |  |
| FACTORY-07 | Node Must Be Registered In Registry After Deploy |  |  |  |
| **REWARD ROUTER - Fluid** |  |  |  |  |
| REWARD-FLUID-01 | Claim Recipient Must Be Node Address |  |  |  |
| REWARD-FLUID-02 | Claim Cumulative Amount Must Match Params |  |  |  |
| REWARD-FLUID-03 | Claim Position ID Must Match Params |  |  |  |
| REWARD-FLUID-04 | Claim Cycle Must Match Params |  |  |  |
| REWARD-FLUID-05 | Claim Proof Hash Must Match Params |  |  |  |
| **REWARD ROUTER - Incentra** |  |  |  |  |
| REWARD-INCENTRA-01 | Last Earner Must Be Node Address |  |  |  |
| REWARD-INCENTRA-02 | Campaign Addresses Hash Must Match |  |  |  |
| REWARD-INCENTRA-03 | Rewards Hash Must Match |  |  |  |
| **REWARD ROUTER - Merkl** |  |  |  |  |
| REWARD-MERKL-01 | Users Hash Must Match Params |  |  |  |
| REWARD-MERKL-02 | Tokens Hash Must Match Params |  |  |  |
| REWARD-MERKL-03 | Amounts Hash Must Match Params |  |  |  |
| REWARD-MERKL-04 | Proofs Hash Must Match Params |  |  |  |
