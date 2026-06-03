// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {DigiftAdapterV2} from "src/adapters/digift/DigiftAdapterV2.sol";
import {AdapterBase} from "src/adapters/AdapterBase.sol";
import {DigiftEventVerifier} from "src/adapters/digift/DigiftEventVerifier.sol";
import {EventVerifierBase} from "src/adapters/EventVerifierBase.sol";
import {ISubRedManagement} from "src/interfaces/external/IDigift.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";

/**
 * @title DigiftAdapterRefundForkTest
 * @notice Fork test that reproduces the live stuck-deposit incident and proves the
 *         {DigiftAdapterV2} beacon upgrade resolves it by returning the refunded USDC to the node.
 *
 * Incident:
 * - Node "tivRWA" (0x6DAcA1e8...) requested a deposit of 19.821999 USDC into the wiSNR DigiftAdapter.
 * - The adapter forwarded it to DigiFT SubRedManagement via subscribe()
 *   (tx 0x1dad06ec4ea04137242894faa74b120bf0d5ae29fc73e333e77b55462b0fba2e).
 * - DigiFT returned the 19.821999 USDC to the adapter using a non-standard transfer that did NOT
 *   emit `SettleSubscriber`
 *   (tx 0x66ea0e665307f3d83e09467cbb832e96d3ae33c4935267ead0c5ef7e5bb2dda0).
 * - As a result `settleDeposit` can never verify the refund: the USDC is stranded in the adapter
 *   and the node's `pendingDepositRequest` is jammed.
 *
 * This test forks Arbitrum after the refund (so the adapter holds the returned USDC and the pending
 * deposit is set), upgrades the beacon implementation to {DigiftAdapterV2}, and calls
 * {settleDepositRefund} as the registry owner. End state: the USDC is returned to tivRWA.
 */
