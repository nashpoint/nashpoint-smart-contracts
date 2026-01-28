import { ethers } from 'hardhat';
import nodeData from '../deployments/nodes/arbitrum/Demo.json';
import { Node__factory } from '../typechain-types';

async function main() {
    const [deployer] = await ethers.getSigners();
    const node = Node__factory.connect(nodeData.address, deployer);
    try {
        await node.fulfillRedeemFromReserve(deployer.address).then((tx) => tx.wait(4));
    } catch (error) {
        await node.startRebalance().then((tx) => tx.wait(4));
        await node.fulfillRedeemFromReserve(deployer.address).then((tx) => tx.wait(4));
    }
}

main();
