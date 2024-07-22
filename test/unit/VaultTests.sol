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

    uint256 public constant START_BALANCE = 1000e18;
    uint256 public constant DEPOSIT_100 = 100e18;
    uint256 public constant DEPOSIT_10 = 10e18;

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
        usdc.mint(user1, START_BALANCE);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(bestia), type(uint256).max);
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

    function testDeposit() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        uint256 shares = bestia.balanceOf(user1);

        assertEq(usdc.balanceOf(address(bestia)), DEPOSIT_100);
        assertEq(bestia.convertToAssets(shares), DEPOSIT_100);
    }

    function testTotalAssets() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        assertEq(bestia.totalAssets(), DEPOSIT_100);
    }

    function testInvestCash() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // test that the cash reserve after investCash == the targetReserveRatio
        uint256 expectedCashReserve = DEPOSIT_100 * bestia.targetReserveRatio() / 1e18;
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
        bestia.deposit(START_BALANCE, address(user3));
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

        // assert that 0.0% < swing factor < 0.1% when reserve approaches
        int256 maxReservePossible = int256(bestia.targetReserveRatio()) - 1;
        swingFactor = bestia.getSwingFactor(maxReservePossible);
        assertGt(swingFactor, 0);
        assertLt(swingFactor, 1e15); // 0.1%
    }

    function testAdjustedWithdraw() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = getCurrentReserveRatio();
        assertEq(reserveRatio, bestia.targetReserveRatio());

        // mint cash so invested assets = 100
        usdc.mint(address(sUSDC), 10e18 + 1);

        // user 2 deposits 10e18 to bestia and burns the rest of their usdc
        vm.startPrank(user2);
        bestia.deposit(DEPOSIT_10, address(user2));
        usdc.transfer(0x000000000000000000000000000000000000dEaD, usdc.balanceOf(address(user2)));
        vm.stopPrank();

        // assert user2 has zero usdc balance
        assertEq(usdc.balanceOf(address(user2)), 0);

        // banker invests excess reserve
        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // user 2 withdraws the same amount they deposited
        // TODO: subtracting 1 (DEPOSIT_10 - 1) prob introduces a bug. fix later
        vm.startPrank(user2);
        bestia.adjustedWithdraw(DEPOSIT_10 - 1, address(user2), address(user2));

        // assert that user2 has burned all shares to withdraw max usdc
        uint256 user2BestiaClosingBalance = bestia.balanceOf(address(user2));
        assertEq(user2BestiaClosingBalance, 0);

        // assert that user2 received less USDC back than they deposited
        uint256 usdcReturned = usdc.balanceOf(address(user2));
        assertLt(usdcReturned, DEPOSIT_10);

        console2.log("delta :", DEPOSIT_10 - usdcReturned);

        // this test does not check if the correct amount was returned
        // only that is was less than originally deposited
        // check for correct swing factor is in that test
    }

    function testAdjustedDeposit() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // assert reserveRatio is correct before other tests
        uint256 reserveRatio = getCurrentReserveRatio();
        assertEq(reserveRatio, bestia.targetReserveRatio());

        // mint cash so invested assets = 100
        usdc.mint(address(sUSDC), 10e18 + 1);

        // get the shares to be minted from a tx with no swing factor
        // this will break later when you complete 4626 conversion
        uint256 nonAdjustedShares = bestia.previewDeposit(DEPOSIT_10);

        // user 2 deposits 10e18 to bestia
        vm.startPrank(user2);
        bestia.adjustedDeposit(DEPOSIT_10, address(user2));
        vm.stopPrank();

        // TEST 1: assert that no swing factor is applied when reserve ratio exceeds target

        // get the reserve ratio after the deposit and assert it is greater than target reserve ratio
        uint256 reserveRatioAfterTX = getCurrentReserveRatio();
        assertGt(reserveRatioAfterTX, bestia.targetReserveRatio());

        // get the actual shares received and assert they are the same i.e. no swing factor applied
        uint256 sharesReceived = bestia.balanceOf(address(user2));
        assertEq(sharesReceived, nonAdjustedShares);

        // invest cash to return reserve ratio to 100%
        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        // withdraw usdc to bring reserve ratio below 100%
        vm.startPrank(user2);
        bestia.withdraw(5e18, (address(user2)), address((user2)));
        vm.stopPrank();

        // get the shares to be minted from a deposit with no swing factor applied
        nonAdjustedShares = bestia.previewDeposit(2e18);

        vm.startPrank(user3);
        bestia.adjustedDeposit(2e18, address(user3));
        vm.stopPrank();

        // TEST 2: test that swing factor is applied with reserve ratio is below target

        // get the reserve ratio after the deposit and assert it is less than target reserve ratio
        reserveRatioAfterTX = getCurrentReserveRatio();
        assertLt(reserveRatioAfterTX, bestia.targetReserveRatio());

        // get the actual shares received and assert they are greater than & have swing factor applied
        sharesReceived = bestia.balanceOf(address(user3));
        assertGt(sharesReceived, nonAdjustedShares);
    }

    // HELPER FUNCTIONS
    function getCurrentReserveRatio() public view returns (uint256 reserveRatio) {
        uint256 currentReserveRatio = Math.mulDiv(usdc.balanceOf(address(bestia)), 1e18, bestia.totalAssets());

        return (currentReserveRatio);
    }
}
