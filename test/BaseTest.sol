// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Bestia} from "../src/Bestia.sol";
import {DeployBestia} from "script/DeployBestia.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC4626Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {IERC7540} from "src/interfaces/IERC7540.sol";
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
    uint256 public constant START_BALANCE_1000 = 1000e18;
    uint256 public constant DEPOSIT_100 = 100e18;
    uint256 public constant DEPOSIT_10 = 10e18;
    uint256 public constant DEPOSIT_1 = 1e18;

    Bestia public bestia;
    HelperConfig public helperConfig;
    ERC20Mock public usdc;
    ERC4626Mock public vaultA;
    ERC4626Mock public vaultB;
    ERC4626Mock public vaultC;
    IERC7540 public liquidityPool;
    // ERC7540Mock public liquidityPool;

    address public banker;
    address public manager;

    function setUp() public {
        if (block.chainid == 1) {
            _setupMainnet();
        } else if (block.chainid == 42161) {
            _setupArbitrumSepolia();
        } else {
            _setupLocalAnvil();
        }
    }

    function _setupLocalAnvil() internal {
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

        _setupUserBalancesAndApprovals();
        _setupBestiaApprovals();
        _setupInitialLiquidity();
    }

    function _setupMainnet() internal {
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
        liquidityPool = IERC7540(liquidityPoolAddress);
    }

    function _setupArbitrumSepolia() internal {
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

        _setupUserBalancesAndApprovals();
        _setupBestiaApprovals();
        _setupInitialLiquidity();
    }

    // Helper functions for setup
    function _setupUserBalancesAndApprovals() internal {
        address[] memory users = new address[](4);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        users[3] = user4;

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            usdc.approve(address(bestia), MAX_ALLOWANCE);
            usdc.approve(address(liquidityPool), MAX_ALLOWANCE);
            liquidityPool.approve(address(liquidityPool), MAX_ALLOWANCE);
            usdc.mint(users[i], START_BALANCE_1000);
            vm.stopPrank();
        }
    }

    function _setupBestiaApprovals() internal {
        vm.startPrank(address(bestia));
        usdc.approve(address(vaultA), MAX_ALLOWANCE);
        usdc.approve(address(vaultB), MAX_ALLOWANCE);
        usdc.approve(address(vaultC), MAX_ALLOWANCE);
        usdc.approve(address(liquidityPool), MAX_ALLOWANCE);
        liquidityPool.approve(address(liquidityPool), MAX_ALLOWANCE);
        vm.stopPrank();
    }

    function _setupInitialLiquidity() internal {
        vm.startPrank(address(manager));
        usdc.approve(address(liquidityPool), MAX_ALLOWANCE);
        usdc.mint(manager, START_BALANCE_1000);
        liquidityPool.requestDeposit(DEPOSIT_100, address(manager), address(manager));
        liquidityPool.processPendingDeposits();
        liquidityPool.mint(DEPOSIT_100, address(manager));
        vm.stopPrank();
    }
}
