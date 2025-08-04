// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {MerklRouter} from "src/routers/MerklRouter.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

import {IMerklDistributor} from "src/interfaces/IMerklDistributor.sol";
import {INode} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";

contract MerklRouterTest is Test {
    bytes32 mockRoot = 0xd7200a1a96be8339675248229d31a058bf36dd9de5e35e0121e67ed450c3ef70;
    bytes32[][] nodeProof = [[bytes32(0x0bc553d11c9227090608e994aa16037932e9514339fb2d383df609703c10d087)]];
    bytes32[][] userProof = [[bytes32(0x16282b5a8ebfc3908febe125027aeabefde42d14f6872d2853164ce4b16a242d)]];
    uint256 nodeAmount = 1300000000;
    uint256 userAmount = 700000000;

    INode node = INode(0x6ca200319A0D4127a7a473d6891B86f34e312F42);
    address protocolOwner = 0x69C2d63BC4Fcd16CD616D22089B58de3796E1F5c;
    address nodeOwner = 0x8d1A519326724b18A6F5877a082aae19394D0f67;

    address user = address(0x1234);

    MerklRouter merklRouter;
    IMerklDistributor distributor;

    function setUp() external {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        uint256 arbitrumFork = vm.createFork(ARBITRUM_RPC_URL, 362881136);
        vm.selectFork(arbitrumFork);

        deal(user, 1 ether);

        INodeRegistry registry = INodeRegistry(node.registry());

        merklRouter = new MerklRouter(address(registry));
        distributor = IMerklDistributor(merklRouter.distributor());

        vm.prank(protocolOwner);
        registry.setRegistryType(address(merklRouter), RegistryType.ROUTER, true);

        vm.prank(nodeOwner);
        node.addRouter(address(merklRouter));

        // warp forward to ensure not rebalancing
        vm.warp(block.timestamp + 1 days);
    }

    function test_claim_fail_not_node() external {
        vm.prank(protocolOwner);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        merklRouter.claim(address(0x98), new address[](0), new uint256[](0), new bytes32[][](0));
    }

    function test_claim_fail_not_rebalancer() external {
        vm.prank(protocolOwner);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        merklRouter.claim(address(node), new address[](0), new uint256[](0), new bytes32[][](0));
    }

    function test_claim_success() external {
        // make sure those things match
        assertEq(distributor.tree().merkleRoot, distributor.getMerkleRoot());

        // mock the Merkl Rewards with our root
        vm.store(address(distributor), bytes32(uint256(101)), mockRoot);
        assertEq(distributor.tree().merkleRoot, mockRoot);
        assertEq(distributor.getMerkleRoot(), mockRoot);

        IERC20Metadata underlying = IERC20Metadata(node.asset());
        deal(address(underlying), address(distributor), 100_000e6);

        uint256 merklUnderlyingBalanceBefore = underlying.balanceOf(address(distributor));

        // ensure Merkl Distributor has enough funds
        assertGt(merklUnderlyingBalanceBefore, nodeAmount + userAmount);

        address[] memory tokens = new address[](1);
        tokens[0] = address(underlying);

        // check that simple user can claim mock Merkl reward
        {
            uint256 userBalanceBefore = underlying.balanceOf(user);
            vm.startPrank(user);
            address[] memory users = new address[](1);
            users[0] = user;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = userAmount;
            distributor.claim(users, tokens, amounts, userProof);
            uint256 userBalanceAfter = underlying.balanceOf(user);
            assertEq(userBalanceAfter - userBalanceBefore, userAmount);
            vm.stopPrank();
        }

        // test MerklRouter claiming to the Node itself
        {
            uint256 nodeBalanceBefore = underlying.balanceOf(address(node));
            vm.startPrank(nodeOwner);
            node.startRebalance();

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = nodeAmount;

            vm.expectEmit(true, true, true, true);
            emit MerklRouter.MerklRewardsClaimed(address(node), tokens, amounts);
            merklRouter.claim(address(node), tokens, amounts, nodeProof);

            uint256 nodeBalanceAfter = underlying.balanceOf(address(node));
            assertEq(nodeBalanceAfter - nodeBalanceBefore, nodeAmount);
            vm.stopPrank();
        }

        uint256 merklUnderlyingBalanceAfter = underlying.balanceOf(address(distributor));

        // Merkl distributor assets decreased
        assertEq(merklUnderlyingBalanceBefore - nodeAmount - userAmount, merklUnderlyingBalanceAfter);
    }
}

// NOTE: how proofs are generated
// import { AbiCoder, keccak256 } from 'ethers';

// const abi = AbiCoder.defaultAbiCoder();

// // Encode leaf: keccak256(abi.encode(user, token, amount))
// function leafHash(user: string, token: string, amount: bigint): string {
//     return keccak256(abi.encode(['address', 'address', 'uint256'], [user, token, amount]));
// }

// // Internal Merkl node hashing: keccak256(abi.encodeSorted(a, b))
// function hashPair(a: string, b: string): string {
//     return a < b
//         ? keccak256(abi.encode(['bytes32', 'bytes32'], [a, b]))
//         : keccak256(abi.encode(['bytes32', 'bytes32'], [b, a]));
// }

// // Build the tree, promoting unpaired nodes (Merkl style)
// function buildTree(leaves: string[]): string[][] {
//     const levels: string[][] = [leaves];
//     while (levels[0].length > 1) {
//         const level = levels[0];
//         const next: string[] = [];
//         for (let i = 0; i < level.length; i += 2) {
//             if (i + 1 === level.length) {
//                 next.push(level[i]);
//             } else {
//                 next.push(hashPair(level[i], level[i + 1]));
//             }
//         }
//         levels.unshift(next);
//     }
//     return levels;
// }

// // Return sibling hashes needed for Merkle proof for leaf at index
// function getProof(index: number, tree: string[][]): string[] {
//     const proof: string[] = [];
//     let i = index;
//     for (let level = tree.length - 1; level > 0; level--) {
//         const levelNodes = tree[level];
//         const isRight = i % 2 === 1;
//         const siblingIndex = isRight ? i - 1 : i + 1;
//         if (siblingIndex < levelNodes.length) {
//             proof.push(levelNodes[siblingIndex]);
//         }
//         i = Math.floor(i / 2);
//     }
//     return proof;
// }

// const node = leafHash(
//     '0x6ca200319A0D4127a7a473d6891B86f34e312F42',
//     '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
//     1300000000n,
// );

// const user = leafHash(
//     '0x0000000000000000000000000000000000001234',
//     '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
//     700000000n,
// );

// const leaves = [node, user];
// const tree = buildTree(leaves);

// console.log('Merkle Root:', tree[0][0]);

// console.log('\nNode Proof:');
// console.log(getProof(0, tree));

// console.log('\nUser Proof:');
// console.log(getProof(1, tree));
