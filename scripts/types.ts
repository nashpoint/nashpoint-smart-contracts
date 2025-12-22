export type Contracts = {
    digiftAdapterFactory?: string;
    digiftAdapterImplementation?: string;
    digiftEventVerifier?: string;

    erc4626Router: string;
    erc7540Router: string;
    oneInchRouter?: string;

    capPolicy: string;
    gatePolicyBlacklist: string;
    gatePolicyWhitelist: string;
    protocolPausingPolicy: string;
    nodePausingPolicy: string;

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
