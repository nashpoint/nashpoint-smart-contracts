// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OneInchMock {
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address receiver) external {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(receiver, amountOut);
    }
}
