// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

contract SubRedManagementMock is Ownable {
    using SafeERC20 for IERC20;

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

    mapping(address => bool) public managers;
    mapping(address => bool) public whitelist;

    constructor() Ownable(msg.sender) {}

    function setManager(address manager, bool allowed) external onlyOwner {
        managers[manager] = allowed;
    }

    function setWhitelist(address user, bool allowed) external onlyOwner {
        whitelist[user] = allowed;
    }

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }

    modifier onlyManager() {
        require(managers[msg.sender], "Not whitelisted manager");
        _;
    }

    function subscribe(address stToken, address currencyToken, uint256 amount, uint256 deadline)
        external
        onlyWhitelisted
    {
        require(amount > 0, "The subscription amount cannot be zero");
        IERC20(currencyToken).safeTransferFrom(msg.sender, address(this), amount);
        ERC20Mock(stToken).mint(msg.sender, amount);
        emit Subscribe(address(this), stToken, currencyToken, msg.sender, amount);
    }

    function redeem(address stToken, address currencyToken, uint256 quantity, uint256 deadline)
        external
        onlyWhitelisted
    {
        require(quantity > 0, "quantity > 0");
        IERC20(stToken).safeTransferFrom(msg.sender, address(this), quantity);
        emit Redeem(address(this), stToken, currencyToken, msg.sender, quantity);
    }

    function settleSubscriber(
        address stToken,
        address[] memory investorList,
        uint256[] memory quantityList,
        address[] memory currencyTokenList,
        uint256[] memory amountList,
        uint256[] memory feeList
    ) external onlyManager {
        for (uint256 i = 0; i < investorList.length; i++) {
            if (quantityList[i] > 0) {
                IERC20(stToken).safeTransfer(investorList[i], quantityList[i]);
            }
            if (amountList[i] > 0) {
                IERC20(currencyTokenList[i]).safeTransfer(investorList[i], amountList[i]);
            }
        }
        emit SettleSubscriber(
            address(this), stToken, investorList, quantityList, currencyTokenList, amountList, feeList
        );
    }

    function settleRedemption(
        address stToken,
        address[] memory investorList,
        uint256[] memory quantityList,
        address[] memory currencyTokenList,
        uint256[] memory amountList,
        uint256[] memory feeList
    ) external onlyManager {
        for (uint256 i = 0; i < currencyTokenList.length; i++) {
            if (quantityList[i] > 0) {
                IERC20(stToken).safeTransfer(investorList[i], quantityList[i]);
            }
            if (amountList[i] - feeList[i] > 0) {
                IERC20(currencyTokenList[i]).safeTransfer(investorList[i], amountList[i] -= feeList[i]);
            }
        }
        emit SettleRedemption(
            address(this), stToken, investorList, quantityList, currencyTokenList, amountList, feeList
        );
    }

    function rescueToken(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, balance);
    }
}
