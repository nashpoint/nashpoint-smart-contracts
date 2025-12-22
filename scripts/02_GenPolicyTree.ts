import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import fs from 'fs';
import { network } from 'hardhat';
import { Node__factory } from '../typechain-types';
import { Contracts, Policy } from './types';
import { chainIdToName, getContracts } from './utils';

const i = Node__factory.createInterface();

function s<T extends string, I extends { getFunction(name: T): { selector: string } }>(
    i: I,
    functions: readonly T[],
): string[] {
    return functions.map((f) => i.getFunction(f).selector);
}

const getPolicySigs = (policy: Policy) => {
    switch (policy) {
        case 'capPolicy':
            return s(i, ['deposit', 'mint']);
        case 'gatePolicyBlacklist':
            return s(i, [
                'deposit',
                'mint',
                'setOperator',
                'requestRedeem',
                'withdraw',
                'redeem',
                'transfer',
                'approve',
                'transferFrom',
            ]);
        case 'gatePolicyWhitelist':
            return s(i, [
                'deposit',
                'mint',
                'setOperator',
                'requestRedeem',
                'withdraw',
                'redeem',
                'transfer',
                'approve',
                'transferFrom',
            ]);
        case 'protocolPausingPolicy':
            return s(i, [
                'deposit',
                'mint',
                'withdraw',
                'redeem',
                'requestRedeem',
                'execute',
                'subtractProtocolExecutionFee',
                'fulfillRedeemFromReserve',
                'finalizeRedemption',
                'setOperator',
                'startRebalance',
                'payManagementFees',
                'updateTotalAssets',
                'transfer',
                'approve',
                'transferFrom',
            ]);
        case 'nodePausingPolicy':
            return s(i, [
                'deposit',
                'mint',
                'withdraw',
                'redeem',
                'requestRedeem',
                'execute',
                'subtractProtocolExecutionFee',
                'fulfillRedeemFromReserve',
                'finalizeRedemption',
                'setOperator',
                'startRebalance',
                'payManagementFees',
                'updateTotalAssets',
                'transfer',
                'approve',
                'transferFrom',
            ]);
        default:
            throw new Error('Not supported Policy');
    }
};

const buildLeafs = (
    data: {
        policy: string;
        sigs: string[];
    }[],
) => {
    const leafs: [string, string][] = [];
    data.forEach((p) => {
        p.sigs.forEach((s) => {
            leafs.push([s, p.policy]);
        });
    });
    return leafs;
};

const buildPolicy = (policy: Policy, contracts: Contracts) => {
    return { policy: contracts[policy], sigs: getPolicySigs(policy) };
};

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
        JSON.stringify(dump, null, 4) + '\n',
    );
}

main();
