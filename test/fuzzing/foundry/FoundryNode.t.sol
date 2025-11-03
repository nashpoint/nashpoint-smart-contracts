// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../FuzzNode.sol";

/**
 * @title FoundryNode
 * @notice Foundry tests for FuzzNode handlers - testing user lifecycle scenarios
 * @dev Tests verify that handlers can properly call functions without errors
 *      Each test represents a happy path user story with 3+ handler calls
 */
contract FoundryNode is FuzzNode {
    /**
     * @notice Setup function to initialize the fuzzing environment
     */
    function setUp() public {
        fuzzSetup();
        clearNodeContextOverrideForTest();
    }
    /**
     * @notice Test deposit and mint lifecycle
     * @dev User deposits assets, then mints shares
     */

    function test_handler_deposit_mint() public {
        setActor(USERS[1]);
        fuzz_deposit(5e17);

        setActor(USERS[2]);
        fuzz_deposit(3e17);

        setActor(USERS[1]);
        fuzz_mint(2e17);

        setActor(USERS[2]);
        fuzz_mint(1e17);
    }

    /**
     * @notice Test deposit and redeem request lifecycle
     * @dev User deposits, then requests redemption (without withdrawal)
     */
    function test_handler_deposit_requestRedeem() public {
        setActor(USERS[1]);
        fuzz_deposit(8e17);

        setActor(USERS[2]);
        fuzz_deposit(5e17);

        setActor(USERS[1]);
        fuzz_requestRedeem(3e17);

        setActor(USERS[2]);
        fuzz_mint(4e17);
    }

    /**
     * @notice Test mint and request redeem lifecycle
     * @dev User mints shares, then requests redemption
     */
    function test_handler_mint_requestRedeem() public {
        setActor(USERS[1]);
        fuzz_mint(6e17);

        setActor(USERS[2]);
        fuzz_mint(4e17);

        setActor(USERS[3]);
        fuzz_deposit(5e17);

        setActor(USERS[1]);
        fuzz_requestRedeem(2e17);
    }

    /**
     * @notice Test approval and transfer lifecycle
     * @dev User deposits, approves another user, and transfers shares
     */
    function test_handler_deposit_approve_transfer() public {
        setActor(USERS[1]);
        fuzz_deposit(7e17);

        setActor(USERS[1]);
        fuzz_node_approve(2, 5e17);

        setActor(USERS[1]);
        fuzz_node_transfer(3, 3e17);

        setActor(USERS[3]);
        fuzz_deposit(2e17);
    }

    /**
     * @notice Test transferFrom lifecycle
     * @dev User deposits, approves spender, spender transfers on behalf
     */
    function test_handler_approve_transferFrom() public {
        setActor(USERS[1]);
        fuzz_deposit(9e17);

        setActor(USERS[1]);
        fuzz_node_approve(2, 6e17);

        setActor(USERS[2]);
        fuzz_node_transferFrom(1, 4e17);

        setActor(USERS[2]);
        fuzz_deposit(3e17);
    }

    /**
     * @notice Test operator setting and deposit lifecycle
     * @dev User sets operator and makes deposits
     */
    function test_handler_setOperator_deposits() public {
        setActor(USERS[1]);
        fuzz_setOperator(2, true);

        setActor(USERS[1]);
        fuzz_deposit(6e17);

        setActor(USERS[2]);
        fuzz_deposit(4e17);

        setActor(USERS[1]);
        fuzz_mint(3e17);
    }

    /**
     * @notice Test multiple deposits with transfers
     * @dev Users make deposits and transfer shares between them
     */
    function test_handler_deposits_and_transfers() public {
        setActor(USERS[1]);
        fuzz_deposit(5e17);

        setActor(USERS[2]);
        fuzz_deposit(4e17);

        setActor(USERS[1]);
        fuzz_node_transfer(2, 2e17);

        setActor(USERS[3]);
        fuzz_mint(3e17);
    }

    /**
     * @notice Test deposits with operator and approvals
     * @dev Users make deposits and set operators
     */
    function test_handler_deposits_operators() public {
        setActor(USERS[1]);
        fuzz_deposit(6e17);

        setActor(USERS[1]);
        fuzz_setOperator(2, true);

        setActor(USERS[2]);
        fuzz_deposit(3e17);

        setActor(USERS[3]);
        fuzz_mint(4e17);
    }

    /**
     * @notice Test complex multi-user deposit and withdrawal lifecycle
     * @dev Multiple users deposit, some redeem, creating realistic usage
     */
    function test_handler_multiuser_lifecycle() public {
        setActor(USERS[1]);
        fuzz_deposit(7e17);

        setActor(USERS[2]);
        fuzz_deposit(6e17);

        setActor(USERS[3]);
        fuzz_deposit(5e17);

        setActor(USERS[1]);
        fuzz_requestRedeem(3e17);

        setActor(USERS[2]);
        fuzz_mint(4e17);

        setActor(USERS[3]);
        fuzz_node_transfer(1, 2e17);
    }

    /**
     * @notice Test consecutive deposits and mints by same user
     * @dev User makes multiple deposits and mints in sequence
     */
    function test_handler_consecutive_operations() public {
        setActor(USERS[1]);
        fuzz_deposit(4e17);

        setActor(USERS[1]);
        fuzz_deposit(3e17);

        setActor(USERS[1]);
        fuzz_mint(5e17);

        setActor(USERS[1]);
        fuzz_mint(2e17);
    }

    /**
     * @notice Test redemption requests with multiple users
     * @dev Users deposit and request redemptions
     */
    function test_handler_redemption_requests() public {
        setActor(USERS[1]);
        fuzz_deposit(8e17);

        setActor(USERS[2]);
        fuzz_deposit(7e17);

        setActor(USERS[3]);
        fuzz_mint(5e17);

        setActor(USERS[1]);
        fuzz_requestRedeem(4e17);

        setActor(USERS[2]);
        fuzz_requestRedeem(3e17);

        setActor(USERS[3]);
        fuzz_deposit(2e17);
    }

    /**
     * @notice Test component yield adjustments via gain/lose backing helpers
     * @dev Exercises both ERC4626 and ERC7540 component paths
     */
    function test_handler_component_yield_adjustments() public {
        forceNodeContextForTest(0);

        (address[] memory syncComponents, address[] memory asyncComponents) = _componentLists();
        uint256 total = syncComponents.length + asyncComponents.length;
        if (total == 0) {
            clearNodeContextOverrideForTest();
            return;
        }

        uint256 amountSeed = 1e18;
        for (uint256 idx = 0; idx < total; idx++) {
            uint256 gainSeed = _seedForComponentIndex(idx, total, 0);
            address component = _componentAtIndex(idx, syncComponents, asyncComponents);

            uint256 beforeGain = asset.balanceOf(component);
            fuzz_component_gainBacking(gainSeed, amountSeed);
            uint256 afterGain = asset.balanceOf(component);
            assertGt(afterGain, beforeGain, "gain should increase balance");

            uint256 loseSeed = _seedForComponentIndex(idx, total, 1);
            fuzz_component_loseBacking(loseSeed, amountSeed / 2);
            uint256 afterLose = asset.balanceOf(component);
            assertLt(afterLose, afterGain, "lose should decrease balance");
        }

        clearNodeContextOverrideForTest();
    }

    function test_component_gainBacking_all_components() public {
        forceNodeContextForTest(0);

        (address[] memory syncComponents, address[] memory asyncComponents) = _componentLists();
        uint256 total = syncComponents.length + asyncComponents.length;
        if (total == 0) {
            clearNodeContextOverrideForTest();
            return;
        }

        uint256 amountSeed = 5e17;
        for (uint256 idx = 0; idx < total; idx++) {
            uint256 gainSeed = _seedForComponentIndex(idx, total, 0);
            address component = _componentAtIndex(idx, syncComponents, asyncComponents);

            uint256 before = asset.balanceOf(component);
            fuzz_component_gainBacking(gainSeed, amountSeed);
            uint256 afterBalance = asset.balanceOf(component);
            assertGt(afterBalance, before, "component gain backing failed");
        }

        clearNodeContextOverrideForTest();
    }

    function test_component_loseBacking_all_components() public {
        forceNodeContextForTest(0);

        (address[] memory syncComponents, address[] memory asyncComponents) = _componentLists();
        uint256 total = syncComponents.length + asyncComponents.length;
        if (total == 0) {
            clearNodeContextOverrideForTest();
            return;
        }

        uint256 gainSeedBase = 0;
        uint256 amountSeed = 8e17;
        for (uint256 idx = 0; idx < total; idx++) {
            uint256 gainSeed = _seedForComponentIndex(idx, total, gainSeedBase);
            fuzz_component_gainBacking(gainSeed, amountSeed);
        }

        for (uint256 idx = 0; idx < total; idx++) {
            uint256 loseSeed = _seedForComponentIndex(idx, total, 2);
            address component = _componentAtIndex(idx, syncComponents, asyncComponents);

            uint256 before = asset.balanceOf(component);
            fuzz_component_loseBacking(loseSeed, amountSeed / 2);
            uint256 afterBalance = asset.balanceOf(component);
            if (before > 0) {
                assertLt(afterBalance, before, "component lose backing should decrease balance");
            }
        }

        clearNodeContextOverrideForTest();
    }

    function test_erc4626_static_vault_no_yield() public {
        forceNodeContextForTest(0);

        address user = USERS[1];
        uint256 amount = 10_000 ether;
        assetToken.mint(user, amount);

        vm.startPrank(user);
        asset.approve(address(vault), type(uint256).max);
        uint256 shares = vault.deposit(amount, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        vm.startPrank(user);
        uint256 redeemed = vault.redeem(shares, user, user);
        vm.stopPrank();

        assertEq(redeemed, amount, "Static vault should preserve principal");

        clearNodeContextOverrideForTest();
    }

    function test_erc4626_linear_vault_accumulates_yield() public {
        forceNodeContextForTest(0);

        address user = USERS[2];
        uint256 amount = 15_000 ether;
        assetToken.mint(user, amount);

        vm.startPrank(user);
        asset.approve(address(vaultSecondary), type(uint256).max);
        uint256 shares = vaultSecondary.deposit(amount, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 14 days);

        vm.startPrank(user);
        uint256 redeemed = vaultSecondary.redeem(shares, user, user);
        vm.stopPrank();

        assertGt(redeemed, amount, "Linear vault should grow principal");

        clearNodeContextOverrideForTest();
    }

    function test_erc4626_negative_vault_loses_yield() public {
        forceNodeContextForTest(0);

        address user = USERS[3];
        uint256 amount = 20_000 ether;
        assetToken.mint(user, amount);

        vm.startPrank(user);
        asset.approve(address(vaultTertiary), type(uint256).max);
        uint256 shares = vaultTertiary.deposit(amount, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(user);
        uint256 redeemed = vaultTertiary.redeem(shares, user, user);
        vm.stopPrank();

        assertLt(redeemed, amount, "Negative vault should erode principal");

        clearNodeContextOverrideForTest();
    }

    function test_erc7540_linear_vault_positive_yield() public {
        forceNodeContextForTest(0);

        address user = USERS[1];
        uint256 amount = 25_000 ether;
        assetToken.mint(user, amount);

        vm.startPrank(user);
        asset.approve(address(liquidityPoolSecondary), type(uint256).max);
        ERC7540Mock(liquidityPoolSecondary).requestDeposit(amount, user, user);
        vm.stopPrank();

        vm.prank(poolManager);
        ERC7540Mock(liquidityPoolSecondary).processPendingDeposits();

        uint256 shares = ERC7540Mock(liquidityPoolSecondary).claimableShares();
        vm.prank(user);
        ERC7540Mock(liquidityPoolSecondary).mint(shares, user, user);

        vm.warp(block.timestamp + 7 days);

        vm.prank(user);
        ERC7540Mock(liquidityPoolSecondary).requestRedeem(shares, user, user);

        vm.prank(poolManager);
        ERC7540Mock(liquidityPoolSecondary).processPendingRedemptions();

        uint256 claimable = ERC7540Mock(liquidityPoolSecondary).claimableRedeemRequest(0, user);
        vm.prank(user);
        uint256 redeemed = ERC7540Mock(liquidityPoolSecondary).withdraw(claimable, user, user);

        assertGt(redeemed, amount, "Async linear vault should grow principal");

        clearNodeContextOverrideForTest();
    }

    function test_erc7540_negative_vault_declines() public {
        forceNodeContextForTest(0);

        address user = USERS[2];
        uint256 amount = 18_000 ether;
        assetToken.mint(user, amount);

        vm.startPrank(user);
        asset.approve(address(liquidityPoolTertiary), type(uint256).max);
        ERC7540Mock(liquidityPoolTertiary).requestDeposit(amount, user, user);
        vm.stopPrank();

        vm.prank(poolManager);
        ERC7540Mock(liquidityPoolTertiary).processPendingDeposits();

        uint256 shares = ERC7540Mock(liquidityPoolTertiary).claimableShares();
        vm.prank(user);
        ERC7540Mock(liquidityPoolTertiary).mint(shares, user, user);

        vm.warp(block.timestamp + 9 days);

        vm.prank(user);
        ERC7540Mock(liquidityPoolTertiary).requestRedeem(shares, user, user);

        vm.prank(poolManager);
        ERC7540Mock(liquidityPoolTertiary).processPendingRedemptions();

        uint256 claimable = ERC7540Mock(liquidityPoolTertiary).claimableRedeemRequest(0, user);
        vm.prank(user);
        uint256 redeemed = ERC7540Mock(liquidityPoolTertiary).withdraw(claimable, user, user);

        assertLt(redeemed, amount, "Async negative vault should erode principal");

        clearNodeContextOverrideForTest();
    }

    function _componentLists()
        internal
        view
        returns (address[] memory syncComponents, address[] memory asyncComponents)
    {
        syncComponents = componentsByRouterForTest(address(router4626));
        asyncComponents = componentsByRouterForTest(address(router7540));
    }

    function _componentAtIndex(uint256 index, address[] memory syncComponents, address[] memory asyncComponents)
        internal
        pure
        returns (address)
    {
        if (index < syncComponents.length) {
            return syncComponents[index];
        }
        return asyncComponents[index - syncComponents.length];
    }

    function _seedForComponentIndex(uint256 index, uint256 total, uint256 iteration) internal pure returns (uint256) {
        return index + total * iteration;
    }
}
