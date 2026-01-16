import { ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import {
    ERC4626Router__factory,
    ERC7540Router__factory,
    NodeRegistry__factory,
} from '../typechain-types';
import { getConfig, getContracts } from './utils/utils';
import { safePropose } from './utils/SafeService';

async function main() {
    const [deployer] = await ethers.getSigners();
    const config = await getConfig(network.config.chainId!);
    const contracts = await getContracts(network.config.chainId!);

    const txs: ContractTransaction[] = [];

    const nodeRegistry = NodeRegistry__factory.connect(contracts.nodeRegistryProxy, deployer);
    const erc4626Router = ERC4626Router__factory.connect(contracts.routers.erc4626Router, deployer);
    const erc7540Router = ERC7540Router__factory.connect(contracts.routers.erc7540Router, deployer);

    const owner = await nodeRegistry.owner();

    // whitelisting erc4626 components
    for (const component of config.components.erc4626Router) {
        const blacklisted = await erc4626Router.isBlacklisted(component.address);
        const whitelisted = await erc4626Router.isWhitelisted(component.address);
        if (blacklisted || whitelisted) continue;
        const tx = await erc4626Router.setWhitelistStatus.populateTransaction(
            component.address,
            true,
        );
        console.log(`${component.name} will be whitelisted on erc4626Router`);
        txs.push(tx);
    }

    // whitelisting erc7540 components
    for (const component of config.components.erc7540Router) {
        const blacklisted = await erc7540Router.isBlacklisted(component.address);
        const whitelisted = await erc7540Router.isWhitelisted(component.address);
        if (blacklisted || whitelisted) continue;
        const tx = await erc7540Router.setWhitelistStatus.populateTransaction(
            component.address,
            true,
        );
        console.log(`${component.name} will be whitelisted on erc7540Router`);
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
        await safePropose(owner, txs);
    }
}

main();
