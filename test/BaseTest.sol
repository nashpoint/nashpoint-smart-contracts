// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Deployer} from "script/Deployer.sol";

import {Node} from "src/Node.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {Escrow} from "src/Escrow.sol";
import {QueueManager} from "src/QueueManager.sol";

import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {INodeFactory} from "src/interfaces/INodeFactory.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
import {IQueueManager} from "src/interfaces/IQueueManager.sol";
import {IQuoter} from "src/interfaces/IQuoter.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract BaseTest is Test {
    Deployer public deployer;
    INodeRegistry public registry;
    INodeFactory public factory;
    IQuoter public quoter;
    ERC4626Router public router;
    
    INode public node;
    IEscrow public escrow;
    IQueueManager public queueManager;
    ERC20Mock public asset;

    address public owner;
    address public user;
    address public randomUser;
    address public rebalancer;

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    bytes32 public constant SALT = bytes32(uint256(1));

    function setUp() public virtual {
        vm.chainId(1);
        
        owner = makeAddr("owner");
        user = makeAddr("user");
        randomUser = makeAddr("randomUser");
        rebalancer = makeAddr("rebalancer");
        
        deployer = new Deployer();
        deployer.deploy(owner);
        
        registry = INodeRegistry(address(deployer.registry()));
        factory = INodeFactory(address(deployer.factory()));
        quoter = IQuoter(address(deployer.quoter()));
        router = deployer.router();
        
        asset = new ERC20Mock("Test Token", "TEST");

        vm.startPrank(owner);
        registry.initialize(
            _toArray(address(factory)),
            _toArray(address(router)),
            _toArray(address(quoter)),
            _toArray(address(rebalancer))
        );
        vm.stopPrank();

        vm.startPrank(owner);
        (node, escrow, queueManager) = factory.deployFullNode(
            "Test Node",
            "TNODE",
            address(asset),
            owner,
            address(rebalancer),
            address(quoter),
            _toArray(address(router)),
            _toArray(address(router)),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation(),
            SALT
        );
        vm.stopPrank();

        deal(address(asset), user, INITIAL_BALANCE);
        deal(address(asset), randomUser, INITIAL_BALANCE);

        _labelAddresses();
    }

    function _toArray(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }

    function _defaultComponentAllocations(uint256 count) internal pure returns (ComponentAllocation[] memory allocations) {
        allocations = new ComponentAllocation[](count);
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = ComponentAllocation({
                minimumWeight: 0.3 ether,
                maximumWeight: 0.7 ether,
                targetWeight: 0.5 ether
            });
        }
    }

    function _defaultReserveAllocation() internal pure returns (ComponentAllocation memory) {
        return ComponentAllocation({
            minimumWeight: 0.3 ether,
            maximumWeight: 0.7 ether,
            targetWeight: 0.5 ether
        });
    }

    function _labelAddresses() internal {
        vm.label(address(registry), "Registry");
        vm.label(address(factory), "Factory");
        vm.label(address(quoter), "Quoter");
        vm.label(address(router), "Router");
        vm.label(address(node), "Node");
        vm.label(address(escrow), "Escrow");
        vm.label(address(queueManager), "QueueManager");
        vm.label(address(asset), "TestToken");
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(randomUser, "RandomUser");
        vm.label(rebalancer, "Rebalancer");
    }
}
