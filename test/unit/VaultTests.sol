// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Issuer} from "../../src/Issuer.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ERC4626Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC4626Mock.sol";
import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

contract VaultTests is Test {
    address public constant user1 = address(0x1);
    address public constant user2 = address(0x2);
    address public constant user3 = address(0x3);
    address public constant user4 = address(0x4);
    address public constant banker = address(0x5);

    uint256 public constant BALANCE = 1000e18;
    uint256 public constant DEPOSIT = 100e18;

    // CONTRACTS
    Issuer public immutable bestia;
    MockERC20 public immutable usdc;
    ERC4626Mock public immutable sUSDC;

    constructor() {
        usdc = new MockERC20("Mock USDC", "USDC");
        sUSDC = new ERC4626Mock(address(usdc));
        bestia = new Issuer(address(usdc), "Bestia", "BEST", address(sUSDC), address(banker));
    }

    function setUp() public {
        vm.startPrank(user1);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.mint(user1, BALANCE);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.mint(user2, BALANCE);
        vm.stopPrank();

        vm.startPrank(user3);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.mint(user3, BALANCE);
        vm.stopPrank();

        vm.startPrank(address(bestia));
        usdc.approve(address(sUSDC), type(uint256).max);
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT, address(user1));
        vm.stopPrank();

        uint256 shares = bestia.balanceOf(user1);

        assertEq(usdc.balanceOf(address(bestia)), DEPOSIT);
        assertEq(bestia.convertToAssets(shares), DEPOSIT);
    }

    function testTotalAssets() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT, address(user1));
        vm.stopPrank();

        assertEq(bestia.totalAssets(), DEPOSIT);
    }

    function testInvestCash() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT, address(user1));
        vm.stopPrank();

        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // test that the cash reserve after investCash == the targetReserveRatio
        uint256 expectedCashReserve = DEPOSIT * bestia.targetReserveRatio() / 1e18;
        assertEq(usdc.balanceOf(address(bestia)), expectedCashReserve);

        // remove some cash from reserve
        vm.startPrank(user1);
        bestia.withdraw(2e18, address(user1), address(user1));
        vm.stopPrank();

        // mint cash so invested assets = 100
        usdc.mint(address(sUSDC), 10e18 + 1);

        // expect revert
        vm.startPrank(banker);
        vm.expectRevert(); // error CashBelowTargetRatio();
        bestia.investCash();
        vm.stopPrank();

        // user 2 deposits 4 tokens to bring cash reserve to 12 tokens
        vm.startPrank(user2);
        bestia.deposit(4e18, address(user2));
        vm.stopPrank();

        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // asserts cash reserve == target reserve
        expectedCashReserve = bestia.totalAssets() * bestia.targetReserveRatio() / 1e18;        assertEq(usdc.balanceOf(address(bestia)), expectedCashReserve);

        // test large deposit of 1000e18 (about 10x total assets)
        vm.startPrank(user3);
        bestia.deposit(BALANCE, address(user3));
        vm.stopPrank();

        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // asserts cash reserve == target reserve
        expectedCashReserve = bestia.totalAssets() * bestia.targetReserveRatio() / 1e18;        assertEq(usdc.balanceOf(address(bestia)), expectedCashReserve);
    }
}
