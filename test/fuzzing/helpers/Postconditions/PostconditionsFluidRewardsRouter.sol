// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

import {FluidDistributorMock} from "../../../mocks/FluidDistributorMock.sol";

contract PostconditionsFluidRewardsRouter is PostconditionsBase {
    function fluidClaimPostconditions(bool success, bytes memory returnData, FluidClaimParams memory params) internal {
        if (params.shouldSucceed) {
            // fl.t(success, "FLUID_CLAIM_SUCCESS");

            (
                address recipient,
                uint256 cumulativeAmount,
                uint8 positionType,
                bytes32 positionId,
                uint256 cycle,
                bytes32 proofHash
            ) = FluidDistributorMock(address(fluidDistributor)).lastClaimInfo();

            // fl.eq(recipient, address(node), "FLUID_CLAIM_RECIPIENT");
            // fl.eq(cumulativeAmount, params.cumulativeAmount, "FLUID_CLAIM_AMOUNT");
            // fl.eq(positionType, uint8(1), "FLUID_CLAIM_POSITION_TYPE");
            // fl.t(positionId == params.positionId, "FLUID_CLAIM_POSITION_ID");
            // fl.eq(cycle, params.cycle, "FLUID_CLAIM_CYCLE");
            // fl.t(proofHash == params.proofHash, "FLUID_CLAIM_PROOF");

            uint256 recorded = FluidDistributorMock(address(fluidDistributor)).getClaimed(address(node), positionId);
            // fl.eq(recorded, params.cumulativeAmount, "FLUID_CLAIM_RECORDED");

            onSuccessInvariantsGeneral(returnData);
        } else {
            // fl.t(!success, "FLUID_CLAIM_SHOULD_REVERT");
            onFailInvariantsGeneral(returnData);
        }
    }
}
