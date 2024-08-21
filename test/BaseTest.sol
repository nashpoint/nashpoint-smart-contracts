// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Bestia} from "../src/Bestia.sol";
import {DeployBestia} from "script/DeployBestia.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

contract BaseTest is Test {
    address public constant user1 = address(1);
    address public constant user2 = address(2);
    address public constant user3 = address(3);
    address public constant user4 = address(4);

    uint256 public constant MAX_ALLOWANCE = type(uint256).max;
    uint256 public constant START_BALANCE = 1000e18;
    uint256 public constant DEPOSIT_100 = 100e18;
    uint256 public constant DEPOSIT_10 = 10e18;
    uint256 public constant DEPOSIT_1 = 1e18;

    Bestia public bestia;
    HelperConfig public helperConfig;
    ERC20Mock public usdc;
    ERC4626Mock public vaultA;
    ERC4626Mock public vaultB;
    ERC4626Mock public vaultC;
    ERC7540Mock public liquidityPool;

    address public banker;
    address public manager;

    function setUp() public {
        DeployBestia deployer = new DeployBestia();
        (bestia, helperConfig) = deployer.run();

        (
            address managerAddress,
            address bankerAddress,
            address usdcAddress,
            address vaultAAddress,
            address vaultBAddress,
            address vaultCAddress,
            address liquidityPoolAddress
        ) = helperConfig.activeNetworkConfig();

        banker = bankerAddress;
        manager = managerAddress;
        usdc = ERC20Mock(usdcAddress);
        vaultA = ERC4626Mock(vaultAAddress);
        vaultB = ERC4626Mock(vaultBAddress);
        vaultC = ERC4626Mock(vaultCAddress);
        liquidityPool = ERC7540Mock(liquidityPoolAddress);

        vm.startPrank(user1);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.approve(address(liquidityPool), type(uint256).max);
        usdc.mint(user1, START_BALANCE);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.approve(address(liquidityPool), type(uint256).max);
        usdc.mint(user2, START_BALANCE);
        vm.stopPrank();

        vm.startPrank(user3);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.approve(address(liquidityPool), type(uint256).max);
        usdc.mint(user3, START_BALANCE);
        vm.stopPrank();

        vm.startPrank(user4);
        usdc.approve(address(bestia), type(uint256).max);
        usdc.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.approve(address(liquidityPool), type(uint256).max);
        usdc.mint(user4, START_BALANCE);
        vm.stopPrank();

        vm.startPrank(address(bestia));
        usdc.approve(address(vaultA), type(uint256).max);
        usdc.approve(address(vaultB), type(uint256).max);
        usdc.approve(address(vaultC), type(uint256).max);
        usdc.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.approve(address(liquidityPool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(address(manager));
        usdc.approve(address(liquidityPool), type(uint256).max);
        usdc.mint(manager, START_BALANCE);
        liquidityPool.requestDeposit(DEPOSIT_100, address(manager), address(manager));
        liquidityPool.processPendingDeposits();
        liquidityPool.mint(DEPOSIT_100, address(manager));
    }
}
