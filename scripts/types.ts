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
};

export type Config = {
    rebalancer: string[];
    components: {
        [k in Router]: [
            {
                name: string;
                address: string;
            },
        ];
    };
};

export type Contracts = {
    digift?: {
        adapterFactory: string;
        adapterImplementation: string;
        eventVerifier: string;
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
