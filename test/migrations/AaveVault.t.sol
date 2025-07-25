// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ComponentAllocation} from "src/interfaces/INode.sol";
import {Node} from "src/Node.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {INodeRegistry, RegistryType} from "src/interfaces/INodeRegistry.sol";

contract AaveVault is Test {
    address constant PROTOCOL_OWNER = 0x69C2d63BC4Fcd16CD616D22089B58de3796E1F5c;
    address constant RWAFI_OWNER = 0x8d1A519326724b18A6F5877a082aae19394D0f67;
    address constant AAVE_VAULT = 0x8E7617ba208479e1CCA2b929916285C1eCaCe4C5;
    address constant AAVE_HARVEST = 0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c;
    address constant GEARBOX = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6;

    INodeRegistry registry = INodeRegistry(0xc3d09B30a04BEBb2D942e060de4B4197e94296f7);
    Node rwafi = Node(0x6ca200319A0D4127a7a473d6891B86f34e312F42);
    ERC4626Router router = ERC4626Router(0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6);

    function setUp() external {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 360715337);
        deal(PROTOCOL_OWNER, 10 ether);
        deal(RWAFI_OWNER, 10 ether);
    }

    function test_aave_integration() external {
        vm.startPrank(RWAFI_OWNER);
        rwafi.updateTotalAssets();
        uint256 balanceBefore = rwafi.totalAssets();
        vm.stopPrank();

        // 1. Step
        vm.startPrank(PROTOCOL_OWNER);
        // Allow RWAFI Owner to to rebalancing
        registry.setRegistryType(RWAFI_OWNER, RegistryType.REBALANCER, true);
        // whitelist aave vault
        router.setWhitelistStatus(AAVE_VAULT, true);
        vm.stopPrank();

        // prepare data for the step 2
        uint64 initialRebalanceWindow = rwafi.rebalanceWindow();
        uint256 harvestShares = IERC4626(AAVE_HARVEST).balanceOf(address(rwafi));
        uint256 minAssetsOutHarvest = IERC4626(AAVE_HARVEST).previewRedeem(harvestShares) - 1;
        uint256 gearboxShares = IERC4626(GEARBOX).balanceOf(address(rwafi));
        uint256 minAssetsOutGearbox = IERC4626(GEARBOX).previewRedeem(gearboxShares) - 1;
        ComponentAllocation memory cH = rwafi.getComponentAllocation(AAVE_HARVEST);
        ComponentAllocation memory cG = rwafi.getComponentAllocation(GEARBOX);

        // 2. Step
        vm.startPrank(RWAFI_OWNER);
        // set aave vault with the same config as harvest
        rwafi.addComponent(AAVE_VAULT, cH.targetWeight + cG.targetWeight, cH.maxDelta, cH.router);
        // owner allows to rebalance itself
        rwafi.addRebalancer(RWAFI_OWNER);
        // increase rebalancing window to do reallocation
        rwafi.setRebalanceWindow(24 hours);
        // remove funds from harvest
        router.liquidate(address(rwafi), AAVE_HARVEST, harvestShares, minAssetsOutHarvest);
        // remove funds from gearbox
        router.liquidate(address(rwafi), GEARBOX, gearboxShares, minAssetsOutGearbox);
        // invest those in aave vault
        // actually it's hard to compute how much shares we get, since we need to compute _computeDepositAmount
        router.invest(address(rwafi), AAVE_VAULT, 0);
        // set rebalance window back again
        rwafi.setRebalanceWindow(initialRebalanceWindow);
        // remove harvest component
        rwafi.removeComponent(AAVE_HARVEST, false);
        // remove gearbox component
        rwafi.removeComponent(GEARBOX, false);
        vm.stopPrank();

        // we should have removed all funds
        assertEq(IERC4626(AAVE_HARVEST).balanceOf(address(rwafi)), 0);

        // 3. Step
        vm.startPrank(PROTOCOL_OWNER);
        // remove harvest from whitelisted components
        router.setWhitelistStatus(AAVE_HARVEST, false);
        vm.stopPrank();

        vm.startPrank(RWAFI_OWNER);
        rwafi.updateTotalAssets();
        uint256 balanceAfter = rwafi.totalAssets();
        vm.stopPrank();

        assertEq(balanceAfter, balanceBefore);
        assertTrue(rwafi.validateComponentRatios());
    }
}
