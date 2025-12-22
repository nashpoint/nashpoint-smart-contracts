import path from 'path';
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';

import { Config, Contracts } from './types';

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
