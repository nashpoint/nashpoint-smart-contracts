// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// Test utils
import "forge-std/Test.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

// Core contracts
import {Node} from "src/Node.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {Escrow} from "src/Escrow.sol";
import {QueueManager} from "src/QueueManager.sol";
import {Quoter} from "src/Quoter.sol";
import {ERC4626Rebalancer} from "src/rebalancers/ERC4626Rebalancer.sol";
// Interfaces
import {INode} from "src/interfaces/INode.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";
import {IQuoter} from "src/interfaces/IQuoter.sol";
import {IERC4626Rebalancer} from "src/interfaces/IERC4626Rebalancer.sol";
// Mocks
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract BaseTest is Test {
    // Core contracts
    NodeFactory public nodeFactory;
    INode public node;
    IEscrow public escrow;
    IQuoter public quoter;
    IQueueManager public queueManager;
    IERC4626Rebalancer public erc4626Rebalancer;
    
    // Mock tokens
    ERC20Mock public erc20;

    // Common addresses
    address public self = address(this);
    address public deployer = makeAddr("deployer");
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public randomUser = makeAddr("randomUser");
    
    // Constants
    uint128 public constant MAX_UINT128 = type(uint128).max;
    uint256 public constant INITIAL_BALANCE = 1000000 ether;

    function setUp() public virtual {
        vm.chainId(1);
        vm.startPrank(deployer);

        // Deploy mock token
        erc20 = new ERC20Mock("Test Token", "TEST");
        
        // Deploy core contracts
        nodeFactory = new NodeFactory();

        console.log(owner);
        
        // Deploy full node setup
        (node, escrow, quoter, queueManager, erc4626Rebalancer) = deployFullNode(
            address(erc20),
            "Test Node",
            "TNODE",
            owner
        );
        
        // Deal initial balances
        deal(address(erc20), user, INITIAL_BALANCE);
        deal(address(erc20), randomUser, INITIAL_BALANCE);
        
        // Label addresses for better trace output
        vm.label(address(nodeFactory), "NodeFactory");
        vm.label(address(node), "Node");
        vm.label(address(escrow), "Escrow");
        vm.label(address(queueManager), "QueueManager");
        vm.label(address(quoter), "Quoter");
        vm.label(address(erc20), "TestToken");
        vm.label(deployer, "Deployer");
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(randomUser, "RandomUser");

        vm.stopPrank();
    }

    function deployFullNode(
        address asset,
        string memory name,
        string memory symbol,
        address nodeOwner
    ) internal returns (
        INode node_,
        IEscrow escrow_,
        IQuoter quoter_,
        IQueueManager manager_,
        IERC4626Rebalancer erc4626Rebalancer_
    ) {
        bytes32 salt = keccak256(abi.encodePacked("node", name, symbol));

        (
            node_,
            escrow_,
            quoter_,
            manager_,
            erc4626Rebalancer_
        ) = nodeFactory.deployFullNode(asset, name, symbol, nodeOwner, salt);
    }

    function mintAndApprove(address to, uint256 amount, address spender) public {
        erc20.mint(to, amount);
        vm.prank(to);
        erc20.approve(spender, amount);
    }
}
