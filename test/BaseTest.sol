// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
pragma abicoder v2;

import {Deployer} from "script/Deployer.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
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

    // Helper function to mint and approve tokens
    function mintAndApprove(address to, uint256 amount, address spender) public {
        erc20.mint(to, amount);
        vm.prank(to);
        erc20.approve(spender, amount);
    }
}
