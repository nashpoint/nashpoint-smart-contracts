// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Issuer} from "../../src/Issuer.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {ERC4626Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC4626Mock.sol";
import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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

    function testBasicMath() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT, address(user1));
        vm.stopPrank();

        uint256 _totalAssets = bestia.totalAssets();
        uint256 _targetReserve = bestia.getTargetReserve();
        uint256 _maxDiscount = bestia.getMaxDiscount();

        assertEq(_totalAssets, _targetReserve * 100 / bestia.targetReserveRatio());
        assertEq(_totalAssets, _maxDiscount * 100 / bestia.maxDiscount());
    }

    function testBestiaCanStake() public {
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT, address(user1));
        vm.stopPrank();

        vm.startPrank(banker);
        uint256 targetReserve = bestia.getTargetReserve();
        bestia.investCash();
        vm.stopPrank();

        assertEq(sUSDC.balanceOf(address(bestia)), DEPOSIT - targetReserve);
    }

    function testGetReservePercent() public {
        // user1 deposits 100 USDC
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT, address(user1));
        vm.stopPrank();

        // banker invests 90 USDC
        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        uint256 investedAssets = sUSDC.totalAssets();
        console2.log("sUSDC Assets", investedAssets);

        vm.startPrank(user1);
        bestia.withdraw(DEPOSIT / 20, address(user1), address(user1));
        vm.stopPrank();

        uint256 currentReserve = usdc.balanceOf(address(bestia));
        uint256 assets = bestia.totalAssets();
        uint256 reservePercent = bestia.getReservePercent();

        console2.log("Bestia currentReserve", currentReserve);
        console2.log("Bestia totalAssets", assets);
        console2.log("Bestia reservePercent", reservePercent);

        assertEq(reservePercent, Math.mulDiv(currentReserve, 1e18, assets));
    }

    function testGetRemainingReservePercent() public {
        // user1 deposits 100 USDC
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT, address(user1));
        vm.stopPrank();

        // banker invests 90 USDC
        vm.startPrank(banker);
        bestia.investCash();
        vm.stopPrank();

        vm.startPrank(user1);
        bestia.withdraw(DEPOSIT / 20, address(user1), address(user1));
        vm.stopPrank();

        uint256 remainingReserve = bestia.getRemainingReservePercent();
        console2.log("Bestia remainingReserve", remainingReserve);

        assertEq(remainingReserve, 1e18 - bestia.getReservePercent());
        assertEq(1e18, bestia.getReservePercent() + remainingReserve);
    }
}
