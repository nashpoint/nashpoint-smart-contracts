// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

import {IIncentraDistributor} from "../../../../src/interfaces/external/IIncentraDistributor.sol";

contract PreconditionsRewardRouters is PreconditionsBase {
    function fluidClaimPreconditions(uint256 positionIdSeed, uint256 cycleSeed, uint256 amountSeed)
        internal
        returns (FluidClaimParams memory params)
    {
        positionIdSeed;

        params.cumulativeAmount = fl.clamp(amountSeed, 0, 1_000_000e6);
        params.positionId = keccak256(abi.encodePacked(address(node), cycleSeed, iteration));
        params.cycle = fl.clamp(cycleSeed + 1, 1, 64);

        params.merkleProof = new bytes32[](1);
        params.merkleProof[0] = keccak256(abi.encodePacked(params.positionId, params.cycle));

        params.proofHash = keccak256(abi.encode(params.merkleProof));

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("FLUID_CALLER", positionIdSeed, cycleSeed) % 17 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;
    }

    function incentraClaimPreconditions(uint256 campaignSeed, uint256 amountSeed)
        internal
        returns (IncentraClaimParams memory params)
    {
        params.campaignAddrs = new address[](1);
        params.campaignAddrs[0] = address(uint160(uint256(keccak256(abi.encodePacked(campaignSeed, address(node))))));

        params.rewards = new IIncentraDistributor.CampaignReward[](1);
        params.rewards[0].campaignAddr = params.campaignAddrs[0];
        params.rewards[0].cumulativeAmounts = new uint256[](1);
        params.rewards[0].cumulativeAmounts[0] = fl.clamp(amountSeed, 0, 100_000e6);
        params.rewards[0].epoch = uint64((campaignSeed % 100) + 1);
        params.rewards[0].proof = new bytes32[](1);
        params.rewards[0].proof[0] =
            keccak256(abi.encodePacked(params.rewards[0].campaignAddr, params.rewards[0].epoch));

        params.campaignAddrsHash = keccak256(abi.encode(params.campaignAddrs));
        params.rewardsHash = keccak256(abi.encode(params.rewards));

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("INCENTRA_CALLER", campaignSeed, amountSeed) % 17 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;
    }

    function merklClaimPreconditions(uint256 amountSeed) internal returns (MerklClaimParams memory params) {
        params.tokens = new address[](1);
        params.tokens[0] = address(asset);

        params.amounts = new uint256[](1);
        params.amounts[0] = fl.clamp(amountSeed, 0, 100_000 ether);

        params.proofs = new bytes32[][](1);
        params.proofs[0] = new bytes32[](1);
        params.proofs[0][0] = keccak256(abi.encodePacked(params.tokens[0], params.amounts[0]));

        address[] memory users = new address[](params.tokens.length);
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = address(node);
        }

        params.usersHash = keccak256(abi.encode(users));
        params.tokensHash = keccak256(abi.encode(params.tokens));
        params.amountsHash = keccak256(abi.encode(params.amounts));
        params.proofsHash = keccak256(abi.encode(params.proofs));

        if (_hasPreferredAdminActor) {
            params.caller = _preferredAdminActor;
            _preferredAdminActor = address(0);
            _hasPreferredAdminActor = false;
            params.shouldSucceed = params.caller == rebalancer;
            return params;
        }

        bool authorized = _rand("MERKL_CALLER", amountSeed) % 17 != 0;
        params.caller = authorized ? rebalancer : randomUser;
        params.shouldSucceed = authorized;
    }
}
