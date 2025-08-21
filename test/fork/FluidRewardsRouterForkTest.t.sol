// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {FluidRewardsRouter} from "src/routers/FluidRewardsRouter.sol";
import {INode} from "src/interfaces/INode.sol";
import {INodeRegistry, RegistryType} from "src/interfaces/INodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

contract FluidRewardsRouterForkTest is Test {
    INodeRegistry registry;
    address protocolOwner = 0x69C2d63BC4Fcd16CD616D22089B58de3796E1F5c;
    address nodeOwner = 0x8d1A519326724b18A6F5877a082aae19394D0f67;
    address rebalancer = nodeOwner;

    uint256 blockNumber = 370346542;
    address fluidDistributor = 0x94312a608246Cecfce6811Db84B3Ef4B2619054E;

    bytes32 positionId = bytes32(uint256(uint160(0x1A996cb54bb95462040408C06122D45D6Cdb6096)));
    uint256 cycle = 101;
    uint256 cumulativeAmount = 6032462101433512556;

    INode node = INode(0x6ca200319A0D4127a7a473d6891B86f34e312F42);

    IERC20Metadata reward = IERC20Metadata(0x61E030A56D33e8260FdD81f03B162A79Fe3449Cd);

    address randomUser = address(0x1234);

    bytes32[] proof;

    FluidRewardsRouter fluidRewardsRouter;

    function setUp() external {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        vm.createSelectFork(ARBITRUM_RPC_URL, blockNumber);

        registry = INodeRegistry(node.registry());

        fluidRewardsRouter = new FluidRewardsRouter(address(registry), fluidDistributor);

        proof = new bytes32[](13);
        proof[0] = 0xd8ede23324e31cf936e556d816399f28635ecec5d0a0fcaf85c4aaeaf72a4bb0;
        proof[1] = 0x1f54abfb5d45410b31353a220bcf0d3f09d1ab623a050d5cdcea6859ba8b9dfa;
        proof[2] = 0x7861572646c556c54ef697e6d1770baca680179a8558e34fe4eca83669c9bbb8;
        proof[3] = 0x9365e09530029f5f9d71cf38bd4cbf450f4da5795bd4f1f674ef52034cb14500;
        proof[4] = 0x37a9158b43e0c5f2294a0a776d17cee9db1d1564b92b8000e2916166f8c7790b;
        proof[5] = 0x52d3990c631b2532992ab3ef2ce45a86bef3d4ea7f004273d44a2e8513ef9bc8;
        proof[6] = 0x134f8357e9c767e2ca80fc9449e51a415613d3675d45e2c26b48151568dabdf9;
        proof[7] = 0x958b5d8c4530be5d1e071994527dbe917de5790c50a4ae19cb1e1655243a078c;
        proof[8] = 0xa1850e2697ad1830965dc3a7715b4bc1c7fcc02d87fa4bea4c986c583f771e25;
        proof[9] = 0xcbe4c465ab2283f96d2361e8ae77b3d60836d03a06b169ad136fc47db5a98215;
        proof[10] = 0x3d5d3cac1fc2cc2d256db2a1d75be08ed62c12fb4de474bfb0e8d6296344dfdb;
        proof[11] = 0x2f169acfa8ea35f0966882caca58e9103b934db065159ec8a3211ca23749225d;
        proof[12] = 0xe15dfe8689eb1e01ccb5e563a054304ea019a3536976f75c9c6ca32d716c7926;
    }

    function test_revert_deploy_zero_address_distributor() external {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new FluidRewardsRouter(address(registry), address(0));
    }

    function test_deploy_success() external view {
        assertEq(fluidRewardsRouter.distributor(), fluidDistributor);
        assertEq(address(fluidRewardsRouter.registry()), address(registry));
    }

    function test_claim_revert() external {
        vm.startPrank(randomUser);
        vm.expectRevert(ErrorsLib.NotRebalancer.selector);
        fluidRewardsRouter.claim(address(node), cumulativeAmount, positionId, cycle, proof);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        vm.expectRevert(ErrorsLib.InvalidNode.selector);
        fluidRewardsRouter.claim(randomUser, cumulativeAmount, positionId, cycle, proof);
        vm.stopPrank();
    }

    function test_claim_success() external {
        vm.prank(protocolOwner);
        registry.setRegistryType(address(fluidRewardsRouter), RegistryType.ROUTER, true);
        vm.startPrank(nodeOwner);
        node.addRouter(address(fluidRewardsRouter));
        node.setRebalanceWindow(24 * 60 * 60);

        assertTrue(registry.isNode(address(node)));
        assertTrue(INode(address(node)).isRebalancer(rebalancer));

        // no reward on Node
        assertEq(reward.balanceOf(address(node)), 0);

        vm.startPrank(rebalancer);
        vm.expectEmit(true, true, true, true);
        emit FluidRewardsRouter.FluidRewardsClaimed(address(node), cycle, cumulativeAmount);
        fluidRewardsRouter.claim(address(node), cumulativeAmount, positionId, cycle, proof);
        vm.stopPrank();

        // Node received all rewards
        assertEq(reward.balanceOf(address(node)), cumulativeAmount);
    }
}
