// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

library MathLib {
    uint256 constant WAD = 1e18;

    function withinRange(uint256 expectedValue, uint256 actualValue, uint256 allowedDeviation)
        internal
        pure
        returns (bool)
    {
        uint256 upperBound = expectedValue * (WAD + allowedDeviation) / WAD;
        uint256 lowerBound = expectedValue * (WAD - allowedDeviation) / WAD;
        return lowerBound <= actualValue && actualValue <= upperBound;
    }

    function pow10(uint8 n) internal pure returns (uint256) {
        return 10 ** n;
    }
}
