import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import fs from 'fs';
import { network } from 'hardhat';
import { Policy } from './utils/types';
import { buildLeafs, buildPolicy, chainIdToName, getContracts } from './utils/utils';

async function main() {
    const contracts = await getContracts(network.config.chainId!);
    const policies: Policy[] = [
        'capPolicy',
        'gatePolicyBlacklist',
        'gatePolicyWhitelist',
        'nodePausingPolicy',
        'protocolPausingPolicy',
    ];
    const tree = StandardMerkleTree.of(buildLeafs(policies.map((p) => buildPolicy(p, contracts))), [
        'bytes4',
        'address',
    ]);
    const dump = tree.dump();
    fs.writeFileSync(
        `./policy/${chainIdToName(network.config.chainId!)}.json`,
        JSON.stringify(dump, null, 2) + '\n',
    );
}

main();
