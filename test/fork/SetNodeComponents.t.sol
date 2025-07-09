// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {console2} from "forge-std/console2.sol";

contract SetNodeComponents is BaseTest {
    uint256 arbitrumFork;
    // uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    // address liveOwner = vm.addr(privateKey);

    address constant farmUsdcAaveV3Address = 0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c; // aave
    address constant cfgUsdcJTRSY = 0x16C796208c6E2d397Ec49D69D207a9cB7d072f04; // centrifuge
    address constant fUsdcAddress = 0x1A996cb54bb95462040408C06122D45D6Cdb6096; // fluid
    address constant sdUSDCV3Address = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6; // gearbox
    address constant revertUsdcV3VaultAddress = 0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825; // revert

    address constant deployedNodeAddress = 0x6ca200319A0D4127a7a473d6891B86f34e312F42;
    address constant deployedRouter4626 = 0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6;
    address constant deployedRouter7540 = 0x6a200b1Bafc7183741809B35E1B0DE9E4f4c0828;
    address constant deployedNodeOwnerMultisig = 0x8d1A519326724b18A6F5877a082aae19394D0f67;

    INode liveNode = INode(deployedNodeAddress);
    IERC20 public usdc = IERC20(usdcArbitrum);
    IERC4626 public fUsdc = IERC4626(fUsdcAddress);
    IERC4626 public sdUsdcV3 = IERC4626(sdUSDCV3Address);
    IERC4626 public farmUsdcAaveV3 = IERC4626(farmUsdcAaveV3Address);
    IERC4626 public revertUsdcV3Vault = IERC4626(revertUsdcV3VaultAddress);

    address liveOwner;

    address[] componentArray =
        [farmUsdcAaveV3Address, cfgUsdcJTRSY, fUsdcAddress, sdUSDCV3Address, revertUsdcV3VaultAddress];

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(arbitrumFork);
        super.setUp();
        liveOwner = Ownable(address(liveNode)).owner();
    }

    function test_nodeGetComponents_live() public view {
        address[] memory liveComponents = liveNode.getComponents();
        assertEq(liveComponents.length, componentArray.length);
        for (uint256 i = 0; i < liveComponents.length; i++) {
            assertEq(liveComponents[i], componentArray[i]);
        }
    }

    function test_updateNodeTotalAssets_live() public {
        vm.prank(liveOwner);
        liveNode.updateTotalAssets();
    }

    function test_validate_live_cfg_updated() public view {
        // Get Centrifuge's current allocation
        ComponentAllocation memory cfgAllocation = liveNode.getComponentAllocation(cfgUsdcJTRSY);

        // Validate Centrifuge is set to 95%
        assertEq(cfgAllocation.targetWeight, 950000000000000000); // 0.95 ether
        assertEq(cfgAllocation.maxDelta, 10000000000000000); // 0.01 ether
        assertEq(cfgAllocation.router, deployedRouter7540);
        assertTrue(cfgAllocation.isComponent);

        // Validate all other components are set to 0%
        ComponentAllocation memory aaveAllocation = liveNode.getComponentAllocation(farmUsdcAaveV3Address);
        ComponentAllocation memory fluidAllocation = liveNode.getComponentAllocation(fUsdcAddress);
        ComponentAllocation memory gearboxAllocation = liveNode.getComponentAllocation(sdUSDCV3Address);
        ComponentAllocation memory revertAllocation = liveNode.getComponentAllocation(revertUsdcV3VaultAddress);

        assertEq(aaveAllocation.targetWeight, 0);
        assertEq(fluidAllocation.targetWeight, 0);
        assertEq(gearboxAllocation.targetWeight, 0);
        assertEq(revertAllocation.targetWeight, 0);

        // Validate total ratios are correct (95% in components + 5% reserve)
        assertTrue(liveNode.validateComponentRatios());
    }

    function test_nodeisCacheValid_live() public view {
        assertFalse(liveNode.isCacheValid());
    }

    // updateComponentAllocation(address component, uint64 targetWeight, uint64 maxDelta, address router)
    function test_updateComponents_live_realValues() public {
        assertEq(liveNode.targetReserveRatio(), 50000000000000000); // 0.05 ether

        vm.startPrank(0x8d1A519326724b18A6F5877a082aae19394D0f67); // deployedNodeOwnerMultisig
        liveNode.updateComponentAllocation(
            0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c, // farmUsdcAaveV3Address
            150000000000000000, // 0.150 ether
            10000000000000000, // 0.01 ether
            0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6 // deployedRouter4626
        );
        liveNode.updateComponentAllocation(
            0x16C796208c6E2d397Ec49D69D207a9cB7d072f04, // cfgUsdcJTRSY
            204300000000000000, // 0.2043 ether
            10000000000000000, // 0.01 ether
            0x6a200b1Bafc7183741809B35E1B0DE9E4f4c0828 // deployedRouter7540
        );
        liveNode.updateComponentAllocation(
            0x1A996cb54bb95462040408C06122D45D6Cdb6096, // fUsdcAddress
            242700000000000000, // 0.2427 ether
            10000000000000000, // 0.01 ether
            0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6 // deployedRouter4626
        );
        liveNode.updateComponentAllocation(
            0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6, // sdUSDCV3Address
            13500000000000000, // 0.0135 ether
            10000000000000000, // 0.01 ether
            0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6 // deployedRouter4626
        );
        liveNode.updateComponentAllocation(
            0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825, // revertUsdcV3VaultAddress
            339500000000000000, // 0.3395 ether
            10000000000000000, // 0.01 ether
            0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6 // deployedRouter4626
        );

        assertTrue(liveNode.validateComponentRatios());
        vm.stopPrank();
    }

    function test_updateComponents_live_newValues() public {
        assertEq(liveNode.targetReserveRatio(), 50000000000000000); // 0.05 ether

        vm.startPrank(0x8d1A519326724b18A6F5877a082aae19394D0f67); // deployedNodeOwnerMultisig
        liveNode.updateComponentAllocation(
            0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c, // farmUsdcAaveV3Address
            0, // 0 ether
            10000000000000000, // 0.01 ether
            0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6 // deployedRouter4626
        );
        liveNode.updateComponentAllocation(
            0x16C796208c6E2d397Ec49D69D207a9cB7d072f04, // cfgUsdcJTRSY
            950000000000000000, // 0.95 ether
            10000000000000000, // 0.01 ether
            0x6a200b1Bafc7183741809B35E1B0DE9E4f4c0828 // deployedRouter7540
        );
        liveNode.updateComponentAllocation(
            0x1A996cb54bb95462040408C06122D45D6Cdb6096, // fUsdcAddress
            0, // 0 ether
            10000000000000000, // 0.01 ether
            0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6 // deployedRouter4626
        );
        liveNode.updateComponentAllocation(
            0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6, // sdUSDCV3Address
            0, // 0 ether
            10000000000000000, // 0.01 ether
            0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6 // deployedRouter4626
        );
        liveNode.updateComponentAllocation(
            0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825, // revertUsdcV3VaultAddress
            0, // 0 ether
            10000000000000000, // 0.01 ether
            0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6 // deployedRouter4626
        );

        assertTrue(liveNode.validateComponentRatios());
        vm.stopPrank();
    }

    function test_updateComponents_live() public {
        assertEq(liveNode.targetReserveRatio(), 0.05 ether);

        vm.startPrank(liveOwner);
        liveNode.updateComponentAllocation(farmUsdcAaveV3Address, 0.1 ether, 0.01 ether, deployedRouter4626);
        liveNode.updateComponentAllocation(cfgUsdcJTRSY, 0.2043 ether, 0.01 ether, deployedRouter7540);
        liveNode.updateComponentAllocation(fUsdcAddress, 0.2427 ether, 0.01 ether, deployedRouter4626);
        liveNode.updateComponentAllocation(sdUSDCV3Address, 0.0635 ether, 0.01 ether, deployedRouter4626);
        liveNode.updateComponentAllocation(revertUsdcV3VaultAddress, 0.3395 ether, 0.01 ether, deployedRouter4626);

        assertTrue(liveNode.validateComponentRatios());
        vm.stopPrank();
    }

    function test_rebalance_to_Centrifuge() public {}
}
