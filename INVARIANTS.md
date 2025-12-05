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
| NODE-08 | Receiver Share Balance Must Increase By Minted Shares After Deposit |  |  |  |
| NODE-09 | Node Asset Balance Must Increase By Deposited Assets |  |  |  |
| NODE-10 | Node Total Assets Must Increase By Deposited Assets |  |  |  |
| NODE-11 | Node Total Supply Must Increase By Minted Shares |  |  |  |
| **NODE - Mint Invariants** |  |  |  |  |
| NODE-12 | Receiver Share Balance Must Increase By Minted Shares |  |  |  |
| NODE-13 | Node Asset Balance Must Increase By Assets Spent |  |  |  |
| NODE-14 | Node Total Assets Must Increase By Assets Spent |  |  |  |
| NODE-15 | Node Total Supply Must Increase By Requested Shares |  |  |  |
| **NODE - Request Redeem Invariants** |  |  |  |  |
| NODE-16 | Owner Share Balance Must Decrease By Requested Shares |  |  |  |
| NODE-17 | Pending Redeem Must Increase By Requested Shares |  |  |  |
| NODE-18 | Claimable Redeem Must Remain Unchanged After Request |  |  |  |
| NODE-19 | Claimable Assets Must Remain Unchanged After Request |  |  |  |
| **NODE - Fulfill Redeem Invariants** |  |  |  |  |
| NODE-20 | Pending Redeem Must Decrease After Fulfill |  |  |  |
| NODE-21 | Claimable Redeem Must Increase After Fulfill |  |  |  |
| **NODE - Withdraw Invariants** |  |  |  |  |
| NODE-22 | Claimable Assets Must Decrease By Withdrawn Amount |  |  |  |
| NODE-23 | Escrow Asset Balance Must Decrease By Withdrawn Amount |  |  |  |
| **NODE - Finalize Redemption Invariants** |  |  |  |  |
| NODE-24 | Pending Redeem Must Decrease By Finalized Shares |  |  |  |
| NODE-25 | Claimable Redeem Must Increase By Finalized Shares |  |  |  |
| NODE-26 | Claimable Assets Must Increase By Returned Assets |  |  |  |
| NODE-27 | Escrow Asset Balance Must Increase By Returned Assets |  |  |  |
| NODE-28 | Node Asset Balance Must Decrease By Returned Assets |  |  |  |
| **NODE - Redeem Invariants** |  |  |  |  |
| NODE-29 | Claimable Redeem Must Decrease By Redeemed Shares |  |  |  |
| NODE-30 | Claimable Assets Must Decrease By Returned Assets |  |  |  |
| NODE-31 | Receiver Asset Balance Must Increase By Returned Assets |  |  |  |
| NODE-32 | Escrow Asset Balance Must Decrease By Returned Assets |  |  |  |
| **NODE - Component Invariants** |  |  |  |  |
| NODE-33 | Component Must Be Registered After Add |  |  |  |
| NODE-34 | Component Must Be Unregistered After Remove |  |  |  | 
| **NODE - Rescue Tokens Invariants** |  |  |  |  |
| NODE-35 | Node Balance Must Decrease By Rescued Amount |  |  |  |
| NODE-36 | Recipient Balance Must Increase By Rescued Amount |  |  |  |
| **NODE - Policies Invariants** |  |  |  |  |
| NODE-37 | Policy Must Be Registered After Add |  |  |  |
| NODE-38 | Policy Must Be Unregistered After Remove |  |  |  |
| **DIGIFT ADAPTER** |  |  |  |  |
| DIGIFT-01 | Global Pending Deposit Must Match Forwarded Amount |  |  |  |
| DIGIFT-02 | Global Pending Redeem Must Match Forwarded Amount |  |  |  |
| DIGIFT-03 | No Pending Deposits Must Remain After Settle |  |  |  |
| DIGIFT-04 | No Pending Redemptions Must Remain After Settle |  |  |  |
| **REGISTRY** |  |  |  |  |
| REGISTRY-01 | Protocol Fee Address Must Match Set Value |  |  |  |
| REGISTRY-02 | Protocol Management Fee Must Match Set Value |  |  |  |
| REGISTRY-03 | Protocol Execution Fee Must Match Set Value |  |  |  |
| REGISTRY-04 | Policies Root Must Match Set Value |  |  |  |
| REGISTRY-05 | Registry Type Status Must Match Set Value |  |  |  |
| REGISTRY-06 | Owner Must Match After Transfer |  |  |  |
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
