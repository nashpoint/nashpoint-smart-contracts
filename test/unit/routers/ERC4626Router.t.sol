// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../../BaseTest.sol";
import {ERC4626Router} from "src/routers/ERC4626Router.sol";
import {ComponentAllocation} from "src/interfaces/INode.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

contract ERC4626RouterHarness is ERC4626Router {
    constructor(address _registry) ERC4626Router(_registry) {}

    function _getInvestmentSize(address node, address component) public view returns (uint256 depositAssets) {
        return super.getInvestmentSize(node, component);
    }
}

contract ERC4626RouterTest is BaseTest {
    ERC4626RouterHarness public testRouter;
    ERC4626Mock public testComponent;

    function setUp() public override {
        super.setUp();
        testRouter = new ERC4626RouterHarness(address(registry));
        testComponent = new ERC4626Mock(address(asset));
    }

    function test_getInvestmentSize() public {
        _seedNode(100 ether);
        ComponentAllocation memory allocation = ComponentAllocation({targetWeight: 0.5 ether, maxDelta: 0.01 ether});

        vm.startPrank(owner);
        quoter.setErc4626(address(testComponent), true);
        node.addComponent(address(testComponent), allocation);
        vm.stopPrank();

        uint256 investmentSize = testRouter._getInvestmentSize(address(node), address(testComponent));

        assertEq(node.getComponentRatio(address(testComponent)), 0.5 ether);
        assertEq(testComponent.balanceOf(address(node)), 0);
        assertEq(investmentSize, 50 ether);
    }
}
