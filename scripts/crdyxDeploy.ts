import { ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import config from '../config/arbitrum.json';
import contracts from '../deployments/arbitrum.json';
import { WTAdapterFactory__factory } from '../typechain-types';
import { safePropose } from './utils/SafeService';

async function main() {
    if (network.config.chainId !== 42161) {
        throw new Error('Only Arbitrum');
    }

    const txs: ContractTransaction[] = [];

    if (!contracts.wt) {
        throw new Error('WT Adapter Factory is not deployed');
    }

    const wtAdapterFactory = WTAdapterFactory__factory.connect(
        contracts.wt.adapterFactory,
        ethers.provider,
    );

    {
        const tx = await wtAdapterFactory.deploy.populateTransaction({
            name: 'CRDYX Wrapper',
            symbol: 'wCRDYX',
            asset: config.usdc,
            assetPriceOracle: config.usdcPriceOracle,
            fund: config.CRDYX,
            fundPriceOracle: contracts.wt.crdyxPriceOracle,
            priceDeviation: ethers.parseEther('0.01'), // 1%
            settlementDeviation: ethers.parseEther('0.01'), // 1%
            priceUpdateDeviationFund: 3 * 24 * 60 * 60, // 3 days
            priceUpdateDeviationAsset: 1 * 24 * 60 * 60, // 1 day
            minDepositAmount: ethers.parseUnits('10', 6),
            minRedeemAmount: ethers.parseEther('1'),
            customInitData: ethers.AbiCoder.defaultAbiCoder().encode(
                ['address', 'address'],
                [
                    // receiver address
                    '0xc24d277EEdc174b764C822a6965740f8C22CF95A',
                    // sender address
                    '0x463f5d63e5a5edb8615b0e485a090a18aba08578',
                ],
            ),
        });
        txs.push(tx);
    }

    await safePropose(config.protocolOwner, txs);
}

main();
