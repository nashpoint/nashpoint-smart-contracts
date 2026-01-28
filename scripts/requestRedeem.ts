import { ethers } from 'hardhat';
import nodeData from '../deployments/nodes/arbitrum/Demo.json';
import { Node__factory } from '../typechain-types';
import { getGasFee } from './utils/utils';

async function main() {
    const [deployer] = await ethers.getSigners();
    const node = Node__factory.connect(nodeData.address, deployer);
    const shares = await node.balanceOf(deployer.address);
    await node.requestRedeem(shares, deployer.address, deployer.address).then((tx) => tx.wait(4));
}

main();
