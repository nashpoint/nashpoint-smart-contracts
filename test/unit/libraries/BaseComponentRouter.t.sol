// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseComponentRouter} from "src/libraries/BaseComponentRouter.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {INodeRegistry} from "src/interfaces/INodeRegistry.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseComponentRouterHarness is BaseComponentRouter {
    uint256 public investmentSize;

    constructor(address registry_) BaseComponentRouter(registry_) {}

    function setMockInvestmentSize(uint256 value) external {
        investmentSize = value;
    }

    function computeDepositAmount(address node, address component) external returns (uint256) {
        return _computeDepositAmount(node, component);
    }

    function validateReserve(uint256 currentCash, uint256 idealCashReserve) external pure {
        _validateReserveAboveTargetRatio(currentCash, idealCashReserve);
    }

    function calculatePartialFulfill(uint256 sharesPending, uint256 assetsReturned, uint256 assetsRequested)
        external
        pure
        returns (uint256)
    {
        return _calculatePartialFulfill(sharesPending, assetsReturned, assetsRequested);
    }

    function getNodeCashStatus(address node)
        external
        view
        returns (uint256 totalAssets, uint256 currentCash, uint256 idealCashReserve)
    {
        return _getNodeCashStatus(node);
    }

    function subtractExecutionFee(uint256 amount, address node) external returns (uint256) {
        return _subtractExecutionFee(amount, node);
    }

    function getComponentAssets(address, address, bool) public view virtual override returns (uint256) {
        return 0;
    }

    function getInvestmentSize(address, address) public view virtual override returns (uint256) {
        return investmentSize;
    }

    function callGetComponentAssets(address node, address component, bool claimableOnly)
        external
        view
        returns (uint256)
    {
        return getComponentAssets(node, component, claimableOnly);
    }

    function callGetInvestmentSize(address node, address component) external view returns (uint256) {
        return getInvestmentSize(node, component);
    }

    function callSafeApprove(address node, address token, address spender, uint256 amount) external {
        _safeApprove(node, token, spender, amount);
    }
}

contract BaseComponentRouterRevertHarness is BaseComponentRouter {
    constructor(address registry_) BaseComponentRouter(registry_) {}

    function getComponentAssets(address node, address component, bool claimableOnly)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return super.getComponentAssets(node, component, claimableOnly);
    }

    function getInvestmentSize(address node, address component) public view virtual override returns (uint256) {
        return super.getInvestmentSize(node, component);
    }
}

contract NodeExecuteMock {
    address public lastTarget;
    bytes public lastData;

    function execute(address target, bytes calldata data) external returns (bytes memory) {
        lastTarget = target;
        lastData = data;
        return abi.encode(true);
    }
}

contract NodeExecuteFailMock {
    function execute(address, bytes calldata) external pure returns (bytes memory) {
        return abi.encode(false);
    }
}

