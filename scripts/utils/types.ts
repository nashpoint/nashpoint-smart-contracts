import { NodeInterface } from './../../typechain-types/src/Node';

export type InterfaceFunctionName<I> = I extends {
    getFunction(nameOrSignature: infer Name): { selector: string };
}
    ? Extract<Name, string>
    : never;

export type NodeFunctionName = InterfaceFunctionName<NodeInterface>;

export type ComponentAllocation = {
    name: string;
    address: string;
    allocation: number | string;
    maxDelta?: number | string;
};

export type NodeData = {
    // defined once deployed
    address?: string;
    name: string;
    symbol: string;
    asset: string;
    owner: string;
    rebalancer?: string;
    salt?: string;
    components?: {
        erc7540Router?: ComponentAllocation[];
        erc4626Router?: ComponentAllocation[];
    };
    targetReserveRatio?: number | string;
    policies?: Policy[];
    whitelist?: string[];
    pauser?: string[];
    rebalanceCooldown?: number;
    rebalanceWindow?: number;
    nodeOwnerFeeAddress?: string;
    // decimal value
    nodeFee?: number;
    pauseFunctions?: NodeFunctionName[];
    // decimal value
    seedValue?: number;
};

export type Config = {
    protocolOwner: string;
    rebalancer: string[];
    components: {
        [k in Router]: [
            {
                name: string;
                address: string;
            },
        ];
    };
    usdc: string;
    usdcPriceOracle: string;
    iSNR: string;
    iSNRPriceOracle: string;
    CRDYX: string;
};

export type Contracts = {
    digift?: {
        adapterFactory: string;
        adapterImplementation: string;
        eventVerifier: string;
        wiSNR?: string;
    };

    routers: {
        erc4626Router: string;
        erc7540Router: string;
        oneInchRouter?: string;
    };

    policies: {
        capPolicy: string;
        gatePolicyBlacklist: string;
        gatePolicyWhitelist: string;
        protocolPausingPolicy: string;
        nodePausingPolicy: string;
    };

    nodeFactory: string;
    nodeImplementation: string;
    nodeRegistryImplementation: string;
    nodeRegistryProxy: string;
};

export type Router = 'erc4626Router' | 'erc7540Router' | 'oneInchRouter';

export type Policy =
    | 'capPolicy'
    | 'gatePolicyBlacklist'
    | 'gatePolicyWhitelist'
    | 'protocolPausingPolicy'
    | 'nodePausingPolicy';

export type Component = {
    address: string;
    targetWeight: number;
    maxDelta: number;
    router: Router;
};

export type NodeSetup = {
    name: string;
    symbol: string;
    owner: string;
    rebalancers: string[];
    routers: Router[];
    components: Component[];
    targetReserveRatio: number;
    policies: Policy[];
};

export enum RegistryType {
    UNUSED,
    NODE,
    FACTORY,
    ROUTER,
    REBALANCER,
}
