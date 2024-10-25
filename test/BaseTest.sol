// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
pragma abicoder v2;

import {Deployer} from "script/Deployer.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {Node} from "src/Node.sol";
import {NodeFactory} from "src/NodeFactory.sol";
import {Escrow} from "src/Escrow.sol";
import {ERC4626Rebalancer} from "src/rebalancers/ERC4626Rebalancer.sol";
import "forge-std/Test.sol";

contract BaseTest is Deployer, Test {
    ERC20Mock public erc20;

    uint8 public assetDecimals = 18;

    address owner = makeAddr("owner");
    address randomUser = makeAddr("randomUser");

    function setUp() public virtual {
        vm.chainId(1);

        // Deploy node factory
        deploy(address(this));

        erc20 = new ERC20Mock("Test Token", "TST");
    }

    // Helper function to deploy a new Node
    function deployNode(
        address asset,
        string memory name,
        string memory symbol,
        address owner
    ) public returns (Node) {
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, asset, name, symbol));
        address nodeAddress = address(nodeFactory.createNode(asset, name, symbol, owner, salt));
        return Node(nodeAddress);
    }

    function deployERC4626Rebalancer(address node, address owner) public returns (ERC4626Rebalancer) {
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, node, owner));
        address rebalancerAddress = address(nodeFactory.createERC4626Rebalancer(node, owner, salt));
        return ERC4626Rebalancer(rebalancerAddress);
    }

    // Helper function to mint and approve tokens
    function mintAndApprove(address to, uint256 amount, address spender) public {
        erc20.mint(to, amount);
        vm.prank(to);
        erc20.approve(spender, amount);
    }
}
