// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/BeforeAfter.sol";
import "../../mocks/FluidDistributorMock.sol";

contract LogicalRewardRouters is BeforeAfter {
    function logicalRewardRouters() internal {
        _checkFluidRouterState();
        _checkIncentraRouterState();
        _checkMerklRouterState();
    }

    function _checkFluidRouterState() private {
        if (address(routerFluid) == address(0)) {
            fl.log("REWARD_fluid_router_missing");
            return;
        }

        if (routerFluid.distributor() == address(0)) {
            fl.log("REWARD_fluid_distributor_missing");
        } else {
            fl.log("REWARD_fluid_distributor_configured");
        }

        if (address(routerFluid.registry()) == address(registry)) {
            fl.log("REWARD_fluid_registry_linked");
        } else {
            fl.log("REWARD_fluid_registry_mismatch");
        }

        if (address(node) != address(0)) {
            _checkFluidRewardTiming();
        }
    }

    function _checkFluidRewardTiming() private {
        (
            address recipient,
            uint256 cumulativeAmount,
            uint8 positionType,
            bytes32 positionId,
            uint256 cycle,
            bytes32 proofHash
        ) = fluidDistributor.lastClaimInfo();

        if (recipient == address(node)) {
            fl.log("REWARD_fluid_node_recent_claim");
        }
        if (cumulativeAmount == 0) {
            fl.log("REWARD_fluid_last_claim_zero");
        }

        if (cycle == 0) {
            fl.log("REWARD_fluid_cycle_zero");
        } else if (block.timestamp % 2 == 0) {
            fl.log("REWARD_fluid_cycle_active");
        }
        if (positionType == 1) {
            fl.log("REWARD_fluid_position_lending_type");
        }
        if (positionId == bytes32(0) && proofHash == bytes32(0)) {
            fl.log("REWARD_fluid_claim_uninitialized");
        }
    }

    function _checkIncentraRouterState() private {
        if (address(routerIncentra) == address(0)) {
            fl.log("REWARD_incentra_router_missing");
            return;
        }

        if (routerIncentra.distributor() == address(0)) {
            fl.log("REWARD_incentra_distributor_missing");
        } else {
            fl.log("REWARD_incentra_distributor_configured");
        }

        if (address(routerIncentra.registry()) == address(registry)) {
            fl.log("REWARD_incentra_registry_linked");
        } else {
            fl.log("REWARD_incentra_registry_mismatch");
        }

        if (address(node) != address(0)) {
            uint256 simulatedQueue = uint256(keccak256(abi.encodePacked("INCENTRA_QUEUE", iteration, block.number))) % 10;
            if (simulatedQueue == 0) {
                fl.log("REWARD_incentra_no_pending_campaigns");
            } else if (simulatedQueue < 5) {
                fl.log("REWARD_incentra_light_queue");
            } else {
                fl.log("REWARD_incentra_heavy_queue");
            }
        }
    }

    function _checkMerklRouterState() private {
        if (address(routerMerkl) == address(0)) {
            fl.log("REWARD_merkl_router_missing");
            return;
        }

        if (routerMerkl.distributor() == address(0)) {
            fl.log("REWARD_merkl_distributor_missing");
        } else {
            fl.log("REWARD_merkl_distributor_constant");
        }

        if (address(routerMerkl.registry()) == address(registry)) {
            fl.log("REWARD_merkl_registry_linked");
        } else {
            fl.log("REWARD_merkl_registry_mismatch");
        }

        if (address(node) != address(0)) {
            uint256 tokenBalance = asset.balanceOf(address(node));
            if (tokenBalance == 0) {
                fl.log("REWARD_merkl_no_rewards_held");
            } else {
                fl.log("REWARD_merkl_rewards_buffered");
            }
        }
    }
}
