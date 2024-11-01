// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Deployer} from "script/Deployer.sol";

import {Node} from "src/Node.sol";
import {Escrow} from "src/Escrow.sol";
import {QueueManager} from "src/QueueManager.sol";

import {INode} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {INodeFactory} from "src/interfaces/INodeFactory.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";
import {IQuoter} from "src/interfaces/IQuoter.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract BaseTest is Test {
    Deployer public deployer;

    INodeRegistry public registry;
    INodeFactory public nodeFactory;
    IQuoter public quoter;

    INode public node;
    IEscrow public escrow;
    IQueueManager public queueManager;

    ERC20Mock public erc20;

    address public deployerAddress = makeAddr("deployer");
    address public owner = makeAddr("owner");
    address public rebalancer = makeAddr("rebalancer");
    address public user = makeAddr("user");
    address public randomUser = makeAddr("randomUser");

    uint128 public constant MAX_UINT128 = type(uint128).max;
    uint256 public constant INITIAL_BALANCE = 1000000 ether;
    bytes32 public constant SALT = bytes32(uint256(1));

    function setUp() public virtual {
        vm.chainId(1);

        erc20 = new ERC20Mock("Test Token", "TEST");

        deployer = new Deployer();
        deployer.deploy(deployerAddress);

        registry = INodeRegistry(address(deployer.nodeRegistry()));
        nodeFactory = INodeFactory(address(deployer.nodeFactory()));
        quoter = IQuoter(address(deployer.quoter()));

        address[] memory factories = new address[](1);
        factories[0] = address(nodeFactory);

        address[] memory routers = new address[](1);
        routers[0] = address(deployer.erc4626Router());

        address[] memory quoters = new address[](1);
        quoters[0] = address(quoter);

        vm.startPrank(deployerAddress);
        registry.initialize(factories, routers, quoters);
        Ownable(address(registry)).transferOwnership(owner);
        vm.stopPrank();

        vm.startPrank(owner);
        (node, escrow, queueManager) = nodeFactory.deployFullNode(
            "Test Node", "TNODE", address(erc20), owner, rebalancer, address(quoter), routers, SALT
        );
        vm.stopPrank();

        deal(address(erc20), user, INITIAL_BALANCE);
        deal(address(erc20), randomUser, INITIAL_BALANCE);

        vm.label(address(registry), "NodeRegistry");
        vm.label(address(nodeFactory), "NodeFactory");
        vm.label(address(quoter), "Quoter");
        vm.label(address(deployer.erc4626Router()), "Router");
        vm.label(address(node), "Node");
        vm.label(address(escrow), "Escrow");
        vm.label(address(queueManager), "QueueManager");
        vm.label(address(erc20), "TestToken");
        vm.label(deployerAddress, "Deployer");
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(randomUser, "RandomUser");
        vm.label(rebalancer, "Rebalancer");
    }

    function mintAndApprove(address to, uint256 amount, address spender) public {
        erc20.mint(to, amount);
        vm.prank(to);
        erc20.approve(spender, amount);
    }
}
