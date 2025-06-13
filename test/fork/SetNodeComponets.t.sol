// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {console2} from "forge-std/console2.sol";

contract SetNodeComponents is BaseTest {
    uint256 arbitrumFork;
    uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address liveOwner = vm.addr(privateKey);

    address constant farmUsdcAaveV3Address = 0x803Ae650Bc7c40b03Fe1C33F2a787E81f1c4819c; // aave
    address constant cfgUsdcJTRSY = 0x16C796208c6E2d397Ec49D69D207a9cB7d072f04; // centrifuge
    address constant fUsdcAddress = 0x1A996cb54bb95462040408C06122D45D6Cdb6096; // fluid
    address constant sdUSDCV3Address = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6; // gearbox
    address constant revertUsdcV3VaultAddress = 0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825; // revert

    address constant deployedNodeAddress = 0x6ca200319A0D4127a7a473d6891B86f34e312F42;
    address constant deployedRouter4626 = 0x7124a7DF6D804FCba0B0A06fF63a0cC831c6b0e6;
    address constant deployedRouter7540 = 0x6a200b1Bafc7183741809B35E1B0DE9E4f4c0828;

    INode liveNode = INode(deployedNodeAddress);
    IERC20 public usdc = IERC20(usdcArbitrum);
    IERC4626 public fUsdc = IERC4626(fUsdcAddress);
    IERC4626 public sdUsdcV3 = IERC4626(sdUSDCV3Address);
    IERC4626 public farmUsdcAaveV3 = IERC4626(farmUsdcAaveV3Address);
    IERC4626 public revertUsdcV3Vault = IERC4626(revertUsdcV3VaultAddress);

    address[] componentArray =
        [farmUsdcAaveV3Address, cfgUsdcJTRSY, fUsdcAddress, sdUSDCV3Address, revertUsdcV3VaultAddress];

    function setUp() public override {
        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(arbitrumFork);
        super.setUp();
    }

    function test_nodeGetComponents_live() public view {
        address[] memory liveComponents = liveNode.getComponents();
        assertEq(liveComponents.length, componentArray.length);
        for (uint256 i = 0; i < liveComponents.length; i++) {
            assertEq(liveComponents[i], componentArray[i]);
        }
    }

    function test_nodeisCacheValid_live() public view {
        assertFalse(liveNode.isCacheValid());
    }

    // updateComponentAllocation(address component, uint64 targetWeight, uint64 maxDelta, address router)

    function test_updateComponents_live() public {
        assertEq(liveNode.targetReserveRatio(), 0.05 ether);

        vm.startPrank(liveOwner);
        liveNode.updateComponentAllocation(farmUsdcAaveV3Address, 0.1000 ether, 0.01 ether, deployedRouter4626);
        liveNode.updateComponentAllocation(cfgUsdcJTRSY, 0.2043 ether, 0.01 ether, deployedRouter7540);
        liveNode.updateComponentAllocation(fUsdcAddress, 0.2427 ether, 0.01 ether, deployedRouter4626);
        liveNode.updateComponentAllocation(sdUSDCV3Address, 0.0635 ether, 0.01 ether, deployedRouter4626);
        liveNode.updateComponentAllocation(revertUsdcV3VaultAddress, 0.3395 ether, 0.01 ether, deployedRouter4626);   

        liveNode.addRebalancer(liveOwner);           

        liveNode.startRebalance();
        vm.stopPrank();

        
    }
}
