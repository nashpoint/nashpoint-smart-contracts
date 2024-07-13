// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Issuer} from "../../src/Issuer.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
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

    // CONTRACTS
    Issuer public immutable bestia;
    MockERC20 public immutable usdc;

    constructor() {
        usdc = new MockERC20("Mock USDC", "USDC");
        bestia = new Issuer(address(usdc), "Bestia", "BEST");
    }

    function setUp() public {
        vm.startPrank(user1);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.mint(user1, BALANCE);
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(user1);
        bestia.deposit(BALANCE, address(user1));
        vm.stopPrank();

        uint256 shares = bestia.balanceOf(user1);

        assertEq(usdc.balanceOf(address(bestia)), BALANCE);
        assertEq(bestia.convertToAssets(shares), BALANCE);
    }

    function testTotalAssets() public {
        vm.startPrank(user1);
        bestia.deposit(BALANCE, address(user1));
        vm.stopPrank();

        assertEq(bestia.totalAssets(), BALANCE);
    }

    function testMath() public {
        vm.startPrank(user1);
        bestia.deposit(BALANCE, address(user1));
        vm.stopPrank();

        uint256 _totalAssets = bestia.totalAssets();
        uint256 _targetReserve = bestia.getTargetReserve();
        assertEq(_totalAssets, _targetReserve * 10);
    }
}
