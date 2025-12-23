import { network } from 'hardhat';
import { getContracts } from './utils';

async function main() {
    const contracts = await getContracts(network.config.chainId!);
}

main();
