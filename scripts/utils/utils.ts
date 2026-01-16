import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import fs from 'fs';
import path from 'path';

import type { Provider } from 'ethers';
import { ethers } from 'hardhat';
import { Node__factory } from '../../typechain-types';
import { Config, Contracts, NodeData, Policy } from './types';

export const chainIdToName = (chainId: number) => {
    switch (chainId) {
        case 42161:
            return 'arbitrum';
        case 11155111:
            return 'sepolia';
        default:
            throw new Error(`${chainId} not supported`);
    }
};

export const getContracts = async (chainId: number): Promise<Contracts> => {
    return import(
        path.resolve(process.cwd(), 'deployments', `${chainIdToName(chainId)}.json`)
    ).then((f) => f.default);
};

export const getConfig = async (chainId: number): Promise<Config> => {
    return import(path.resolve(process.cwd(), 'config', `${chainIdToName(chainId)}.json`)).then(
        (f) => f.default,
    );
};

export const getPoliciesMerkleTree = async (
    chainId: number,
): Promise<StandardMerkleTree<[string, string]>> => {
    const data = await import(
        path.resolve(process.cwd(), 'policy', `${chainIdToName(chainId)}.json`)
    ).then((f) => f.default);
    return StandardMerkleTree.load(data);
};

export const getNodeData = async (chainId: number, nodeFile: string): Promise<NodeData> => {
    return import(
        path.resolve(
            process.cwd(),
            'deployments',
            'nodes',
            chainIdToName(chainId),
            `${nodeFile}.json`,
        )
    ).then((f) => f.default);
};

export const writeNodeData = (chainId: number, nodeFile: string, nodeData: NodeData) => {
    fs.writeFileSync(
        path.resolve(
            process.cwd(),
            'deployments',
            'nodes',
            chainIdToName(chainId),
            `${nodeFile}.json`,
        ),
        JSON.stringify(nodeData, null, 2) + '\n',
    );
};

const i = Node__factory.createInterface();

function s<T extends string, I extends { getFunction(name: T): { selector: string } }>(
    i: I,
    functions: readonly T[],
): string[] {
    return functions.map((f) => i.getFunction(f).selector);
}

export const getPolicySigs = (policy: Policy) => {
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

export const buildLeafs = (
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

export const buildPolicy = (policy: Policy, contracts: Contracts) => {
    return { policy: contracts.policies[policy], sigs: getPolicySigs(policy) };
};

export const percentToWei = (value: string | number) => ethers.parseEther(value.toString()) / 100n;
export const weiToPercent = (value: bigint) => ethers.formatEther(value * 100n);

export const getGasFee = async (provider: Provider, percentIncrease = 20) => {
    const feeData = await provider.getFeeData();
    const result: Record<string, bigint> = {};

    const multiplier = 100n + BigInt(percentIncrease);

    if (feeData.maxFeePerGas) {
        result.maxFeePerGas = (feeData.maxFeePerGas * multiplier) / 100n;
    }
    if (feeData.maxPriorityFeePerGas) {
        result.maxPriorityFeePerGas = (feeData.maxPriorityFeePerGas * multiplier) / 100n;
    }
    if (!result.maxFeePerGas && feeData.gasPrice) {
        result.gasPrice = (feeData.gasPrice * multiplier) / 100n;
    }
    return result;
};
