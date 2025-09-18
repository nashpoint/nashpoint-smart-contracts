// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

interface IManagement {
    function isContractManager(address manager) external view returns (bool);
    function isWhiteInvestor(address investor) external view returns (bool);
    function isRestrictInvestor(address investor) external view returns (bool);
    function isWhiteContract(address contractAddress) external view returns (bool);
    function isBlockInvestor(address investor) external view returns (bool);
}

interface ISubRedManagement {
    event Subscribe(address indexed from, address stToken, address currencyToken, address investor, uint256 amount);

    event Redeem(address indexed from, address stToken, address currencyToken, address investor, uint256 quantity);

    event SettleSubscriber(
        address indexed from,
        address stToken,
        address[] investorList,
        uint256[] quantityList,
        address[] currencyTokenList,
        uint256[] amountList,
        uint256[] feeList
    );

    event SettleRedemption(
        address indexed from,
        address stToken,
        address[] investorList,
        uint256[] quantityList,
        address[] currencyTokenList,
        uint256[] amountList,
        uint256[] feeList
    );

    function management() external view returns (address);
    function subscribe(address stToken, address currencyToken, uint256 amount, uint256 deadline) external;
    function redeem(address stToken, address currencyToken, uint256 quantity, uint256 deadline) external;
    function settleSubscriber(
        address stToken,
        address[] memory investorList,
        uint256[] memory quantityList,
        address[] memory currencyTokenList,
        uint256[] memory amountList,
        uint256[] memory feeList
    ) external;
    function settleRedemption(
        address stToken,
        address[] memory investorList,
        uint256[] memory quantityList,
        address[] memory currencyTokenList,
        uint256[] memory amountList,
        uint256[] memory feeList
    ) external;
}

interface IDFeedPriceOracle {
    function decimals() external view returns (uint8);

    function updatedAt() external view returns (uint256);

    function getPrice() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            // always zero
            uint80 roundId,
            int256 answer,
            // same as updatedAt
            uint256 startedAt,
            uint256 updatedAt,
            // always zero
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            // always zero
            uint80 roundId,
            int256 answer,
            // same as updatedAt
            uint256 startedAt,
            uint256 updatedAt,
            // always zero
            uint80 answeredInRound
        );
}

interface ISecurityToken {
    function issue(address investor, uint256 value) external;
    function redeem(address investor, uint256 value) external;
    function balanceOf(address who) external view returns (uint256);
    function decimals() external view returns (uint8);
}
