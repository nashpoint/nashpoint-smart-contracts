// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC7540Mock} from "test/mocks/ERC7540Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Deployer} from "script/Deployer.sol";

import {Node} from "src/Node.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ERC7540Router} from "src/routers/ERC7540Router.sol";
import {Escrow} from "src/Escrow.sol";

import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {INodeFactory, DeployParams} from "src/interfaces/INodeFactory.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
import {IQuoterV1} from "src/interfaces/IQuoterV1.sol";

import {MathLib} from "src/libraries/MathLib.sol";

contract BaseTest is Test {
    using MathLib for uint256;

    Deployer public deployer;
    INodeRegistry public registry;
    INodeFactory public factory;
    IQuoterV1 public quoter;
    ERC4626Router public router4626;
    ERC7540Router public router7540;

    INode public node;
    IEscrow public escrow;
    IERC20 public asset;
    ERC4626Mock public vault;
    ERC7540Mock public liquidityPool;

    address public owner;
    address public user;
    address public user2;
    address public user3;
    address public randomUser;
    address public rebalancer;
    address public vaultSeeder;
    address public testPoolManager;
    address public protocolFeesAddress;
    uint256 public constant INITIAL_BALANCE = 1_000_000 ether;
    bytes32 public constant SALT = bytes32(uint256(1));

    address constant usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant usdcEthereum = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public virtual {
        // warp forward one day to avoid underflow in initialize() setting lastRebalance
        vm.warp(block.timestamp + 1 days);

        owner = makeAddr("owner");
        user = makeAddr("user");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        randomUser = makeAddr("randomUser");
        rebalancer = makeAddr("rebalancer");
        vaultSeeder = makeAddr("vaultSeeder");
        testPoolManager = makeAddr("testPoolManager");
        protocolFeesAddress = makeAddr("protocolFeesAddress");

        deployer = new Deployer();
        deployer.deploy(owner);

        registry = INodeRegistry(address(deployer.registry()));
        factory = INodeFactory(address(deployer.factory()));
        quoter = IQuoterV1(address(deployer.quoter()));
        router4626 = deployer.erc4626router();
        router7540 = deployer.erc7540router();

        if (block.chainid == 42161) {
            asset = IERC20(usdcArbitrum);
            vault = new ERC4626Mock(address(asset));
        } else if (block.chainid == 1) {
            asset = IERC20(usdcEthereum);
            vault = new ERC4626Mock(address(asset));
        } else {
            asset = new ERC20Mock("Test Token", "TEST");
            vault = new ERC4626Mock(address(asset));
            liquidityPool = new ERC7540Mock(IERC20(asset), "Mock", "MOCK", testPoolManager);
        }

        vm.startPrank(owner);
        registry.initialize(
            _toArray(address(factory)),
            _toArrayTwo(address(router4626), address(router7540)),
            _toArray(address(quoter)),
            _toArray(address(rebalancer)),
            protocolFeesAddress,
            0,
            0
        );
        quoter.setErc4626(address(vault), true);
        router4626.setWhitelistStatus(address(vault), true);

        DeployParams memory params = DeployParams({
            name: "Test Node",
            symbol: "TNODE",
            asset: address(asset),
            owner: owner,
            rebalancer: address(rebalancer),
            quoter: address(quoter),
            routers: _toArrayTwo(address(router4626), address(router7540)),
            components: _toArray(address(vault)),
            componentAllocations: _defaultComponentAllocations(1),
            reserveAllocation: _defaultReserveAllocation(),
            salt: SALT
        });

        (node, escrow) = factory.deployFullNode(params);

        escrow.approveMax(address(asset), address(node));
        node.setMaxDepositSize(1e36);
        vm.stopPrank();

        deal(address(asset), user, INITIAL_BALANCE);
        deal(address(asset), user2, INITIAL_BALANCE);
        deal(address(asset), user3, INITIAL_BALANCE);
        deal(address(asset), randomUser, INITIAL_BALANCE);
        deal(address(asset), vaultSeeder, INITIAL_BALANCE);

        _labelAddresses();
        vm.label(address(vault), "Vault");

        // warp forward one day to pass rebalance window & cooldown
        vm.warp(block.timestamp + 1 days);

        vm.prank(rebalancer);
        node.startRebalance();
    }

    function _toArray(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }

    function _toArrayTwo(address addr1, address addr2) internal pure returns (address[] memory arr) {
        arr = new address[](2);
        arr[0] = addr1;
        arr[1] = addr2;
    }

    function _defaultComponentAllocations(uint256 count)
        internal
        pure
        returns (ComponentAllocation[] memory allocations)
    {
        allocations = new ComponentAllocation[](count);
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = ComponentAllocation({targetWeight: 0.9 ether, maxDelta: 0.01 ether, isComponent: true});
        }
    }

    function _defaultReserveAllocation() internal pure returns (ComponentAllocation memory) {
        return ComponentAllocation({targetWeight: 0.1 ether, maxDelta: 0.01 ether, isComponent: true});
    }

    function _labelAddresses() internal {
        vm.label(address(registry), "Registry");
        vm.label(address(factory), "Factory");
        vm.label(address(quoter), "Quoter");
        vm.label(address(router4626), "ERC4626Router");
        vm.label(address(router7540), "ERC7540Router");
        vm.label(address(node), "Node");
        vm.label(address(escrow), "Escrow");
        vm.label(address(asset), "Asset");
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(user2, "User2");
        vm.label(user3, "User3");
        vm.label(randomUser, "RandomUser");
        vm.label(rebalancer, "Rebalancer");
        vm.label(vaultSeeder, "vaultSeeder");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getCurrentReserveRatio() public view returns (uint256 reserveRatio) {
        uint256 currentReserveRatio = MathLib.mulDiv(asset.balanceOf(address(node)), 1e18, node.totalAssets());

        return (currentReserveRatio);
    }

    function _seedNode(uint256 amount) public {
        deal(address(asset), address(vaultSeeder), amount);
        vm.startPrank(vaultSeeder);
        asset.approve(address(node), amount);
        node.deposit(amount, vaultSeeder);
        vm.stopPrank();
    }

    function _seedERC4626(address component, uint256 amount) public {
        deal(address(asset), address(vaultSeeder), type(uint256).max);
        vm.startPrank(vaultSeeder);
        asset.approve(component, amount);
        ERC4626Mock(component).deposit(amount, vaultSeeder);
        vm.stopPrank();
    }

    function _seedERC7540(address component, uint256 amount) public {
        deal(address(asset), address(vaultSeeder), type(uint256).max);
        vm.startPrank(vaultSeeder);
        asset.approve(component, amount);
        ERC7540Mock(component).requestDeposit(amount, vaultSeeder, vaultSeeder);
        vm.stopPrank();
    }

    function _userDeposits(address user_, uint256 amount_) internal returns (uint256 shares) {
        vm.startPrank(user_);
        asset.approve(address(node), amount_);
        shares = node.deposit(amount_, user_);
        vm.stopPrank();
    }

    function _userRequestsRedeem(address user_, uint256 sharesToRedeem_) internal {
        vm.startPrank(user);
        node.approve(address(node), sharesToRedeem_);
        node.requestRedeem(sharesToRedeem_, user_, user_);
        vm.stopPrank();
    }

    function _userRedeemsAndClaims(address user_, uint256 sharesToRedeem_, address node_)
        internal
        returns (uint256 claimableAssets)
    {
        vm.startPrank(user_);
        INode(node_).approve(node_, sharesToRedeem_);
        INode(node_).requestRedeem(sharesToRedeem_, user_, user_);
        vm.stopPrank();

        vm.startPrank(rebalancer);
        INode(node_).fulfillRedeemFromReserve(user_);
        vm.stopPrank();

        claimableAssets = INode(node_).maxWithdraw(user_);

        vm.prank(user);
        INode(node_).withdraw(claimableAssets, user, user);
    }

    function _setAllocationToAsyncVault(address liquidityPool_, uint64 allocation) internal {
        vm.startPrank(owner);
        uint64 reserveAllocation = 1 ether - allocation;
        node.updateReserveAllocation(
            ComponentAllocation({targetWeight: reserveAllocation, maxDelta: 0, isComponent: true})
        );
        node.updateComponentAllocation(
            address(vault), ComponentAllocation({targetWeight: 0, maxDelta: 0, isComponent: true})
        );
        node.removeComponent(address(vault));
        node.addComponent(
            address(liquidityPool_), ComponentAllocation({targetWeight: allocation, maxDelta: 0, isComponent: true})
        );
        quoter.setErc7540(address(liquidityPool_), true);
        router7540.setWhitelistStatus(address(liquidityPool_), true);
        vm.stopPrank();
    }
}