contract DigiftAdapterRefundForkTest is Test {
    // Fork after DigiFT's refund tx (block 468924584) so the stuck state is present on-chain.
    uint256 constant FORK_BLOCK = 469300548;

    // Live Arbitrum deployment (see deployments/arbitrum.json + config/arbitrum.json).
    DigiftAdapterV2 constant adapter = DigiftAdapterV2(0x42eBf0BA14716BA01307B1f6506bE84d7579E643);
    UpgradeableBeacon constant beacon = UpgradeableBeacon(0x5A24559a617f2253437d7938a60541aE578c05c2);
    address constant REGISTRY = 0xC0eEdf3980784fCF4576f139244D20F31BAaDF6E;
    address constant SUB_RED_MANAGEMENT = 0x3DAd21A73a63bBd186f57f733d271623467b6c78;
    address constant EVENT_VERIFIER = 0xf36cc38Ec0b1aF75c4295c5D928eD08b0B6444A8;

    // Beacon owner == registry owner for this deployment.
    address constant OWNER = 0x69C2d63BC4Fcd16CD616D22089B58de3796E1F5c;

    // The node with the stuck deposit ("Inveniam RWA Test Vault" / tivRWA).
    address constant NODE = 0x6DAcA1e808C46E18F32e736E0AeB45c3824e073c;

    // The node owner (can add/remove components and set the reserve ratio).
    address constant NODE_OWNER = 0x45fD333D2CAae3c544f315ee1d7cc247E9D986b9;

    // Whitelisted manager (rebalancer) able to call forwardRequests/settle.
    address constant MANAGER = 0xB1ce02d5eE676e657BD59D2EE5dFB147a13f56e9;

    // DigiFT security token (the adapter's `fund`).
    address constant FUND = 0x37EC21365dC39B0b74ea7b6FabFfBcB277568AC4;

    IERC20 constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    // Documented expected stuck amount: 19.821999 USDC (6 decimals).
    uint256 constant EXPECTED_REFUND = 19_821_999;

    /// @dev True only if the pinned fork could be created (requires an archive RPC that still
    ///      serves FORK_BLOCK). When false, fork tests are skipped rather than failed.
    bool internal forkReady;

    function setUp() public {
        // createSelectFork reverts if the RPC cannot serve historical state at FORK_BLOCK
        // (e.g. non-archive endpoint, or the block has aged out of the provider's retention).
        // Doing it via an external call lets us catch that and skip instead of hard-failing.
        try this._initFork() {
            forkReady = true;
        } catch {
            forkReady = false;
        }
    }

    /// @dev External wrapper so the fork creation can be used with try/catch.
    function _initFork() external {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), FORK_BLOCK);
    }

    /// @dev Skips the test when the pinned fork state is unavailable.
    modifier forkOrSkip() {
        vm.skip(!forkReady);
        _;
    }

    /// @dev Sanity-check the live stuck state is what we expect before fixing it.
    function test_forkState_depositIsStuck() external forkOrSkip {
        assertEq(adapter.asset(), address(USDC), "asset is USDC");
        assertEq(adapter.pendingDepositRequest(0, NODE), EXPECTED_REFUND, "node has stuck pending deposit");
        assertEq(adapter.globalPendingDepositRequest(), EXPECTED_REFUND, "global pending matches");
        assertEq(USDC.balanceOf(address(adapter)), EXPECTED_REFUND, "refunded USDC sits in adapter");
        assertEq(adapter.balanceOf(NODE), 0, "node holds no wiSNR shares for this deposit");
    }

    /// @dev Upgrade the beacon to V2 and refund the stuck deposit; USDC ends up back in tivRWA.
    function test_settleDepositRefund_returnsUsdcToNode() external forkOrSkip {
        // Pre-state captured from the live fork.
        uint256 nodePendingBefore = adapter.pendingDepositRequest(0, NODE);
        uint256 globalPendingBefore = adapter.globalPendingDepositRequest();
        uint256 adapterUsdcBefore = USDC.balanceOf(address(adapter));
        uint256 nodeUsdcBefore = USDC.balanceOf(NODE);
        uint256 nodeSharesBefore = adapter.balanceOf(NODE);
        uint256 totalSupplyBefore = adapter.totalSupply();

        assertEq(nodePendingBefore, EXPECTED_REFUND, "fork captured the stuck deposit");
        assertGe(adapterUsdcBefore, nodePendingBefore, "adapter holds the refunded USDC");

        // Deploy the new implementation (same immutables as the live adapter) and upgrade the beacon.
        DigiftAdapterV2 newImplementation = new DigiftAdapterV2(REGISTRY, SUB_RED_MANAGEMENT, EVENT_VERIFIER);

        vm.prank(OWNER);
        beacon.upgradeTo(address(newImplementation));
        assertEq(beacon.implementation(), address(newImplementation), "beacon points to V2");

        // Registry owner clears the stuck deposit and refunds the node.
        vm.expectEmit(true, true, true, true, address(adapter));
        emit DigiftAdapterV2.DepositRefunded(NODE, EXPECTED_REFUND);

        vm.prank(OWNER);
        uint256 refunded = adapter.settleDepositRefund(NODE);

        // End state: USDC returned to tivRWA, pending cleared, no shares minted.
        assertEq(refunded, EXPECTED_REFUND, "refunded the full stuck amount");
        assertEq(USDC.balanceOf(NODE), nodeUsdcBefore + nodePendingBefore, "tivRWA received the refunded USDC");
        assertEq(USDC.balanceOf(address(adapter)), adapterUsdcBefore - nodePendingBefore, "adapter released the USDC");
        assertEq(adapter.pendingDepositRequest(0, NODE), 0, "node pending deposit cleared");
        assertEq(
            adapter.globalPendingDepositRequest(), globalPendingBefore - nodePendingBefore, "global pending decremented"
        );
        assertEq(adapter.balanceOf(NODE), nodeSharesBefore, "no shares minted to node");
        assertEq(adapter.totalSupply(), totalSupplyBefore, "share supply unchanged");
    }

    /// @dev Access control: only the registry owner may trigger the manual refund.
    function test_settleDepositRefund_onlyRegistryOwner() external forkOrSkip {
        _upgradeToV2();

        vm.prank(address(0xBAD));
        vm.expectRevert();
        adapter.settleDepositRefund(NODE);
    }

    /// @dev After the refund, the adapter accepts new deposits and forwards them normally again.
    function test_depositForwardUnblockedAfterRefund() external forkOrSkip {
        _upgradeToV2();

        // Before the refund, the stuck global pending deposit blocks forwarding entirely.
        vm.prank(MANAGER);
        vm.expectRevert(AdapterBase.DepositRequestPending.selector);
        adapter.forwardRequests();

        // Before the refund, the node cannot open a new deposit (its pending slot is occupied).
        deal(address(USDC), NODE, 1000e6);
        vm.prank(NODE);
        USDC.approve(address(adapter), 1000e6);
        vm.prank(NODE);
        vm.expectRevert(AdapterBase.DepositRequestPending.selector);
        adapter.requestDeposit(1000e6, NODE, NODE);

        // Clear the stuck deposit.
        vm.prank(OWNER);
        adapter.settleDepositRefund(NODE);

        // Forwarding works again (nothing queued -> no-op, no revert).
        vm.prank(MANAGER);
        adapter.forwardRequests();

        // The node can open a fresh deposit.
        vm.prank(NODE);
        uint256 requestId = adapter.requestDeposit(1000e6, NODE, NODE);
        assertEq(requestId, 0, "request id");
        assertEq(adapter.pendingDepositRequest(0, NODE), 1000e6, "fresh deposit recorded");
        assertEq(adapter.accumulatedDeposit(), 1000e6, "queued for next forward");

        // And the adapter forwards it to DigiFT (subscribe mocked to isolate from DigiFT acceptance).
        vm.mockCall(SUB_RED_MANAGEMENT, abi.encodeWithSelector(ISubRedManagement.subscribe.selector), bytes(""));
        vm.prank(MANAGER);
        adapter.forwardRequests();
        assertEq(adapter.globalPendingDepositRequest(), 1000e6, "deposit forwarded");
        assertEq(adapter.accumulatedDeposit(), 0, "queue cleared after forward");
    }

    /// @dev After the refund, a full deposit -> mint -> redeem -> withdraw cycle works end-to-end.
    function test_fullDepositAndRedeemCycleAfterRefund() external forkOrSkip {
        _upgradeToV2();
        vm.prank(OWNER);
        adapter.settleDepositRefund(NODE);

        uint256 depositAmount = 1000e6;

        // ---- Deposit path: request -> forward -> settle -> mint ----
        deal(address(USDC), NODE, depositAmount);
        vm.prank(NODE);
        USDC.approve(address(adapter), depositAmount);
        vm.prank(NODE);
        adapter.requestDeposit(depositAmount, NODE, NODE);

        vm.mockCall(SUB_RED_MANAGEMENT, abi.encodeWithSelector(ISubRedManagement.subscribe.selector), bytes(""));
        vm.prank(MANAGER);
        adapter.forwardRequests();
        assertEq(adapter.globalPendingDepositRequest(), depositAmount, "deposit forwarded");

        uint256 shares = adapter.convertToShares(depositAmount);
        _mockVerifier(DigiftEventVerifier.EventType.SUBSCRIBE, shares, 0);
        _settle(true);
        assertEq(adapter.maxMint(NODE), shares, "shares claimable after settle");

        vm.prank(NODE);
        adapter.mint(shares, NODE, NODE);
        assertEq(adapter.balanceOf(NODE), shares, "deposit complete: node holds wiSNR shares");

        // ---- Withdrawal path: request -> forward -> settle -> withdraw ----
        vm.prank(NODE);
        adapter.approve(address(adapter), shares);
        vm.prank(NODE);
        adapter.requestRedeem(shares, NODE, NODE);
        assertEq(adapter.pendingRedeemRequest(0, NODE), shares, "redeem request recorded");

        vm.mockCall(SUB_RED_MANAGEMENT, abi.encodeWithSelector(ISubRedManagement.redeem.selector), bytes(""));
        vm.prank(MANAGER);
        adapter.forwardRequests();
        assertEq(adapter.globalPendingRedeemRequest(), shares, "redeem forwarded to DigiFT");

        uint256 assetsOut = adapter.convertToAssets(shares);
        _mockVerifier(DigiftEventVerifier.EventType.REDEEM, 0, assetsOut);
        _settle(false);
        assertEq(adapter.maxWithdraw(NODE), assetsOut, "assets withdrawable after settle");

        uint256 nodeUsdcBefore = USDC.balanceOf(NODE);
        vm.prank(NODE);
        adapter.withdraw(assetsOut, NODE, NODE);
        assertEq(USDC.balanceOf(NODE), nodeUsdcBefore + assetsOut, "withdrawal complete: node received USDC");
        assertEq(adapter.balanceOf(NODE), 0, "node shares burned");
    }

    /// @dev Post-refund owner cleanup: remove the wiSNR component and roll its weight into the reserve.
    ///      Demonstrates the exact order of operations the node owner must execute.
    function test_ownerRemovesComponentAndReallocatesReserveAfterRefund() external forkOrSkip {
        // ---- Precondition: clear the stuck deposit (registry owner) ----
        _upgradeToV2();
        vm.prank(OWNER);
        adapter.settleDepositRefund(NODE);

        INode node = INode(NODE);

        // The component must be empty for a non-forced removal; the refund made it so.
        assertEq(adapter.pendingDepositRequest(0, NODE), 0, "no pending deposit left in adapter");
        assertEq(adapter.balanceOf(NODE), 0, "node holds no wiSNR shares");
        assertTrue(node.isComponent(address(adapter)), "wiSNR is still a component pre-cleanup");
        assertTrue(node.validateComponentRatios(), "ratios sum to WAD before cleanup");

        // Capture the values needed for the reserve roll-up before we delete the allocation.
        uint64 reserveBefore = node.targetReserveRatio();
        uint64 wiSNRWeight = node.getComponentAllocation(address(adapter)).targetWeight;
        uint256 componentsBefore = node.getComponents().length;

        // Owner maintenance must happen outside the rebalance window.
        INodeRebalanceView rb = INodeRebalanceView(NODE);
        uint256 windowEnds = uint256(rb.lastRebalance()) + rb.rebalanceWindow();
        if (block.timestamp < windowEnds) {
            vm.warp(windowEnds + 1);
        }

        // ---- Step 1: node owner removes the wiSNR component (balance is 0, no force needed) ----
        vm.prank(NODE_OWNER);
        node.removeComponent(address(adapter), false);

        assertFalse(node.isComponent(address(adapter)), "wiSNR removed as a component");
        assertEq(node.getComponents().length, componentsBefore - 1, "component count decreased by one");

        // After removal, the freed 22% weight leaves the ratios short of WAD until reallocated.
        assertFalse(node.validateComponentRatios(), "ratios no longer sum to WAD until reserve absorbs delta");

        // ---- Step 2: node owner rolls the freed weight into the reserve ----
        uint64 newReserve = reserveBefore + wiSNRWeight;
        vm.prank(NODE_OWNER);
        node.updateTargetReserveRatio(newReserve);

        assertEq(node.targetReserveRatio(), newReserve, "reserve absorbed the wiSNR weight");
        assertTrue(node.validateComponentRatios(), "ratios sum back to WAD; node can rebalance again");
    }

    // =============================
    //          Helpers
    // =============================

    function _upgradeToV2() internal {
        DigiftAdapterV2 newImplementation = new DigiftAdapterV2(REGISTRY, SUB_RED_MANAGEMENT, EVENT_VERIFIER);
        vm.prank(OWNER);
        beacon.upgradeTo(address(newImplementation));
        assertEq(beacon.implementation(), address(newImplementation), "beacon points to V2");
    }

    /// @dev Mocks the DigiftEventVerifier so settlement does not require a real Merkle-proven event.
    function _mockVerifier(DigiftEventVerifier.EventType eventType, uint256 shares, uint256 assets) internal {
        EventVerifierBase.OffchainArgs memory fargs;
        DigiftEventVerifier.OnchainArgs memory nargs =
            DigiftEventVerifier.OnchainArgs(eventType, SUB_RED_MANAGEMENT, FUND, address(USDC));
        vm.mockCall(
            EVENT_VERIFIER,
            abi.encodeWithSelector(DigiftEventVerifier.verifySettlementEvent.selector, fargs, nargs),
            abi.encode(shares, assets)
        );
    }

    /// @dev Calls settleDeposit (isDeposit) or settleRedeem with empty offchain args (verifier mocked).
    function _settle(bool isDeposit) internal {
        EventVerifierBase.OffchainArgs memory fargs;
        address[] memory nodes = new address[](1);
        nodes[0] = NODE;
        vm.prank(MANAGER);
        if (isDeposit) {
            adapter.settleDeposit(nodes, fargs);
        } else {
            adapter.settleRedeem(nodes, fargs);
        }
    }
}

/// @dev Minimal view of the Node's rebalance-window state (not exposed on INode).
interface INodeRebalanceView {
    function lastRebalance() external view returns (uint64);
    function rebalanceWindow() external view returns (uint64);
}
