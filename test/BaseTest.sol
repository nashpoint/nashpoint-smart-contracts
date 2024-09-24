// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Bestia} from "../src/Bestia.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {DeployBestia} from "script/DeployBestia.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {ERC4626Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC4626Mock.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {IERC7540} from "src/interfaces/IERC7540.sol";
import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud} from "lib/prb-math/src/UD60x18.sol";
import {SD59x18, exp, sd} from "lib/prb-math/src/SD59x18.sol";

// escrow contract for bestia
import {Escrow, IEscrow} from "src/Escrow.sol";

// centrifuge interfaces
import {IInvestmentManager} from "test/interfaces/centrifuge/IInvestmentManager.sol";
import {IPoolManager} from "test/interfaces/centrifuge/IPoolManager.sol";
import {IRestrictionManager} from "test/interfaces/centrifuge/IRestrictionManager.sol";
import {ITranche} from "test/interfaces/centrifuge/ITranche.sol";
import {IGateway} from "test/interfaces/centrifuge/IGateway.sol";

contract BaseTest is Test {
    address public constant user1 = address(1);
    address public constant user2 = address(2);
    address public constant user3 = address(3);
    address public constant user4 = address(4);

    uint256 public constant MAX_ALLOWANCE = type(uint256).max;
    uint256 public constant DECIMALS = 1e6;
    uint256 public constant START_BALANCE_1000 = 1000 * DECIMALS;
    uint256 public constant DEPOSIT_100 = 100 * DECIMALS;
    uint256 public constant DEPOSIT_10 = 10 * DECIMALS;
    uint256 public constant DEPOSIT_1 = 1 * DECIMALS;

    // NashPoint V1 Core Contracts
    Bestia public bestia;
    NodeFactory public nodeFactory;
    Escrow public escrow;

    HelperConfig public helperConfig;
    IERC20 public usdc;
    ERC20Mock public usdcMock;
    ERC4626Mock public vaultA;
    ERC4626Mock public vaultB;
    ERC4626Mock public vaultC;
    IERC7540 public liquidityPool;
    address public banker;
    address public manager;

    // fork test contracts and addresses
    IInvestmentManager public investmentManager;
    IRestrictionManager public restrictionManager;
    IPoolManager public poolManager;
    IGateway public gateway;

    ITranche public share;
    address public root;

    // using this instead of usdc address for mainnet fork tests
    IERC20 public asset;

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
        usdcMock = ERC20Mock(usdcAddress);
        vaultA = ERC4626Mock(vaultAAddress);
        vaultB = ERC4626Mock(vaultBAddress);
        vaultC = ERC4626Mock(vaultCAddress);
        liquidityPool = ERC7540Mock(liquidityPoolAddress);

        //////////// TEMP: ADD IN ESCROW HERE FOR SIMPLICITY OF TESTING ///////////

        // deploy the Escrow contract
        escrow = new Escrow();

        // and config each others addresses
        escrow.setBestia(address(bestia));

        // pranking as banker as bestia owner is the deploy script.
        // TODO: fix this later
        vm.startPrank(banker);
        bestia.setEscrow(address(escrow));
        vm.stopPrank();

        ///////////////////////////////////////////////////////////////////////////

        // get node factory running here
        nodeFactory = new NodeFactory();

        ///////////////////////////////////////////////////////////////////////////

        _setupUserBalancesAndApprovals();
        _setupBestiaApprovals();
        _setupInitialLiquidity();
    }

    // MAINNET SETUP FOR CFG TESTING
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
        // diff 7540 manager from local tests
        usdc = IERC20(usdcAddress);
        vaultA = ERC4626Mock(vaultAAddress);
        vaultB = ERC4626Mock(vaultBAddress);
        vaultC = ERC4626Mock(vaultCAddress);
        liquidityPool = IERC7540(liquidityPoolAddress);

        share = ITranche(0x8c213ee79581Ff4984583C6a801e5263418C4b86);
        restrictionManager = IRestrictionManager(0x4737C3f62Cc265e786b280153fC666cEA2fBc0c0);
        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);
        poolManager = IPoolManager(0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29);
        gateway = IGateway(0x7829E5ca4286Df66e9F58160544097dB517a3B8c);

        root = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;

        // using this instead of usdc address for mainnet fork tests
        asset = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
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
        usdcMock = ERC20Mock(usdcAddress);
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
            usdcMock.approve(address(bestia), MAX_ALLOWANCE);
            usdcMock.approve(address(liquidityPool), MAX_ALLOWANCE);
            usdcMock.approve(address(escrow), MAX_ALLOWANCE);
            liquidityPool.approve(address(liquidityPool), MAX_ALLOWANCE);
            usdcMock.mint(users[i], START_BALANCE_1000);
            bestia.approve(address(bestia), MAX_ALLOWANCE);
            vm.stopPrank();
        }
    }

    function _setupBestiaApprovals() internal {
        vm.startPrank(address(bestia));
        usdcMock.approve(address(vaultA), MAX_ALLOWANCE);
        usdcMock.approve(address(vaultB), MAX_ALLOWANCE);
        usdcMock.approve(address(vaultC), MAX_ALLOWANCE);
        usdcMock.approve(address(liquidityPool), MAX_ALLOWANCE);
        liquidityPool.approve(address(liquidityPool), MAX_ALLOWANCE);
        vm.stopPrank();

        vm.startPrank(address(escrow));
        usdcMock.approve(address(bestia), MAX_ALLOWANCE);
        vm.stopPrank();
    }

    function _setupInitialLiquidity() internal {
        vm.startPrank(address(manager));
        usdcMock.approve(address(liquidityPool), MAX_ALLOWANCE);
        usdcMock.mint(manager, START_BALANCE_1000);
        liquidityPool.requestDeposit(DEPOSIT_100, address(manager), address(manager));
        liquidityPool.processPendingDeposits();
        liquidityPool.mint(DEPOSIT_100, address(manager));
        vm.stopPrank();
    }

    function bankerInvestsCash(address _component) public {
        vm.startPrank(banker);
        bestia.investInSynchVault(_component);
        vm.stopPrank();
    }

    function bankerInvestsInAsyncVault(address _component) public {
        vm.startPrank(banker);
        bestia.investInAsyncVault(address(_component));
        vm.stopPrank();
    }

    function seedBestia() public {
        // SET THE STRATEGY
        // add the 4626 Vaults
        bestia.addComponent(address(vaultA), 18e16, false, address(vaultA));
        bestia.addComponent(address(vaultB), 20e16, false, address(vaultB));
        bestia.addComponent(address(vaultC), 22e16, false, address(vaultC));

        // add the 7540 Vault (RWA)
        bestia.addComponent(address(liquidityPool), 30e16, true, address(liquidityPool));

        // SEED VAULT WITH 100 UNITS
        vm.startPrank(user1);
        bestia.deposit(DEPOSIT_100, address(user1));
        vm.stopPrank();

        // banker rebalances into illiquid vault
        bankerInvestsInAsyncVault(address(liquidityPool));

        // banker rebalances bestia instant vaults
        bankerInvestsCash(address(vaultA));
        bankerInvestsCash(address(vaultB));
        bankerInvestsCash(address(vaultC));
    }
}
