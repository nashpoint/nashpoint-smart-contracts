// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

import {Deployer} from "script/Deployer.sol";

import {Node} from "src/Node.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {Escrow} from "src/Escrow.sol";

import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {INodeFactory} from "src/interfaces/INodeFactory.sol";
import {IEscrow} from "src/interfaces/IEscrow.sol";
import {IQuoterV1} from "src/interfaces/IQuoterV1.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract BaseTest is Test {
    Deployer public deployer;
    INodeRegistry public registry;
    INodeFactory public factory;
    IQuoterV1 public quoter;
    ERC4626Router public router;
    
    INode public node;
    IEscrow public escrow;
    ERC20Mock public asset;
    ERC4626Mock public vault;

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
        quoter = IQuoterV1(address(deployer.quoter()));
        router = deployer.router();
        
        asset = new ERC20Mock("Test Token", "TEST");
        vault = new ERC4626Mock(address(asset));

        vm.startPrank(owner);
        registry.initialize(
            _toArray(address(factory)),
            _toArray(address(router)),
            _toArray(address(quoter)),
            _toArray(address(rebalancer))
        );
        quoter.setErc4626(address(vault), true);
        router.setWhitelistStatus(address(vault), true);

        vm.startPrank(owner);
        (node, escrow) = factory.deployFullNode(
            "Test Node",
            "TNODE",
            address(asset),
            owner,
            address(rebalancer),
            address(quoter),
            _toArray(address(router)),
            _toArray(address(vault)),
            _defaultComponentAllocations(1),
            _defaultReserveAllocation(),
            SALT
        );
        vm.stopPrank();

        deal(address(asset), user, INITIAL_BALANCE);
        deal(address(asset), randomUser, INITIAL_BALANCE);

        _labelAddresses();
        vm.label(address(vault), "Vault");
    }

    function _toArray(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }

    function _defaultComponentAllocations(uint256 count) internal pure returns (ComponentAllocation[] memory allocations) {
        allocations = new ComponentAllocation[](count);
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = ComponentAllocation({
                targetWeight: 0.5 ether
            });
        }
    }

    function _defaultReserveAllocation() internal pure returns (ComponentAllocation memory) {
        return ComponentAllocation({
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
        vm.label(address(asset), "TestToken");
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(randomUser, "RandomUser");
        vm.label(rebalancer, "Rebalancer");
    }
}
