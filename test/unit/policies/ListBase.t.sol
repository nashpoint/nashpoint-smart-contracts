// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ListBase} from "src/policies/abstract/ListBase.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract ListBaseHarness is ListBase {
    constructor(address registry_) ListBase(registry_) {}

    function checkIsWhitelistedOne(address node) external view onlyWhitelisted(node, msg.sender) {}

    function checkIsWhitelistedTwo(address user) external view onlyWhitelisted(msg.sender, user) {}

    function checkNotBlacklistedOne(address node) external view notBlacklisted(node, msg.sender) {}

    function _executeCheck(address node, address caller, bytes4 selector, bytes calldata payload)
        internal
        view
        override
    {}

    function exposedGetLeaf(address actor) external pure returns (bytes32) {
        return _getLeaf(actor);
    }

    function exposedIsWhitelisted(address node, address actor) external view {
        _isWhitelisted(node, actor);
    }

    function getProof(address node, address actor) external view returns (bytes32[] memory) {
        return proofs[node][actor];
    }

    function exposedNotBlacklisted(address node, address actor) external view {
        _notBlacklisted(node, actor);
    }
}

contract WhitelistBaseTest is BaseTest {
    ListBaseHarness policy;

    function setUp() public override {
        super.setUp();

        policy = new ListBaseHarness(address(registry));

        bytes4[] memory sigs = new bytes4[](3);
        sigs[0] = IERC20.transfer.selector;
        sigs[1] = IERC20.approve.selector;
        sigs[2] = IERC20.transferFrom.selector;
        address[] memory policies = new address[](3);
        policies[0] = address(policy);
        policies[1] = address(policy);
        policies[2] = address(policy);

        _addPolicies(sigs, policies);
    }

    function test_manageWhitelist() external {
        address[] memory users = _toArray(user);

        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        policy.add(address(0x1234), users);

        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        policy.add(address(node), users);

        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        policy.checkIsWhitelistedOne(address(node));
        vm.stopPrank();

        vm.startPrank(address(node));
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        policy.checkIsWhitelistedTwo(user);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ListBase.ListAdded(address(node), users);
        policy.add(address(node), users);
        assertTrue(policy.list(address(node), user));
        vm.stopPrank();

        vm.startPrank(user);
        policy.checkIsWhitelistedOne(address(node));
        vm.stopPrank();

        vm.startPrank(address(node));
        policy.checkIsWhitelistedTwo(user);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ListBase.ListRemoved(address(node), users);
        policy.remove(address(node), users);
        assertFalse(policy.list(address(node), user));
        vm.stopPrank();

        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        policy.remove(address(node), users);
    }

    function test_setRoot() external {
        bytes32 root = keccak256("root");

        vm.expectRevert(ErrorsLib.NotRegistered.selector);
        policy.setRoot(makeAddr("unregistered"), root);

        vm.expectRevert(ErrorsLib.NotNodeOwner.selector);
        policy.setRoot(address(node), root);

        vm.expectEmit(true, true, false, true);
        emit ListBase.NodeRootUpdated(address(node), root);
        vm.prank(owner);
        policy.setRoot(address(node), root);
        assertEq(policy.roots(address(node)), root);
    }

    function test_getLeaf() external view {
        bytes32 expected = keccak256(bytes.concat(keccak256(abi.encode(user))));
        bytes32 leaf = policy.exposedGetLeaf(user);
        assertEq(leaf, expected);
    }

    function test_processCallerDataStoresProof() external {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256("left");
        proof[1] = keccak256("right");

        vm.expectEmit(true, true, true, true);
        emit ListBase.ProofUpdated(address(node), user, proof);
        vm.prank(address(node));
        policy.receiveUserData(user, abi.encode(proof));

        bytes32[] memory stored = policy.getProof(address(node), user);
        assertEq(stored.length, proof.length);
        for (uint256 i; i < proof.length; i++) {
            assertEq(stored[i], proof[i]);
        }
    }

    function test_isWhitelistedWithMerkleProof() external {
        address other = user2;

        bytes32 leafUser = policy.exposedGetLeaf(user);
        bytes32 leafOther = policy.exposedGetLeaf(other);
        bytes32 root = leafUser < leafOther
            ? keccak256(abi.encodePacked(leafUser, leafOther))
            : keccak256(abi.encodePacked(leafOther, leafUser));

        vm.prank(owner);
        policy.setRoot(address(node), root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafOther;

        vm.prank(address(node));
        policy.receiveUserData(user, abi.encode(proof));

        policy.exposedIsWhitelisted(address(node), user);

        vm.prank(address(node));
        policy.receiveUserData(randomUser, abi.encode(new bytes32[](0)));
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        policy.exposedIsWhitelisted(address(node), randomUser);

        proof[0] = keccak256("blabla");
        vm.prank(address(node));
        policy.receiveUserData(randomUser, abi.encode(proof));
        vm.expectRevert(ErrorsLib.NotWhitelisted.selector);
        policy.exposedIsWhitelisted(address(node), randomUser);
    }

    function test_notBlacklistedModifierBlocksListedActor() external {
        address[] memory users = _toArray(user);

        vm.prank(owner);
        policy.add(address(node), users);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        policy.checkNotBlacklistedOne(address(node));

        vm.prank(owner);
        policy.remove(address(node), users);

        vm.prank(user);
        policy.checkNotBlacklistedOne(address(node));
    }

    function test_notBlacklistedInternalFunctionRevertsForListedActor() external {
        address[] memory users = _toArray(user);

        vm.prank(owner);
        policy.add(address(node), users);

        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        policy.exposedNotBlacklisted(address(node), user);

        vm.prank(owner);
        policy.remove(address(node), users);

        policy.exposedNotBlacklisted(address(node), user);
    }
}
