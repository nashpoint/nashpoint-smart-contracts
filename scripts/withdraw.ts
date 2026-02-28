import { ethers } from 'hardhat';
import nodeData from '../deployments/nodes/arbitrum/Demo.json';
import { Node__factory } from '../typechain-types';
import { getGasFee } from './utils/utils';

async function main() {
    const [deployer] = await ethers.getSigners();
    const node = Node__factory.connect(nodeData.address, deployer);
    const assets = await node.maxWithdraw(deployer.address);
    await node.withdraw(assets, deployer.address, deployer.address).then((tx) => tx.wait(4));
}

main();
