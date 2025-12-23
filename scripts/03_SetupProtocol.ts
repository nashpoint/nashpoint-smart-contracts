import { ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import { NodeRegistry__factory } from '../typechain-types';
import { RegistryType } from './types';
import { getConfig, getContracts, getPoliciesMerkleTree } from './utils';

async function main() {
    const [deployer] = await ethers.getSigners();
    const config = await getConfig(network.config.chainId!);
    const contracts = await getContracts(network.config.chainId!);

    const txs: ContractTransaction[] = [];

    const nodeRegistry = NodeRegistry__factory.connect(contracts.nodeRegistryProxy, deployer);

    const owner = await nodeRegistry.owner();

    // whitelist policies
    for (const policy of Object.values(contracts.policies)) {
        const tx = await nodeRegistry.updateSetupCallWhitelist.populateTransaction(policy, true);
        txs.push(tx);
    }

    // attach factory
    {
        const tx = await nodeRegistry.setRegistryType.populateTransaction(
            contracts.nodeFactory,
            RegistryType.FACTORY,
            true,
        );
        txs.push(tx);
    }

    // whitelist routers
    for (const router of Object.values(contracts.routers)) {
        const tx = await nodeRegistry.setRegistryType.populateTransaction(
            router,
            RegistryType.ROUTER,
            true,
        );
        txs.push(tx);
    }

    // whitelist rebalancers
    for (const router of config.rebalancer) {
        const tx = await nodeRegistry.setRegistryType.populateTransaction(
            router,
            RegistryType.REBALANCER,
            true,
        );
        txs.push(tx);
    }

    // add policy root
    {
        const merkleTree = await getPoliciesMerkleTree(network.config.chainId!);
        const tx = await nodeRegistry.setPoliciesRoot.populateTransaction(merkleTree.root);
        txs.push(tx);
    }

    // sepolia
    if (deployer.address.toLowerCase() === owner.toLowerCase()) {
        console.log(`${txs.length} txs to send`);
        for (let i = 0; i < txs.length; i++) {
            await deployer.sendTransaction(txs[i]).then((t) => t.wait(1));
            console.log(`Sent ${i + 1}`);
        }
    } else {
        // TODO: Safe propose tx
    }
}

main();
