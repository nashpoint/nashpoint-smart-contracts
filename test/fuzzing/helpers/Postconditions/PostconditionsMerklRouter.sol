// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {MerklDistributorMock} from "../../../mocks/MerklDistributorMock.sol";

contract PostconditionsMerklRouter is PostconditionsBase {
    function merklClaimPostconditions(bool success, bytes memory returnData, MerklClaimParams memory params) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "MERKL_CLAIM_SUCCESS");

            MerklDistributorMock mock = MerklDistributorMock(address(merklDistributor));

            address[] memory recordedUsers = mock.getLastUsers();
            // fl.t(recordedUsers.length == params.tokens.length, "MERKL_USERS_LEN");
            for (uint256 i = 0; i < recordedUsers.length; i++) {
                // fl.t(recordedUsers[i] == address(node), "MERKL_USER_ADDR");
            }
            address[] memory recordedTokens = mock.getLastTokens();
            uint256[] memory recordedAmounts = mock.getLastAmounts();

            // fl.t(keccak256(abi.encode(recordedTokens)) == params.tokensHash, "MERKL_TOKENS_HASH");
            // fl.t(keccak256(abi.encode(recordedAmounts)) == params.amountsHash, "MERKL_AMOUNTS_HASH");
            // fl.t(mock.lastProofsHash() == params.proofsHash, "MERKL_PROOFS_HASH");

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "MERKL_CLAIM_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }
}
