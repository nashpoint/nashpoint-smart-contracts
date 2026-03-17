import { ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import { DigiftAdapterFactory__factory, NodeRegistry__factory } from '../typechain-types';
import { safePropose } from './utils/SafeService';
import { getConfig, getContracts } from './utils/utils';

async function main() {
    const [deployer] = await ethers.getSigners();
    const config = await getConfig(network.config.chainId!);
    const contracts = await getContracts(network.config.chainId!);

    const txs: ContractTransaction[] = [];

    const nodeRegistry = NodeRegistry__factory.connect(contracts.nodeRegistryProxy, deployer);
    const owner = await nodeRegistry.owner();

    if (!contracts.digift) {
        throw new Error('Digift Adapter Factory is not deployed');
    }

    const digiftAdapterFactory = DigiftAdapterFactory__factory.connect(
        contracts.digift.adapterFactory,
        deployer,
    );

    {
        const tx = await digiftAdapterFactory.deploy.populateTransaction({
            name: 'iSNR Wrapper',
            symbol: 'wiSNR',
            asset: config.usdc,
            assetPriceOracle: config.usdcPriceOracle,
            fund: config.iSNR,
            fundPriceOracle: config.iSNRPriceOracle,
            priceDeviation: ethers.parseEther('0.01'), // 1%
            settlementDeviation: ethers.parseEther('0.01'), // 1%
            priceUpdateDeviationFund: 3 * 24 * 60 * 60, // 3 days
            priceUpdateDeviationAsset: 1 * 24 * 60 * 60, // 1 day
            minDepositAmount: ethers.parseUnits('10000', 6),
            minRedeemAmount: ethers.parseEther('1'),
            customInitData: '0x',
        });
        txs.push(tx);
    }

    if (deployer.address.toLowerCase() === owner.toLowerCase()) {
        console.log(`${txs.length} txs to send`);
        for (let i = 0; i < txs.length; i++) {
            await deployer.sendTransaction(txs[i]).then((t) => t.wait(1));
            console.log(`Sent ${i + 1}`);
        }
    } else {
        await safePropose(owner, txs);
    }
}

main();
