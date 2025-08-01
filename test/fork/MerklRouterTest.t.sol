// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {MerklRouter} from "src/routers/MerklRouter.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

import {IMerklDistributor} from "src/interfaces/IMerklDistributor.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";

import {BaseTest} from "test/BaseTest.sol";

contract MerklRouterTest is BaseTest {
    bytes32 mockRoot = 0x4d8e6cef729b576d577e6dd40383ab461472b2d477302b4dbf910cbc6c429a79;
    bytes32[][] nodeProof = [[bytes32(0xc329c5302d76bcadef989a9b0f28504575c95e9dc247f8996ad8e77c3516db3f)]];
    bytes32[][] userProof = [[bytes32(0xcd4d844b9a99cec07647b40f587c042921a4a390adbbd9e49a742d076ce094ba)]];
    uint256 nodeAmount = 1300000000;
    uint256 userAmount = 700000000;

    MerklRouter merklRouter;
    IMerklDistributor distributor;

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        uint256 arbitrumFork = vm.createFork(ARBITRUM_RPC_URL, 362881136);
        vm.selectFork(arbitrumFork);
        super.setUp();

        merklRouter = new MerklRouter(address(registry));
        distributor = IMerklDistributor(merklRouter.distributor());

        vm.startPrank(owner);
        registry.setRegistryType(address(merklRouter), RegistryType.ROUTER, true);
        node.addRouter(address(merklRouter));
        vm.stopPrank();

        // warp forward to ensure not rebalancing
        vm.warp(block.timestamp + 1 days);
    }

    function test_claim() external {
        assertEq(address(node), 0x10B1bA5AfB39786747ca55797509d0AA9e0774C6);
        assertEq(user, 0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D);
        // make sure those things match
        assertEq(distributor.tree().merkleRoot, distributor.getMerkleRoot());

        // mock the Merkl Rewards with our root
        vm.store(address(distributor), bytes32(uint256(101)), mockRoot);
        assertEq(distributor.tree().merkleRoot, mockRoot);
        assertEq(distributor.getMerkleRoot(), mockRoot);

        IERC20Metadata underlying = IERC20Metadata(node.asset());
        assertEq(address(underlying), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
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
            vm.startPrank(rebalancer);
            node.startRebalance();

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = nodeAmount;

            vm.expectEmit(true, true, true, true);
            emit EventsLib.MerklRewardsClaimed(address(node), tokens, amounts);
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
//     '0x10B1bA5AfB39786747ca55797509d0AA9e0774C6',
//     '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
//     1300000000n,
// );

// const user = leafHash(
//     '0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D',
//     '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
//     700000000n,
// );

// const leaves = [node, user];
// const tree = buildTree(leaves);

// console.log('Merkle Root:', tree[0][0]);

// console.log('\nNode Proof:');
// console.log(getProof(0, tree));

// console.log('\nUser Proof:');
// console.log(getProof(1, tree));
