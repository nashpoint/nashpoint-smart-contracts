// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzStructs.sol";

/**
 * @title BeforeAfter
 * @notice Captures protocol and actor state before/after handler execution
 */
contract BeforeAfter is FuzzStructs {
    mapping(uint8 => State) internal states;

    function _before(address[] memory actors) internal {
        _setStates(0, actors);
    }

    function _before() internal {
        _before(USERS);
    }

    function _after(address[] memory actors) internal {
        _setStates(1, actors);
    }

    function _after() internal {
        _after(USERS);
    }

    function _setStates(uint8 callNum, address[] memory actors) internal {
        _captureActorState(callNum, actors);
        _captureGlobalState(callNum);
    }

    function _captureActorState(uint8 callNum, address[] memory actors) internal {
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            ActorState storage snapshot = states[callNum].actorStates[actor];

            snapshot.assetBalance = asset.balanceOf(actor);
            snapshot.shareBalance = node.balanceOf(actor);

            (
                uint256 pendingRedeemRequest,
                uint256 claimableRedeemRequest,
                uint256 claimableAssets, /* sharesAdjusted */
            ) = node.requests(actor);

            snapshot.pendingRedeem = pendingRedeemRequest;
            snapshot.claimableRedeem = claimableRedeemRequest;
            snapshot.claimableAssets = claimableAssets;
        }
    }

    function _captureGlobalState(uint8 callNum) internal {
        states[callNum].nodeAssetBalance = asset.balanceOf(address(node));
        states[callNum].nodeEscrowAssetBalance = asset.balanceOf(address(escrow));
        states[callNum].nodeTotalAssets = node.totalAssets();
        states[callNum].nodeTotalSupply = node.totalSupply();
        states[callNum].sharesExiting = node.sharesExiting();
        states[callNum].nodeEscrowShareBalance = node.balanceOf(address(escrow)); //@audit added this
    }
}