contract BaseComponentRouterTest is Test {
    address registry = address(0x1);
    address registryOwner = address(0x2);
    address node = address(0x3);
    address component = address(0x4);

    BaseComponentRouterHarness router;
    BaseComponentRouterRevertHarness revertRouter;
    NodeExecuteMock nodeMock;
    NodeExecuteFailMock nodeFailMock;

    event ComponentWhitelisted(address indexed component, bool status);
    event ComponentBlacklisted(address indexed component, bool status);
    event ToleranceUpdated(uint256 tolerance);

    function setUp() external {
        vm.mockCall(registry, abi.encodeWithSelector(Ownable.owner.selector), abi.encode(registryOwner));
        router = new BaseComponentRouterHarness(registry);
        revertRouter = new BaseComponentRouterRevertHarness(registry);
        nodeMock = new NodeExecuteMock();
        nodeFailMock = new NodeExecuteFailMock();
    }

    function test_setWhitelistStatus_zeroAddress_revert() external {
        vm.prank(registryOwner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        router.setWhitelistStatus(address(0), true);
    }

    function test_setWhitelistStatus_emitsAndStores() external {
        vm.startPrank(registryOwner);
        vm.expectEmit(true, false, false, true);
        emit ComponentWhitelisted(component, true);
        router.setWhitelistStatus(component, true);
        vm.stopPrank();

        assertTrue(router.isWhitelisted(component));
    }

    function test_setBlacklistStatus_zeroAddress_revert() external {
        vm.prank(registryOwner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        router.setBlacklistStatus(address(0), true);
    }

    function test_setBlacklistStatus_emitsAndStores() external {
        vm.startPrank(registryOwner);
        vm.expectEmit(true, false, false, true);
        emit ComponentBlacklisted(component, true);
        router.setBlacklistStatus(component, true);
        vm.stopPrank();

        assertTrue(router.isBlacklisted(component));
    }

    function test_batchSetWhitelistStatus_lengthMismatch_revert() external {
        vm.prank(registryOwner);
        vm.expectRevert(ErrorsLib.LengthMismatch.selector);
        router.batchSetWhitelistStatus(new address[](1), new bool[](0));
    }

    function test_batchSetWhitelistStatus_zeroAddress_revert() external {
        address[] memory components = new address[](1);
        components[0] = address(0);
        bool[] memory statuses = new bool[](1);
        vm.prank(registryOwner);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        router.batchSetWhitelistStatus(components, statuses);
    }

    function test_batchSetWhitelistStatus_updates() external {
        address[] memory components = new address[](2);
        components[0] = component;
        components[1] = address(0x5);
        bool[] memory statuses = new bool[](2);
        statuses[0] = true;
        statuses[1] = false;

        vm.prank(registryOwner);
        router.batchSetWhitelistStatus(components, statuses);

        assertTrue(router.isWhitelisted(component));
        assertFalse(router.isWhitelisted(address(0x5)));
    }

    function test_setTolerance_emitsAndStores() external {
        uint256 newTolerance = 123;
        vm.startPrank(registryOwner);
        vm.expectEmit(false, false, false, true);
        emit ToleranceUpdated(newTolerance);
        router.setTolerance(newTolerance);
        vm.stopPrank();

        assertEq(router.tolerance(), newTolerance);
    }

    function test_calculatePartialFulfill_scalesCeiling() external {
        uint256 sharesPending = 1000;
        uint256 assetsReturned = 1;
        uint256 assetsRequested = 3;
        uint256 scaled = router.calculatePartialFulfill(sharesPending, assetsReturned, assetsRequested);
        assertEq(
            scaled,
            Math.min(sharesPending, Math.mulDiv(sharesPending, assetsReturned, assetsRequested, Math.Rounding.Ceil))
        );
    }

    function test_validateReserveBelowTarget_revert() external {
        vm.expectRevert(ErrorsLib.ReserveBelowTargetRatio.selector);
        router.validateReserve(10, 11);
    }

    function test_computeDepositAmount_success() external {
        vm.prank(registryOwner);
        router.setWhitelistStatus(component, true);
        router.setMockInvestmentSize(400);

        // mock node status
        vm.mockCall(node, abi.encodeWithSelector(INode.totalAssets.selector), abi.encode(1000));
        vm.mockCall(node, abi.encodeWithSelector(INode.getCashAfterRedemptions.selector), abi.encode(700));
        vm.mockCall(node, abi.encodeWithSelector(INode.targetReserveRatio.selector), abi.encode(uint64(0.2e18)));
        vm.mockCall(
            node,
            abi.encodeWithSelector(INode.getComponentAllocation.selector, component),
            abi.encode(
                ComponentAllocation({targetWeight: 0.5e18, maxDelta: 0.1e18, router: address(this), isComponent: true})
            )
        );
        vm.mockCall(
            registry, abi.encodeWithSelector(INodeRegistry.protocolExecutionFee.selector), abi.encode(uint64(0))
        );

        uint256 depositAmount = router.computeDepositAmount(node, component);
        assertEq(depositAmount, 400);
    }

    function test_computeDepositAmount_blacklisted_revert() external {
        vm.startPrank(registryOwner);
        router.setWhitelistStatus(component, true);
        router.setBlacklistStatus(component, true);
        vm.stopPrank();

        vm.expectRevert(ErrorsLib.Blacklisted.selector);
        router.computeDepositAmount(node, component);
    }

    function test_computeDepositAmount_reserveBelowTarget_revert() external {
        vm.prank(registryOwner);
        router.setWhitelistStatus(component, true);
        router.setMockInvestmentSize(100);

        vm.mockCall(node, abi.encodeWithSelector(INode.totalAssets.selector), abi.encode(1000));
        vm.mockCall(node, abi.encodeWithSelector(INode.getCashAfterRedemptions.selector), abi.encode(100));
        vm.mockCall(node, abi.encodeWithSelector(INode.targetReserveRatio.selector), abi.encode(uint64(0.2e18)));
        vm.mockCall(
            node,
            abi.encodeWithSelector(INode.getComponentAllocation.selector, component),
            abi.encode(
                ComponentAllocation({targetWeight: 0.5e18, maxDelta: 0.1e18, router: address(this), isComponent: true})
            )
        );
        vm.mockCall(
            registry, abi.encodeWithSelector(INodeRegistry.protocolExecutionFee.selector), abi.encode(uint64(0))
        );

        vm.expectRevert(ErrorsLib.ReserveBelowTargetRatio.selector);
        router.computeDepositAmount(node, component);
    }

    function test_computeDepositAmount_componentWithinTargetRange_revert() external {
        vm.prank(registryOwner);
        router.setWhitelistStatus(component, true);
        router.setMockInvestmentSize(50);

        vm.mockCall(node, abi.encodeWithSelector(INode.totalAssets.selector), abi.encode(1000));
        vm.mockCall(node, abi.encodeWithSelector(INode.getCashAfterRedemptions.selector), abi.encode(500));
        vm.mockCall(node, abi.encodeWithSelector(INode.targetReserveRatio.selector), abi.encode(uint64(0.2e18)));
        vm.mockCall(
            node,
            abi.encodeWithSelector(INode.getComponentAllocation.selector, component),
            abi.encode(
                ComponentAllocation({targetWeight: 0.5e18, maxDelta: 0.1e18, router: address(this), isComponent: true})
            )
        );
        vm.mockCall(
            registry, abi.encodeWithSelector(INodeRegistry.protocolExecutionFee.selector), abi.encode(uint64(0))
        );

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.ComponentWithinTargetRange.selector, node, component));
        router.computeDepositAmount(node, component);
    }

    function test_subtractExecutionFee_appliesFeeAndCallsNode() external {
        uint256 amount = 1000;
        uint64 fee = 0.1e18; // 10%
        vm.mockCall(registry, abi.encodeWithSelector(INodeRegistry.protocolExecutionFee.selector), abi.encode(fee));
        vm.mockCall(node, abi.encodeWithSelector(INode.subtractProtocolExecutionFee.selector, 0), abi.encode());

        uint256 expectedFee = amount * fee / 1e18;
        vm.expectCall(node, abi.encodeWithSelector(INode.subtractProtocolExecutionFee.selector, expectedFee));

        uint256 afterFee = router.subtractExecutionFee(amount, node);
        assertEq(afterFee, amount - expectedFee);
    }

    function test_virtual_getComponentAssets_revertForbidden() external {
        vm.expectRevert(ErrorsLib.Forbidden.selector);
        revertRouter.getComponentAssets(node, component, false);
    }

    function test_virtual_getInvestmentSize_revertForbidden() external {
        vm.expectRevert(ErrorsLib.Forbidden.selector);
        revertRouter.getInvestmentSize(node, component);
    }

    function test_safeApprove_executesThroughNode() external {
        address token = address(0xabc);
        address spender = address(0xdef);
        uint256 amount = 1234;

        vm.expectCall(
            address(nodeMock),
            abi.encodeWithSelector(INode.execute.selector, token, abi.encodeCall(IERC20.approve, (spender, amount)))
        );
        router.callSafeApprove(address(nodeMock), token, spender, amount);
    }

    function test_safeApprove_revertWhenNodeReturnsFalse() external {
        address token = address(0xabc);
        address spender = address(0xdef);
        uint256 amount = 1234;

        vm.expectRevert(ErrorsLib.SafeApproveFailed.selector);
        router.callSafeApprove(address(nodeFailMock), token, spender, amount);
    }
}
