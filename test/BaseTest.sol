// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Issuer} from "../src/Issuer.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

contract BaseTest is Test {
    address public constant user1 = address(0x1);
    address public constant user2 = address(0x2);
    address public constant user3 = address(0x3);
    address public constant user4 = address(0x4);
    address public constant banker = address(0x5);

    uint256 public constant START_BALANCE = 1000e18;
    uint256 public constant DEPOSIT_100 = 100e18;
    uint256 public constant DEPOSIT_10 = 10e18;

    // CONTRACTS
    Issuer public immutable bestia;
    ERC20Mock public immutable usdc;
    ERC4626Mock public immutable sUSDC;
    ERC7540Mock public immutable liquidityPool;

    constructor() {
        usdc = new ERC20Mock("Mock USDC", "USDC");
        sUSDC = new ERC4626Mock(address(usdc));
        bestia = new Issuer(address(usdc), "Bestia", "BEST", address(sUSDC), address(banker));
        liquidityPool = new ERC7540Mock(usdc, "7540 Token", "7540");
    }

    function setUp() public {
        vm.startPrank(user1);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.approve(address(liquidityPool), type(uint256).max);
        usdc.mint(user1, START_BALANCE);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.approve(address(liquidityPool), type(uint256).max);
        usdc.mint(user2, START_BALANCE);
        vm.stopPrank();

        vm.startPrank(user3);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.mint(user3, START_BALANCE);
        vm.stopPrank();

        vm.startPrank(address(bestia));
        usdc.approve(address(sUSDC), type(uint256).max);
        vm.stopPrank();
    }
}
