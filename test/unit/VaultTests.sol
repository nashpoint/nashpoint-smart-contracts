// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Issuer} from "../../src/Issuer.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
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
    ERC20Mock public immutable usdc;
    ERC4626Mock public immutable sUSDC;

    constructor() {
        usdc = new ERC20Mock("Mock USDC", "USDC");
        sUSDC = new ERC4626Mock(address(usdc));
        bestia = new Issuer(address(usdc), "Bestia", "BEST", address(sUSDC), address(banker));
    }

    function setUp() public {
        vm.startPrank(user1);
        usdc.approve(address(bestia), type(uint256).max);
        bestia.approve(address(bestia), type(uint256).max);
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
        expectedCashReserve = bestia.totalAssets() * bestia.targetReserveRatio() / 1e18;
        assertEq(usdc.balanceOf(address(bestia)), expectedCashReserve);

        // test large deposit of 1000e18 (about 10x total assets)
        vm.startPrank(user3);
        bestia.deposit(BALANCE, address(user3));
        vm.stopPrank();

        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // asserts cash reserve == target reserve
        expectedCashReserve = bestia.totalAssets() * bestia.targetReserveRatio() / 1e18;
        assertEq(usdc.balanceOf(address(bestia)), expectedCashReserve);
    }

    function testGetSwingFactor() public {
        // reverts on withdrawal exceeds available reserve
        vm.expectRevert();
        bestia.getSwingFactor(0);

        vm.expectRevert();
        bestia.getSwingFactor(-1e16);

        // assert swing factor is zero if reserve target is met or exceeded
        uint256 swingFactor = bestia.getSwingFactor(int256(bestia.targetReserveRatio()));
        assertEq(swingFactor, 0);

        swingFactor = bestia.getSwingFactor(int256(bestia.targetReserveRatio()) + 1e16);
        assertEq(swingFactor, 0);

        // assert that swing factor approaches maxDiscount when reserve approaches zero
        int256 minReservePossible = 1;
        swingFactor = bestia.getSwingFactor(minReservePossible);
        assertEq(swingFactor, bestia.maxDiscount() - 1);

        // assert that 0 < swing factor < 0.1% when reserve approaches
        int256 maxReservePossible = int256(bestia.targetReserveRatio()) - 1;
        swingFactor = bestia.getSwingFactor(maxReservePossible);
        assertGt(swingFactor, 0);
        assertLt(swingFactor, 1e15); // 0.1%
    }

    function testAdjustedWithdraw() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT, address(user1));
        vm.stopPrank();

        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = Math.mulDiv(usdc.balanceOf(address(bestia)), 1e18, bestia.totalAssets());
        assertEq(reserveRatio, bestia.targetReserveRatio());

        // mint cash so invested assets = 100
        usdc.mint(address(sUSDC), 10e18 + 1);

        console2.log("usdc.balanceOf(address(bestia)))", usdc.balanceOf(address(bestia)) / 1e18);
        console2.log("bestia.totalAssets())", bestia.totalAssets() / 1e18);
        console2.log("sUSDC.totalAssets()", sUSDC.totalAssets() / 1e18);

        vm.startPrank(user1);
        uint256 startingBalanceBestia = bestia.balanceOf(address(user1));
        uint256 startingBalanceUSDC = usdc.balanceOf(address(user1));
        bestia.adjustedWithdraw(1e18, address(user1), address(user1));
        uint256 closingBalanceBestia = bestia.balanceOf(address(user1));
        uint256 closingBalanceUSDC = usdc.balanceOf(address(user1)) - startingBalanceUSDC;
        vm.stopPrank();

        // console2.log("closingBalanceBestia", closingBalanceBestia);
        console2.log("closingBalance", closingBalanceUSDC);
        console2.log("startingBalanceBestia", startingBalanceBestia);
        console2.log("closingBalanceBestia", closingBalanceBestia);
    }
}
