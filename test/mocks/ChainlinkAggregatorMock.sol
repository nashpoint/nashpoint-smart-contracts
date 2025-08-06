// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IChainlinkAccessControlAggregator {
    function minAnswer() external view returns (int192);
    function maxAnswer() external view returns (int192);
}

contract AggregatorMock is IChainlinkAccessControlAggregator {
    int192 min = 0;
    int192 max = type(int192).max;

    function minAnswer() external view returns (int192) {
        return min;
    }

    function maxAnswer() external view returns (int192) {
        return max;
    }
}

contract ChainlinkAggregatorMock {
    uint80 public roundId;
    int256 public answer;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound;

    uint8 public decimals = 8;

    IChainlinkAccessControlAggregator public aggregator;

    constructor(address aggregator_) {
        aggregator = IChainlinkAccessControlAggregator(aggregator_);
    }

    function setLatestRoundData(
        uint80 roundId_,
        int256 answer_,
        uint256 startedAt_,
        uint256 updatedAt_,
        uint80 answeredInRound_
    ) external {
        roundId = roundId_;
        answer = answer_;
        startedAt = startedAt_;
        updatedAt = updatedAt_;
        answeredInRound = answeredInRound_;
    }

    function setAnswer(int256 answer_) external {
        answer = answer_;
    }

    function setUpdatedAt(uint256 updatedAt_) external {
        updatedAt = updatedAt_;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
