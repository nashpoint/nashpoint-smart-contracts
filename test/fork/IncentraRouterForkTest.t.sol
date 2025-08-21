// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {IncentraRouter} from "src/routers/IncentraRouter.sol";
import {INode} from "src/interfaces/INode.sol";
import {IIncentraDistributor} from "src/interfaces/external/IIncentraDistributor.sol";
import {INodeRegistry, RegistryType} from "src/interfaces/INodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract IncentraRouterForkTest is Test {
    INodeRegistry registry;
    address protocolOwner = 0x69C2d63BC4Fcd16CD616D22089B58de3796E1F5c;
    address nodeOwner = 0x8d1A519326724b18A6F5877a082aae19394D0f67;
    address rebalancer = nodeOwner;

    uint256 blockNumber = 370668636;
    address incentraDistributor = 0x273d0d19eaC2861FCF6B21893AD6d71b018E25aB;

    INode node = INode(0x6ca200319A0D4127a7a473d6891B86f34e312F42);

    // rEUL
    IERC20Metadata reward = IERC20Metadata(0xFA31599a4928c2d57C0dd77DFCA5DA1E94E6D2D2);

    address randomUser = address(0x1234);

    bytes32[] proof;

    IncentraRouter incentraRouter;

    address campaignAddress = 0x46288043b6EFE7E699253F58E36537EBc823bbc5;
    uint256[] cumulativeRewards = [648469353291079793];
    uint64 epoch = 153;

    function setUp() external {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        vm.createSelectFork(ARBITRUM_RPC_URL, blockNumber);

        registry = INodeRegistry(node.registry());

        incentraRouter = new IncentraRouter(address(registry), incentraDistributor);

        proof = new bytes32[](9);
        proof[0] = 0xd7127f2501e23019cfc806f26447398c49f7ef6e64e01a6fe515b176302ba571;
        proof[1] = 0xf42ca84d41b4fc83ee7eb4cdf9d1e9032f9a9083f1e9d1074cc34f36a273baf8;
        proof[2] = 0xa62355a17bf54783aaeae0fc9f828ec46b6f76861d088da1f2e0b0a1084edcf5;
        proof[3] = 0x6c445616c3ba636916b22eee21c827d32dca4b24455aa2268c8f257b889a1e3e;
        proof[4] = 0x2ac6659f90a6d9491344c43b2442e2d9129f24aa9e453c46c88bbf3cc90fdce0;
        proof[5] = 0xe7b21a79a246bf3d795997220fd88ca4f62d940774987521b5f7ad5128f2225b;
        proof[6] = 0x27b6b3c17187e0a463109622e9dbbfde920a49deaf9a3206a0d48afbc9c1d398;
        proof[7] = 0x0bc564b886e47f3fc560f27c394e2ca09b1e1bd8bb77af624e0b713378b576c8;
        proof[8] = 0x6289999afa8f4107a986945a295b7945c2456f5d402be39363957a2397bf49bf;
    }

    function _payload() internal view returns (IIncentraDistributor.CampaignReward[] memory) {
        IIncentraDistributor.CampaignReward[] memory campaignRewards = new IIncentraDistributor.CampaignReward[](1);
        campaignRewards[0] = IIncentraDistributor.CampaignReward({
            campaignAddr: campaignAddress,
            cumulativeAmounts: cumulativeRewards,
            epoch: epoch,
            proof: proof
        });
        return campaignRewards;
    }

    function test_revert_deploy_zero_address_distributor() external {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new IncentraRouter(address(registry), address(0));
    }

    function test_deploy_success() external view {
        assertEq(incentraRouter.distributor(), incentraDistributor);
        assertEq(address(incentraRouter.registry()), address(registry));
    }

    function test_claim_fail_not_node() external {
        vm.startPrank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        incentraRouter.claim(randomUser, new address[](0), _payload());
        vm.stopPrank();
    }

    function test_claim_fail_not_rebalancer() external {
        vm.startPrank(randomUser);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        incentraRouter.claim(address(node), new address[](0), _payload());
        vm.stopPrank();
    }

    function test_claim_success() external {
        vm.prank(protocolOwner);
        registry.setRegistryType(address(incentraRouter), RegistryType.ROUTER, true);
        vm.startPrank(nodeOwner);
        node.addRouter(address(incentraRouter));
        node.setRebalanceWindow(24 * 60 * 60);

        assertTrue(registry.isNode(address(node)));
        assertTrue(INode(address(node)).isRebalancer(rebalancer));

        // no reward on Node
        assertEq(reward.balanceOf(address(node)), 0);

        vm.startPrank(rebalancer);
        vm.expectEmit(true, true, true, true);
        emit IncentraRouter.IncentraRewardsClaimed(address(node));
        incentraRouter.claim(address(node), new address[](0), _payload());
        vm.stopPrank();

        // Node received all rewards
        assertEq(reward.balanceOf(address(node)), cumulativeRewards[0]);
    }
}
