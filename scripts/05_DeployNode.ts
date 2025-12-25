import { ethers, network } from 'hardhat';
import {
    ErrorsLib__factory,
    GatePolicyWhitelist__factory,
    Node__factory,
    NodeFactory__factory,
} from '../typechain-types';
import {
    buildLeafs,
    buildPolicy,
    getContracts,
    getNodeData,
    getPoliciesMerkleTree,
    percentToWei,
    weiToPercent,
    writeNodeData,
} from './utils';
import { SetupCallStruct } from '../typechain-types/src/NodeFactory';

async function main() {
    const fileName = process.env.FILE;
    if (!fileName) {
        console.error('Please provide FILE name');
        return;
    }
    const [deployer] = await ethers.getSigners();
    const contracts = await getContracts(network.config.chainId!);
    const nodeData = await getNodeData(network.config.chainId!, fileName);
    const policyTree = await getPoliciesMerkleTree(network.config.chainId!);

    if (nodeData.address) {
        console.log(`Node is already deployed at ${nodeData.address}`);
        return;
    }

    const node = Node__factory.createInterface();
    const nodeFactory = NodeFactory__factory.connect(contracts.nodeFactory, deployer);

    const nodePayload = [];
    const setupCalls: SetupCallStruct[] = [];
    let totalAllocation = 0n;
    const salt =
        nodeData.salt ||
        ethers.keccak256(
            ethers.toUtf8Bytes(`${nodeData.name}-${nodeData.symbol}-${nodeData.asset}`),
        );
    const nodeAddressPredicted = await nodeFactory.predictDeterministicAddress(
        salt,
        deployer.address,
    );

    if (nodeData.rebalancer) {
        for (const r of nodeData.rebalancer) {
            nodePayload.push(node.encodeFunctionData('addRebalancer', [r]));
        }
    }
    if (nodeData.rebalanceCooldown) {
        nodePayload.push(
            node.encodeFunctionData('setRebalanceCooldown', [nodeData.rebalanceCooldown]),
        );
    }
    if (nodeData.rebalanceWindow) {
        nodePayload.push(node.encodeFunctionData('setRebalanceWindow', [nodeData.rebalanceWindow]));
    }
    if (nodeData.policies) {
        const policiesToUse = nodeData.policies.map((p) => buildPolicy(p, contracts));
        const multiProof = policyTree.getMultiProof(buildLeafs(policiesToUse));
        const sigs = multiProof.leaves.map(([s, _]) => s);
        const policies = multiProof.leaves.map(([_, p]) => p);
        nodePayload.push(
            node.encodeFunctionData('addPolicies', [
                multiProof.proof,
                multiProof.proofFlags,
                sigs,
                policies,
            ]),
        );
    }
    if (nodeData.whitelist) {
        setupCalls.push({
            target: contracts.policies.gatePolicyWhitelist,
            payload: GatePolicyWhitelist__factory.createInterface().encodeFunctionData('add', [
                nodeAddressPredicted,
                nodeData.whitelist,
            ]),
        });
    }
    if (nodeData.pauser) {
        setupCalls.push({
            target: contracts.policies.nodePausingPolicy,
            payload: GatePolicyWhitelist__factory.createInterface().encodeFunctionData('add', [
                nodeAddressPredicted,
                nodeData.pauser,
            ]),
        });
    }
    if (nodeData.targetReserveRatio) {
        const targetReserveRatio = percentToWei(nodeData.targetReserveRatio);
        totalAllocation += targetReserveRatio;
        nodePayload.push(node.encodeFunctionData('updateTargetReserveRatio', [targetReserveRatio]));
    }
    if (nodeData.components) {
        if (nodeData.components.erc4626Router?.length) {
            nodePayload.push(
                node.encodeFunctionData('addRouter', [contracts.routers.erc4626Router]),
            );
            for (const component of nodeData.components.erc4626Router) {
                const allocation = percentToWei(component.allocation);
                totalAllocation += allocation;
                nodePayload.push(
                    node.encodeFunctionData('addComponent', [
                        component.address,
                        allocation,
                        component.maxDelta ? percentToWei(component.maxDelta) : 0,
                        contracts.routers.erc4626Router,
                    ]),
                );
            }
        }
        if (nodeData.components.erc7540Router?.length) {
            nodePayload.push(
                node.encodeFunctionData('addRouter', [contracts.routers.erc7540Router]),
            );
            for (const component of nodeData.components.erc7540Router) {
                const allocation = percentToWei(component.allocation);
                totalAllocation += allocation;
                nodePayload.push(
                    node.encodeFunctionData('addComponent', [
                        component.address,
                        allocation,
                        component.maxDelta ? percentToWei(component.maxDelta) : 0,
                        contracts.routers.erc7540Router,
                    ]),
                );
            }
        }
    }

    if (totalAllocation != 0n && totalAllocation != ethers.parseEther('1')) {
        throw new Error(
            `Allocation doesn't match. ${weiToPercent(totalAllocation)}. Expected 0 or 100`,
        );
    }

    try {
        const tx = await nodeFactory.deployFullNode(
            {
                name: nodeData.name,
                symbol: nodeData.symbol,
                asset: nodeData.asset,
                owner: nodeData.owner,
            },
            nodePayload,
            setupCalls,
            salt,
        );

        const receipt = await tx.wait(1);

        if (receipt) {
            const logs = await nodeFactory.queryFilter(
                nodeFactory.filters['NodeCreated'](
                    undefined,
                    nodeData.asset,
                    undefined,
                    undefined,
                    nodeData.owner,
                ),
                receipt.blockNumber,
                receipt.blockNumber,
            );
            if (logs.length !== 1) {
                throw new Error('Something is wrong with log query');
            }
            nodeData.address = logs[0].args.node;
            writeNodeData(network.config.chainId!, fileName, nodeData);
            console.log(`Node is deployed at ${nodeData.address}`);
        }
    } catch (error) {
        const interfaces = [
            NodeFactory__factory.createInterface(),
            Node__factory.createInterface(),
            ErrorsLib__factory.createInterface(),
        ];
        let decoded = false;
        for (const i of interfaces) {
            try {
                // @ts-ignore
                console.log(i.parseError(error.data));
                decoded = true;
                break;
            } catch (error) {}
        }
        if (!decoded) {
            console.log(error);
        }
    }
}

main();
