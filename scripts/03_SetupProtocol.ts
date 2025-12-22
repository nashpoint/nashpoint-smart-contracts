import { ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import { NodeRegistry__factory } from '../typechain-types';
import { RegistryType } from './types';
import { getContracts, getPoliciesMerkleTree } from './utils';

async function main() {
    const [deployer] = await ethers.getSigners();
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

    // add policy root
    {
        const merkleTree = await getPoliciesMerkleTree(network.config.chainId!);
        const tx = await nodeRegistry.setPoliciesRoot.populateTransaction(merkleTree.root);
        txs.push(tx);
    }

    // sepolia
    if (deployer.address.toLowerCase() === owner.toLowerCase()) {
        for (const tx of txs) {
            await deployer.sendTransaction(tx).then((t) => t.wait(1));
        }
    } else {
        // TODO: Safe propose tx
    }
}

main();
