import { ethers, network } from 'hardhat';
import {
    ERC20__factory,
    GatePolicyWhitelist__factory,
    IERC20PermitHardhat__factory,
    Node__factory,
    NodeFactory__factory,
    NodePausingPolicy__factory,
} from '../typechain-types';
import { SetupCallStruct } from '../typechain-types/src/NodeFactory';
import { signPermit } from './utils/permit';
import {
    buildLeafs,
    buildPolicy,
    decodeError,
    functionNamesToSignatures,
    getContracts,
    getNodeData,
    getPoliciesMerkleTree,
    percentToWei,
    weiToPercent,
    writeNodeData,
} from './utils/utils';

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

    const decimals = await ERC20__factory.connect(nodeData.asset, ethers.provider).decimals();
    if (nodeData.seedValue) {
        const { payload, signature } = await signPermit(
            deployer,
            contracts.nodeFactory,
            nodeData.asset,
            ethers.parseUnits(nodeData.seedValue.toString(), decimals),
        );
        const { owner, spender, value, deadline } = payload;
        setupCalls.push({
            target: nodeData.asset,
            payload: IERC20PermitHardhat__factory.createInterface().encodeFunctionData(
                'permit(address,address,uint256,uint256,bytes)',
                [owner, spender, value, deadline, signature],
            ),
        });

        setupCalls.push({
            target: nodeData.asset,
            payload: ERC20__factory.createInterface().encodeFunctionData('transferFrom', [
                owner,
                contracts.nodeFactory,
                value,
            ]),
        });

        setupCalls.push({
            target: nodeData.asset,
            payload: ERC20__factory.createInterface().encodeFunctionData('approve', [
                nodeAddressPredicted,
                value,
            ]),
        });

        // TODO: receiver might be configurable
        nodePayload.push(node.encodeFunctionData('deposit', [value, deployer.address]));
    }

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
    if (nodeData.nodeOwnerFeeAddress) {
        nodePayload.push(
            node.encodeFunctionData('setNodeOwnerFeeAddress', [nodeData.nodeOwnerFeeAddress]),
        );
    }
    if (nodeData.nodeFee) {
        nodePayload.push(
            node.encodeFunctionData('setAnnualManagementFee', [
                ethers.parseEther(String(nodeData.nodeFee)) / 100n,
            ]),
        );
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
            payload: NodePausingPolicy__factory.createInterface().encodeFunctionData('add', [
                nodeAddressPredicted,
                nodeData.pauser,
            ]),
        });
    }
    if (nodeData.pauseFunctions) {
        // whitelist nodeFactory for one tx
        setupCalls.push({
            target: contracts.policies.nodePausingPolicy,
            payload: NodePausingPolicy__factory.createInterface().encodeFunctionData('add', [
                nodeAddressPredicted,
                [contracts.nodeFactory],
            ]),
        });
        // pause functions
        setupCalls.push({
            target: contracts.policies.nodePausingPolicy,
            payload: NodePausingPolicy__factory.createInterface().encodeFunctionData('pauseSigs', [
                nodeAddressPredicted,
                functionNamesToSignatures(nodeData.pauseFunctions),
            ]),
        });
        // de-whitelist nodeFactory after pausing
        setupCalls.push({
            target: contracts.policies.nodePausingPolicy,
            payload: NodePausingPolicy__factory.createInterface().encodeFunctionData('remove', [
                nodeAddressPredicted,
                [contracts.nodeFactory],
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
        decodeError(error);
    }
}

main();
