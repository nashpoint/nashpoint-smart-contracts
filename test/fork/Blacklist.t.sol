// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {INode} from "src/interfaces/INode.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";

contract Blacklist is Test {
    INode node = INode(0x6ca200319A0D4127a7a473d6891B86f34e312F42);
    address nashPointOwner = 0x69C2d63BC4Fcd16CD616D22089B58de3796E1F5c;
    address nodeOwner = 0x8d1A519326724b18A6F5877a082aae19394D0f67;

    ERC4626 varlamore = ERC4626(0x2BA39e5388aC6C702Cb29AEA78d52aa66832f1ee);

    ERC4626Router router = ERC4626Router(0x18E7a99c527Bd1727111082b8C7D36D1995B89B8);

    address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 396704482);

        // NOTE: comment out upper line
        // use this to verify that correct amount of assets is returned for varlamore
        // vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 396612994);
    }

    function test_blacklist() external {
        // Step 1.
        vm.startPrank(nashPointOwner);
        // prevent future use
        router.setWhitelistStatus(address(varlamore), false);
        // blacklist to allow force remove
        router.setBlacklistStatus(address(varlamore), true);
        vm.stopPrank();

        uint256 shares = varlamore.balanceOf(address(node));
        // calculated via convertToAssets on block number 396612994
        // when last updateTotalAssets has been called
        uint256 assetsToReturn = 32420603426;

        // node owner should have enough assets to cover varlamore
        deal(usdc, nodeOwner, assetsToReturn);

        assertEq(varlamore.balanceOf(nodeOwner), 0);
        assertGt(varlamore.balanceOf(address(node)), 0);

        uint256 totalAssetsBefore = node.totalAssets();

        // Step 2.
        vm.startPrank(nodeOwner);
        // force remove component
        node.removeComponent(address(varlamore), true);
        // move varlamore shares to node owner multisig
        node.rescueTokens(address(varlamore), nodeOwner, shares);
        // transfer usdc equivalent to the node
        ERC20(usdc).transfer(address(node), assetsToReturn);
        // update total assets
        node.updateTotalAssets();
        vm.stopPrank();

        uint256 totalAssetsAfter = node.totalAssets();

        // node no longer has varlamore shares
        assertEq(varlamore.balanceOf(address(node)), 0);
        // node owner received all of them
        assertEq(varlamore.balanceOf(nodeOwner), shares);
        // totalAssets are greater than or equal before
        assertGe(totalAssetsAfter, totalAssetsBefore);

        // NOTE: uncomment this to check correctly calculated assetsToReturn
        // assertEq(totalAssetsAfter, totalAssetsBefore);
    }
}
