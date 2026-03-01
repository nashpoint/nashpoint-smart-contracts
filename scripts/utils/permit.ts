import { ethers } from 'ethers';
import { IERC20PermitHardhat__factory } from '../../typechain-types';

// TODO: hardcoded USDC on arbitrum
export const PERMIT_TYPEHASH =
    '0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9 ';

export const DOMAIN = {
    chainId: 42161,
    name: 'USD Coin',
    version: '2',
    verifyingContract: '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
};

export const TYPES = {
    Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
    ],
};

export async function signPermit(
    signer: ethers.Signer,
    spender: string,
    assetAddress: string,
    value: bigint,
) {
    const deadline = Math.floor(Date.now() / 1000) + 60;

    const owner = await signer.getAddress();
    const nonce = await IERC20PermitHardhat__factory.connect(assetAddress, signer).nonces(owner);

    const payload = {
        owner,
        spender,
        value: value.toString(),
        nonce: nonce.toString(),
        deadline,
    };

    const signature = await signer.signTypedData(DOMAIN, TYPES, payload);

    const address = ethers.verifyTypedData(DOMAIN, TYPES, payload, signature);

    if (address !== owner) {
        throw new Error('Failed to generate permit signature');
    }

    const { r, s, v } = ethers.Signature.from(signature);

    return {
        payload,
        signature,
        r,
        s,
        v,
    };
}
