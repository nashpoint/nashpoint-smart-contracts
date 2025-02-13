#### Deploy Locally for Front End Testing
Set up .env values for $RPC_URL & $PRIVATE_KEY: 

```
# FOUNDRY CONFIG
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL="http://127.0.0.1:8545"

REBALANCER=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
USER=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
```
Note: these are standard foundry private key and not secure in any way

the foundry.toml must be configured as such or the contracts will not compile. The first time you comile the contracts with these settings it might be slow, but runs faster once foundry has cached one good compile to run deploy scripts from.
```
evm_version = "cancun"
solc = '0.8.28'
gas_limit = 100000000000
optimizer = true
optimizer-runs = 1
via-ir = true
```

On the CLI run:
```
source .env
```

Activate Anvil (local blockchain)
```
anvil
```

Run Deploy Script:
```
forge script script/DeployTestEnv.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
```

Generate ABI:
```
forge inspect Node abi
```

### Starting Conditions:
- The Node is initialized with a three ERC4626 vaults set at 30% target each
- The Node has a 10% target reserve ratio
- The asset token of the Node is ```asset```. Similarly the asset token for each 4626 vault is ```asset```
- User is funded with 1_000_000 units of ```asset```
- Vault is seed with 1000 units of asset
- Swing Pricing is activated
- 300 units of asset are rebalanced into each ERC4626 Vault

### Roles & Functions
Some functions neccessary for testing can only be called by privileged roles.
- ```user``` is just a normal user address with some ```asset``` tokens they can use to deposit to the Node to mint shares
  - Use ```user``` address to ```deposit()```, ```mint()```, ```requestRedeem()```, ```redeem()``` and ```withdraw()``` on the Node contract.
- ```rebalancer``` is responsible for managing the vault cashflow. 
  - They start a rebalance by calling ```startRebalance()``` on Node
  - They invest extra funds user funds from the reserve into the underlying vaults using ```invest()``` on router4626
  - They return funds to user with pendingRedeemRequests by calling ```fulfillRedeemFromReserve()``` on node, or ```fulfilRedeemRequest``` on router4626. 
  - They call ```updateTotalAssets()``` to calculate any new yield that has been earned by the underlying 4626 vaults

#### Typical Deposit Flow:
- A user will deposit the asset token to the Node and receive shares by calling ```deposit()``` or ```mint()```
- The deposited asset token sits in the node reserve earning no yield
- the rebalancer calls ```startRebalance``` to begin executing asset management functions
- the rebalancer calls ```invest()``` on 4626 router to invest excess tokens from the reserve to begin earning yield in one of the vaults

#### Typical Withdrawal Flow:
- A user has shares and wants to redeem from the Node
- The user calls ```requestRedeem()``` on the node. This moves their shares to an escrow contract and creates a pending claim on the that needs to be fulfilled.
- The rebalancer calls ```startRebalance()``` to begin rebalancing the vault. 
- The rebalancer wants to process the pending user request, and can choose between ```fulfillRedeemFromReserve()``` on node or ```fulfilRedeemRequest``` on router4626, depending on where enough assets are available.
- regardless of which function is called, the user's shares at the escrow are burned and assets are sent to the escrow.
- The user can now redeem their assets directly from the node by calling ```redeem()``` or ```withdraw()```

#### Rebalance Window & Cooldown
- To keep the vault in sync, the rebalancer must initiate a rebalance window by calling ```startRebalance()```
- This has the effect of updating the totalAssets and making sure the component ratios are correct.
- It must be called or most of the functions the rebalance wants to call will not work
- It is configured to last for 30 mins, but you can skip to a later block using cast if you want to be outside a rebalance window

#### Simulating Yield
- A simple way to simulate earning yield on any of the ERC4626 vaults is to mint new ERC20 ```asset``` tokens to it and then update total assets so the node can "see" the new share price for vault.
- As the ```deployer``` address, ```mint()``` new asset tokens to a vault
- As the ```rebalancer``` address, call ```updateTotalAssets()``` 
- 
```
deal(address(asset), address(vault), amount)
```
#### Swing Pricing
The node is able to adjust the share price the user receives for a deposit or a withdrawal based on the cash balance of the reserve. This creates an incentive for users to deposit when the reserve is low, and a disincentive to withdraw when the reserve is low.
- This is a nice to have for now, so don't worry about it if too complex to implement
- If you can just show the percentage of the reserve that is currently in the node that is fine
- You can always see the difference between the share price and the adjusted share price for deposits using view functions on the vault
- compare ```previewDeposit()``` to ```convertToShares()``` to see what kind of a bonus a user will get for depositing.
- if the reserve is at or above target this bonus will be zero
- its harder to calculate the penalty for redeeming so don't worry about it


#### Useful Cast Commands

As ```user``` approve and deposit to node

```
cast send <ASSET_CONTRACT_ADDRESS> "approve(address,uint256)" <NODE_ADDRESS> <AMOUNT_IN_WEI> --private-key <USER_PRIVATE_KEY> --rpc-url <RPC_URL>

cast send 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 "approve(address,uint256)" 0xf24e62cf861AAd5A268da5E3858c1C3ACFDA05F5 1000000000000000000000 --private-key 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a --rpc-url $RPC_URL  
```

```
cast send <NODE_ADDRESS> "deposit(uint256,address)" <AMOUNT_IN_WEI> <USER_ADDRESS> --private-key <USER_PRIVATE_KEY> --rpc-url <RPC_URL>

cast send 0xf24e62cf861AAd5A268da5E3858c1C3ACFDA05F5 "deposit(uint256,address)" 1000000000000000000000 "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC" --private-key 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a --rpc-url $RPC_URL
```

Addresses Used
```
node_address = "0xf24e62cf861AAd5A268da5E3858c1C3ACFDA05F5" 
asset_address = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"
router_4626_address = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
rebalancer_address = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
user_address = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
```




