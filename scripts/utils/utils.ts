import { ProtocolPausingPolicy__factory } from './../../typechain-types/factories/src/policies/ProtocolPausingPolicy__factory';
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import fs from 'fs';
import path from 'path';

import type { Provider } from 'ethers';
import { ethers } from 'hardhat';
import {
    CapPolicy__factory,
    ErrorsLib__factory,
    GatePolicyBlacklist__factory,
    GatePolicyWhitelist__factory,
    Node__factory,
    NodeFactory__factory,
    NodePausingPolicy__factory,
} from '../../typechain-types';
import { Config, Contracts, NodeData, NodeFunctionName, Policy } from './types';

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

export const functionNamesToSignatures = (functionNames: readonly NodeFunctionName[]) => {
    return functionNames.map((f) => {
        const fun = i.getFunction(f);
        if (!fun) {
            throw new Error(`None valid Node function: ${f}`);
        }
        return fun.selector;
    });
};

export const getPolicySigs = (policy: Policy) => {
    switch (policy) {
        case 'capPolicy':
            return functionNamesToSignatures(['deposit', 'mint']);
        case 'gatePolicyBlacklist':
            return functionNamesToSignatures([
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
            return functionNamesToSignatures([
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
            return functionNamesToSignatures([
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
            return functionNamesToSignatures([
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

const interfaces = [
    NodeFactory__factory.createInterface(),
    Node__factory.createInterface(),
    ErrorsLib__factory.createInterface(),
    NodePausingPolicy__factory.createInterface(),
    ProtocolPausingPolicy__factory.createInterface(),
    CapPolicy__factory.createInterface(),
    GatePolicyWhitelist__factory.createInterface(),
    GatePolicyBlacklist__factory.createInterface(),
];

export const decodeError = (error: unknown) => {
    let decoded = false;
    for (const i of interfaces) {
        try {
            // @ts-ignore
            const parsedError = i.parseError(error.data);
            if (parsedError) {
                console.log(parsedError);
                decoded = true;
                break;
            }
        } catch (error) {}
    }
    if (!decoded) {
        console.log(error);
    }
};
