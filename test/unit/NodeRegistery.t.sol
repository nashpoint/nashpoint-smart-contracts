// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseTest} from "../BaseTest.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {NodeRegistry} from "src/NodeRegistry.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

contract NodeRegistryV2 is NodeRegistry {
    function version() external pure returns (uint256) {
        return 2;
    }
}

contract NodeRegistryTest is BaseTest {
    NodeRegistry public testRegistry;

    // NodeRegistryTest specific deployment
    address public testFactory;
    address public testRouter;
    address public testNode;
    address public testRebalancer;

    function setUp() public override {
        super.setUp();

        testFactory = makeAddr("testFactory");
        testRouter = makeAddr("testRouter");
        testNode = makeAddr("testNode");
        testRebalancer = makeAddr("testRebalancer");

        address registryImpl = address(new NodeRegistry());
        testRegistry = NodeRegistry(address(new ERC1967Proxy(registryImpl, "")));
        testRegistry.initialize(owner, protocolFeesAddress, 0, 0);
    }

    function test_addNode() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
        vm.stopPrank();

        vm.prank(testFactory);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.NodeAdded(testNode);
        testRegistry.addNode(testNode);

        assertTrue(testRegistry.isNode(testNode));
    }

    function test_addFactory() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testFactory, RegistryType.FACTORY, true);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
        vm.stopPrank();

        assertTrue(testRegistry.isRegistryType(testFactory, RegistryType.FACTORY));
    }

    function test_addFactory_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
        vm.stopPrank();
    }

    function test_addNode_revert_NotFactory() public {
        vm.prank(address(1));
        vm.expectRevert(ErrorsLib.NotFactory.selector);
        testRegistry.addNode(testNode);
    }

    function test_addNode_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);
        vm.stopPrank();

        vm.startPrank(testFactory);
        testRegistry.addNode(testNode);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.addNode(testNode);
        vm.stopPrank();
    }

    function test_removeFactory() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, true);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testFactory, RegistryType.FACTORY, false);
        testRegistry.setRegistryType(testFactory, RegistryType.FACTORY, false);
        vm.stopPrank();

        assertFalse(testRegistry.isRegistryType(testFactory, RegistryType.FACTORY));
    }

    // Router tests
    function test_addRouter() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRouter, RegistryType.ROUTER, true);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);
        vm.stopPrank();

        assertTrue(testRegistry.isRegistryType(testRouter, RegistryType.ROUTER));
    }

    function test_addRouter_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);
        vm.stopPrank();
    }

    function test_removeRouter() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, true);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRouter, RegistryType.ROUTER, false);
        testRegistry.setRegistryType(testRouter, RegistryType.ROUTER, false);
        vm.stopPrank();

        assertFalse(testRegistry.isRegistryType(testRouter, RegistryType.ROUTER));
    }

    function test_setPoliciesRoot() public {
        bytes32 newRoot = keccak256("policies root");

        vm.expectEmit(false, false, false, true);
        emit EventsLib.PoliciesRootUpdate(newRoot);
        vm.prank(owner);
        testRegistry.setPoliciesRoot(newRoot);

        assertEq(testRegistry.policiesRoot(), newRoot);
    }

    function test_setPoliciesRoot_revert_OnlyOwner() public {
        address notOwner = makeAddr("notOwner");
        bytes32 newRoot = bytes32(uint256(1));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        vm.prank(notOwner);
        testRegistry.setPoliciesRoot(newRoot);
    }

    function test_updateSetupCallWhitelist() public {
        address target = makeAddr("setupTarget");

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.SetupCallChange(target, true);
        testRegistry.updateSetupCallWhitelist(target, true);
        assertTrue(testRegistry.setupCallWhitelisted(target));

        vm.expectEmit(true, false, false, false);
        emit EventsLib.SetupCallChange(target, false);
        testRegistry.updateSetupCallWhitelist(target, false);
        vm.stopPrank();

        assertFalse(testRegistry.setupCallWhitelisted(target));
    }

    function test_updateSetupCallWhitelist_revert_OnlyOwner() public {
        address notOwner = makeAddr("notOwner");
        address target = makeAddr("setupTarget");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        vm.prank(notOwner);
        testRegistry.updateSetupCallWhitelist(target, true);

        assertFalse(testRegistry.setupCallWhitelisted(target));
    }

    // Rebalancer tests
    function test_addRebalancer() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRebalancer, RegistryType.REBALANCER, true);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);
        vm.stopPrank();

        assertTrue(testRegistry.isRegistryType(testRebalancer, RegistryType.REBALANCER));
    }

    function test_addRebalancer_revert_AlreadySet() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);
        vm.stopPrank();
    }

    function test_removeRebalancer() public {
        vm.startPrank(owner);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, true);

        vm.expectEmit(true, false, false, false);
        emit EventsLib.RoleSet(testRebalancer, RegistryType.REBALANCER, false);
        testRegistry.setRegistryType(testRebalancer, RegistryType.REBALANCER, false);
        vm.stopPrank();

        assertFalse(testRegistry.isRegistryType(testRebalancer, RegistryType.REBALANCER));
    }

    function test_setRegistryType_reverts() external {
        vm.startPrank(owner);

        vm.expectRevert(ErrorsLib.InvalidRole.selector);
        testRegistry.setRegistryType(testRebalancer, RegistryType.UNUSED, true);

        vm.expectRevert(ErrorsLib.NotFactory.selector);
        testRegistry.setRegistryType(testRebalancer, RegistryType.NODE, true);

        vm.stopPrank();
    }

    function test_setProtocolFeeAddress() external {
        vm.startPrank(owner);

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        testRegistry.setProtocolFeeAddress(address(0));

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        testRegistry.setProtocolFeeAddress(protocolFeesAddress);

        testRegistry.setProtocolFeeAddress(address(0x1234));
        assertEq(testRegistry.protocolFeeAddress(), address(0x1234));

        vm.stopPrank();
    }

    function test_setProtocolFees() external {
        vm.startPrank(owner);

        vm.expectRevert(ErrorsLib.InvalidFee.selector);
        testRegistry.setProtocolManagementFee(1e18 + 1);

        vm.expectRevert(ErrorsLib.InvalidFee.selector);
        testRegistry.setProtocolExecutionFee(1e18 + 1);

        testRegistry.setProtocolManagementFee(123);
        testRegistry.setProtocolExecutionFee(456);

        assertEq(testRegistry.protocolManagementFee(), 123);
        assertEq(testRegistry.protocolExecutionFee(), 456);

        vm.stopPrank();
    }

    function test_upgrade() external {
        address newImplementation = address(new NodeRegistryV2());

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        testRegistry.upgradeToAndCall(newImplementation, "");

        vm.startPrank(owner);
        testRegistry.upgradeToAndCall(newImplementation, "");

        assertEq(NodeRegistryV2(address(testRegistry)).version(), 2);
    }

    // POLICY TESTS

    // how data has been generated:

    // import { StandardMerkleTree } from './standard';

    // const sigs = {
    //   withdraw: '0xb460af94',
    //   transferFrom: '0x23b872dd',
    //   transfer: '0xa9059cbb',
    //   subtractProtocolExecutionFee: '0x5831a0ae',
    //   startRebalance: '0x4dce7057',
    //   redeem: '0xba087652',
    //   payManagementFees: '0x97c14160',
    //   mint: '0x94bf804d',
    //   fulfillRedeemFromReserve: '0xd4a6f541',
    //   finalizeRedemption: '0x203af657',
    //   execute: '0x1cff79cd',
    //   deposit: '0x6e553f65',
    //   approve: '0x095ea7b3',
    //   updateTotalAssets: '0xd033cb4d',
    // };
    // const whitelistPolicy = '0x0000000000000000000000000000000000000001';
    // const rebalancerPolicy = '0x0000000000000000000000000000000000000002';
    // const pausingPolicy = '0x0000000000000000000000000000000000000003';
    // const policies = [
    //   {
    //     policy: whitelistPolicy,
    //     sigs: ['deposit', 'withdraw', 'redeem', 'transfer', 'transferFrom', 'approve'],
    //   },
    //   {
    //     policy: rebalancerPolicy,
    //     sigs: [
    //       'subtractProtocolExecutionFee',
    //       'startRebalance',
    //       'fulfillRedeemFromReserve',
    //       'finalizeRedemption',
    //       'updateTotalAssets',
    //     ],
    //   },
    //   {
    //     policy: pausingPolicy,
    //     sigs: [
    //       'withdraw',
    //       'transferFrom',
    //       'transfer',
    //       'subtractProtocolExecutionFee',
    //       'startRebalance',
    //       'redeem',
    //       'payManagementFees',
    //       'mint',
    //       'fulfillRedeemFromReserve',
    //       'finalizeRedemption',
    //       'execute',
    //       'deposit',
    //       'approve',
    //       'updateTotalAssets',
    //     ],
    //   },
    // ];

    // const buildLeafs = (
    //   data: {
    //     policy: string;
    //     sigs: string[];
    //   }[],
    // ) => {
    //   const leafs: [string, string][] = [];
    //   data.forEach(p => {
    //     p.sigs.forEach(s => {
    //       // @ts-ignore
    //       leafs.push([sigs[s], p.policy]);
    //     });
    //   });
    //   return leafs;
    // };

    // async function main() {
    //   const tree = StandardMerkleTree.of(buildLeafs(policies), ['bytes4', 'address']);

    //   const policiesToUse = policies.map(p => {
    //     const sigs = p.sigs
    //       .map(s => {
    //         if (Math.random() > 0.5) {
    //           return s;
    //         }
    //         return '';
    //       })
    //       .filter(s => s);
    //     return {
    //       policy: p.policy,
    //       sigs,
    //     };
    //   });

    //   const multiProof = tree.getMultiProof(buildLeafs(policiesToUse));

    //   console.log(tree.root)
    //   console.log(multiProof);
    // }

    // main();

    // DATA
    //     0x35be2de2ea9fc003715aad9814b0b83805fa8eaaa37eebb50792a0a3cc59f171
    // {
    //   leaves: [
    //     [ '0x095ea7b3', '0x0000000000000000000000000000000000000001' ],
    //     [ '0xb460af94', '0x0000000000000000000000000000000000000001' ],
    //     [ '0x095ea7b3', '0x0000000000000000000000000000000000000003' ],
    //     [ '0xd033cb4d', '0x0000000000000000000000000000000000000003' ],
    //     [ '0x5831a0ae', '0x0000000000000000000000000000000000000002' ],
    //     [ '0x203af657', '0x0000000000000000000000000000000000000003' ],
    //     [ '0x23b872dd', '0x0000000000000000000000000000000000000003' ],
    //     [ '0x203af657', '0x0000000000000000000000000000000000000002' ],
    //     [ '0x6e553f65', '0x0000000000000000000000000000000000000003' ],
    //     [ '0xa9059cbb', '0x0000000000000000000000000000000000000003' ],
    //     [ '0x4dce7057', '0x0000000000000000000000000000000000000003' ],
    //     [ '0xd033cb4d', '0x0000000000000000000000000000000000000002' ]
    //   ],
    //   proof: [
    //     '0x076dacb3ade089eeb57607865c7e3d6b582e3963ec6e24b7d9160ba6e74f55c5',
    //     '0x294b43a0b647843436cedfd335e409aa062fbdb47cb920e24275f9dc5f3ff027',
    //     '0x3a493b903cd9298dd3a099a35bdd1020fc8f9935e153868fdaa953b097c222a5',
    //     '0x7d57539f1419b0701df5c2e7e871a51c9d218707d2767684e9dbd3ab58f592ee',
    //     '0xa306866328cbe0491d83ca53c0b60774ec24eac46c3c0682134a6371a8ed3201',
    //     '0xa79f60d08082aa67efdc3f0c5f2b81b8f36f61879dd1c216a03f61037efb688b',
    //     '0xb2a267765ac9bd247b569f38f7737a41bb522625c1f54551fed28586f5fa9297',
    //     '0xd454291e26eada6bf7f56c1b2bbe039ad4f11ce4596ebb1fbc113b3da04a0f50',
    //     '0xdebeb9ab0b0a356b0ff32e98cc2f4b2ab90acaf75b9d3478b13e643508965fd8',
    //     '0xe93dd3a4dc430dd5eb67b1b75dc1575167df6cb9f0a08ebecb68b992afaf8a4c',
    //     '0xf866904479fced81b357d151c7d28a9576e733f92a719466b84e095cb4ffed3f',
    //     '0xbf78c5c6396c08f69a80d767300feaeb99571b30f26620e2050105616e48937b'
    //   ],
    //   proofFlags: [
    //     false, false, false, true,
    //     false, false, false, false,
    //     false, false, false, false,
    //     true,  true,  true,  true,
    //     true,  false, true,  true,
    //     true,  true,  true
    //   ]
    // }

    function test_verifyPolicies() external {
        bytes32 newRoot = 0x35be2de2ea9fc003715aad9814b0b83805fa8eaaa37eebb50792a0a3cc59f171;

        vm.prank(owner);
        testRegistry.setPoliciesRoot(newRoot);

        bytes32[] memory proof = new bytes32[](12);
        proof[0] = 0x076dacb3ade089eeb57607865c7e3d6b582e3963ec6e24b7d9160ba6e74f55c5;
        proof[1] = 0x294b43a0b647843436cedfd335e409aa062fbdb47cb920e24275f9dc5f3ff027;
        proof[2] = 0x3a493b903cd9298dd3a099a35bdd1020fc8f9935e153868fdaa953b097c222a5;
        proof[3] = 0x7d57539f1419b0701df5c2e7e871a51c9d218707d2767684e9dbd3ab58f592ee;
        proof[4] = 0xa306866328cbe0491d83ca53c0b60774ec24eac46c3c0682134a6371a8ed3201;
        proof[5] = 0xa79f60d08082aa67efdc3f0c5f2b81b8f36f61879dd1c216a03f61037efb688b;
        proof[6] = 0xb2a267765ac9bd247b569f38f7737a41bb522625c1f54551fed28586f5fa9297;
        proof[7] = 0xd454291e26eada6bf7f56c1b2bbe039ad4f11ce4596ebb1fbc113b3da04a0f50;
        proof[8] = 0xdebeb9ab0b0a356b0ff32e98cc2f4b2ab90acaf75b9d3478b13e643508965fd8;
        proof[9] = 0xe93dd3a4dc430dd5eb67b1b75dc1575167df6cb9f0a08ebecb68b992afaf8a4c;
        proof[10] = 0xf866904479fced81b357d151c7d28a9576e733f92a719466b84e095cb4ffed3f;
        proof[11] = 0xbf78c5c6396c08f69a80d767300feaeb99571b30f26620e2050105616e48937b;

        bool[] memory proofFlags = new bool[](23);
        proofFlags[0] = false;
        proofFlags[1] = false;
        proofFlags[2] = false;
        proofFlags[3] = true;
        proofFlags[4] = false;
        proofFlags[5] = false;
        proofFlags[6] = false;
        proofFlags[7] = false;
        proofFlags[8] = false;
        proofFlags[9] = false;
        proofFlags[10] = false;
        proofFlags[11] = false;
        proofFlags[12] = true;
        proofFlags[13] = true;
        proofFlags[14] = true;
        proofFlags[15] = true;
        proofFlags[16] = true;
        proofFlags[17] = false;
        proofFlags[18] = true;
        proofFlags[19] = true;
        proofFlags[20] = true;
        proofFlags[21] = true;
        proofFlags[22] = true;

        bytes4[] memory sigs = new bytes4[](12);
        sigs[0] = 0x095ea7b3;
        sigs[1] = 0xb460af94;
        sigs[2] = 0x095ea7b3;
        sigs[3] = 0xd033cb4d;
        sigs[4] = 0x5831a0ae;
        sigs[5] = 0x203af657;
        sigs[6] = 0x23b872dd;
        sigs[7] = 0x203af657;
        sigs[8] = 0x6e553f65;
        sigs[9] = 0xa9059cbb;
        sigs[10] = 0x4dce7057;
        sigs[11] = 0xd033cb4d;

        address[] memory policies = new address[](12);
        policies[0] = 0x0000000000000000000000000000000000000001;
        policies[1] = 0x0000000000000000000000000000000000000001;
        policies[2] = 0x0000000000000000000000000000000000000003;
        policies[3] = 0x0000000000000000000000000000000000000003;
        policies[4] = 0x0000000000000000000000000000000000000002;
        policies[5] = 0x0000000000000000000000000000000000000003;
        policies[6] = 0x0000000000000000000000000000000000000003;
        policies[7] = 0x0000000000000000000000000000000000000002;
        policies[8] = 0x0000000000000000000000000000000000000003;
        policies[9] = 0x0000000000000000000000000000000000000003;
        policies[10] = 0x0000000000000000000000000000000000000003;
        policies[11] = 0x0000000000000000000000000000000000000002;

        assertTrue(testRegistry.verifyPolicies(proof, proofFlags, sigs, policies));

        address tempPolicy = policies[1];
        policies[1] = 0x0000000000000000000000000000000000000002;
        assertFalse(testRegistry.verifyPolicies(proof, proofFlags, sigs, policies));
        policies[1] = tempPolicy;

        proofFlags[0] = true;
        proofFlags[13] = false;
        assertFalse(testRegistry.verifyPolicies(proof, proofFlags, sigs, policies));
        proofFlags[0] = false;
        proofFlags[13] = true;
    }

    function test_verifyPolicies_revert_LengthMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.LengthMismatch.selector));
        testRegistry.verifyPolicies(new bytes32[](1), new bool[](2), new bytes4[](2), new address[](3));
    }
}
