import { network } from 'hardhat';

import SafeApiKit from '@safe-global/api-kit';
import Safe from '@safe-global/protocol-kit';
// TODO: https://github.com/safe-global/safe-core-sdk/issues/1247
// import { decodeMultiSendData } from '@safe-global/protocol-kit';
import { MetaTransactionData, SafeMultisigTransactionResponse } from '@safe-global/types-kit';
import { ContractTransaction, Wallet } from 'ethers';

export class SafeService {
    private signer: Wallet;
    private apiKit: SafeApiKit;
    private protocolKit = new Safe();

    constructor(
        public safeAddress: string,
        public safeOrigin: string,
        safeApiKey: string,
        public providerUrl: string,
        public chainId: number,
        private delegatePrivateKey: string,
    ) {
        this.signer = new Wallet(this.delegatePrivateKey);
        this.apiKit = new SafeApiKit({ chainId: BigInt(chainId), apiKey: safeApiKey });
    }

    async initialize() {
        this.protocolKit = await Safe.init({
            provider: this.providerUrl,
            safeAddress: this.safeAddress,
            signer: this.signer.privateKey,
        });
    }

    async getPendingSafeTransactions(): Promise<SafeMultisigTransactionResponse[]> {
        const pendingTxs = await this.apiKit.getPendingTransactions(this.safeAddress);
        return pendingTxs.results;
    }

    // TODO: if Safe exposes decodeMultiSendData we can use it.
    // if not - we'll implement it on our own
    // async getProposedTransaction(nonce: number): Promise<MetaTransactionData[] | undefined> {
    //     const pendingTxs = await this.getPendingSafeTransactions();
    //     const tx = pendingTxs.find((tx) => tx.nonce === String(nonce));
    //     if (tx?.data) {
    //         return decodeMultiSendData(tx.data);
    //     }
    // }

    async propose(transactions: MetaTransactionData[], nonce?: number): Promise<string> {
        const transactionNonce = nonce
            ? nonce
            : await this.apiKit.getNextNonce(this.safeAddress).then(Number);

        const safeTx = await this.protocolKit.createTransaction({
            transactions,
            options: {
                nonce: transactionNonce,
            },
            onlyCalls: true,
        });
        safeTx.data.value = '0';
        const safeTxHash = await this.protocolKit.getTransactionHash(safeTx);
        const signature = await this.protocolKit.signHash(safeTxHash);

        await this.apiKit.proposeTransaction({
            safeAddress: this.safeAddress,
            safeTransactionData: safeTx.data,
            safeTxHash,
            senderAddress: this.signer.address,
            senderSignature: signature.data,
            origin: this.safeOrigin,
        });

        return safeTxHash;
    }
}

export const safePropose = async (safeAddress: string, txs: ContractTransaction[]) => {
    const safe = new SafeService(
        safeAddress,
        process.env.SAFE_ORIGIN!,
        process.env.SAFE_API_KEY!,
        // @ts-ignore
        network.config.url,
        network.config.chainId!,
        process.env.SAFE_DELEGATE_PRIVATE_KEY!,
    );
    await safe.initialize();
    if (txs.length) {
        const safeTxHash = await safe.propose(
            txs.map((tx) => ({ data: tx.data, to: tx.to, value: '' })),
        );
        console.log(`Proposed: ${safeTxHash}`);
    }
};
