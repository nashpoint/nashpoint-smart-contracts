import dotenv from 'dotenv';
dotenv.config();
//
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-toolbox';
import { HardhatUserConfig } from 'hardhat/config';

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.28',
        settings: {
            evmVersion: 'cancun',
            optimizer: {
                enabled: true,
                runs: 1000,
            },
        },
    },
    networks: {
        arbitrum: {
            chainId: 42161,
            url: process.env.ARBITRUM_RPC_URL!,
            accounts: [process.env.ARBITRUM_PRIVATE_KEY!],
        },
        sepolia: {
            chainId: 11155111,
            url: process.env.SEPOLIA_RPC_URL!,
            accounts: [process.env.SEPOLIA_PRIVATE_KEY!],
        },
        local: {
            url: process.env.LOCAL_RPC_URL!,
            accounts: [process.env.LOCAL_PRIVATE_KEY!],
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY!,
    },
    sourcify: {
        enabled: false,
    },
};

export default config;
