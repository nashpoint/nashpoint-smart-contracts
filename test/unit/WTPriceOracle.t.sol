// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {WTPriceOracle} from "src/adapters/wt/WTPriceOracle.sol";

contract WTPriceOracleTest is Test {
    address internal owner = makeAddr("owner");
    address internal operator = makeAddr("operator");
    address internal pauser = makeAddr("pauser");
    address internal stranger = makeAddr("stranger");

    uint64 internal constant INITIAL_PRICE = 100e8;
    uint8 internal constant DECIMALS = 8;
    string internal constant DESCRIPTION = "WT oracle";
    uint64 internal constant COOLDOWN = 1 days;
    uint64 internal constant PRICE_DEVIATION = 5e16; // 5%

    WTPriceOracle internal oracle;

    function setUp() public {
        oracle = new WTPriceOracle(owner, INITIAL_PRICE, DECIMALS, DESCRIPTION, COOLDOWN, PRICE_DEVIATION);

        vm.startPrank(owner);
        oracle.setOperator(operator, true);
        oracle.setPauser(pauser, true);
        vm.stopPrank();
    }

    function test_constructor_setsInitialState() external view {
        assertEq(oracle.owner(), owner);
        assertEq(oracle.decimals(), DECIMALS);
        assertEq(oracle.description(), DESCRIPTION);
        assertEq(oracle.version(), 1);
        assertEq(oracle.cooldown(), COOLDOWN);
        assertEq(oracle.priceDeviation(), PRICE_DEVIATION);
        assertTrue(oracle.operators(operator));
        assertTrue(oracle.pausers(pauser));
        assertTrue(oracle.isCooldownActive());
        assertFalse(oracle.paused());

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            oracle.latestRoundData();

        assertEq(roundId, 0);
        assertEq(answer, int256(uint256(INITIAL_PRICE)));
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 0);
    }

    function test_constructor_reverts_zeroOwner() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new WTPriceOracle(address(0), INITIAL_PRICE, DECIMALS, DESCRIPTION, COOLDOWN, PRICE_DEVIATION);
    }

    function test_constructor_reverts_zeroPrice() external {
        vm.expectRevert(WTPriceOracle.ZeroPrice.selector);
        new WTPriceOracle(owner, 0, DECIMALS, DESCRIPTION, COOLDOWN, PRICE_DEVIATION);
    }

    function test_constructor_reverts_emptyDescription() external {
        vm.expectRevert(WTPriceOracle.EmptyDescription.selector);
        new WTPriceOracle(owner, INITIAL_PRICE, DECIMALS, "", COOLDOWN, PRICE_DEVIATION);
    }

    function test_constructor_reverts_zeroCooldown() external {
        vm.expectRevert(WTPriceOracle.InvalidCooldown.selector);
        new WTPriceOracle(owner, INITIAL_PRICE, DECIMALS, DESCRIPTION, 0, PRICE_DEVIATION);
    }

    function test_constructor_reverts_zeroPriceDeviation() external {
        vm.expectRevert(abi.encodeWithSelector(WTPriceOracle.InvalidPriceDeviation.selector, uint64(0)));
        new WTPriceOracle(owner, INITIAL_PRICE, DECIMALS, DESCRIPTION, COOLDOWN, 0);
    }

    function test_constructor_reverts_priceDeviationAboveWad() external {
        uint64 invalidPriceDeviation = uint64(1e18 + 1);

        vm.expectRevert(abi.encodeWithSelector(WTPriceOracle.InvalidPriceDeviation.selector, invalidPriceDeviation));
        new WTPriceOracle(owner, INITIAL_PRICE, DECIMALS, DESCRIPTION, COOLDOWN, invalidPriceDeviation);
    }

    function test_updatePriceByOperator_reverts_notOperator() external {
        vm.expectRevert(abi.encodeWithSelector(WTPriceOracle.NotOperator.selector, stranger));
        vm.prank(stranger);
        oracle.updatePriceByOperator(101e8);
    }

    function test_updatePriceByOperator_pauses_whenCooldownActive() external {
        vm.prank(operator);
        oracle.updatePriceByOperator(101e8);

        assertTrue(oracle.paused());

        vm.expectRevert(Pausable.EnforcedPause.selector);
        oracle.latestRoundData();
    }

    function test_updatePriceByOperator_updatesPrice_afterCooldown_whenWithinRange() external {
        vm.warp(block.timestamp + COOLDOWN + 1);

        vm.expectEmit(true, true, true, true, address(oracle));
        emit WTPriceOracle.UpdatePrice(INITIAL_PRICE, 102e8);

        vm.prank(operator);
        oracle.updatePriceByOperator(102e8);

        (, int256 answer,, uint256 updatedAt,) = oracle.latestRoundData();

        assertEq(answer, int256(102e8));
        assertEq(updatedAt, block.timestamp);
        assertFalse(oracle.paused());
        assertTrue(oracle.isCooldownActive());
    }

    function test_updatePriceByOperator_pauses_whenOutsideRange() external {
        vm.warp(block.timestamp + COOLDOWN + 1);

        vm.prank(operator);
        oracle.updatePriceByOperator(106e8);

        assertTrue(oracle.paused());

        vm.expectRevert(Pausable.EnforcedPause.selector);
        oracle.latestRoundData();
    }

    function test_updatePriceByOwner_updatesPrice_evenWhenPaused() external {
        vm.prank(pauser);
        oracle.pause();

        vm.expectEmit(true, true, true, true, address(oracle));
        emit WTPriceOracle.UpdatePrice(INITIAL_PRICE, 110e8);

        vm.prank(owner);
        oracle.updatePriceByOwner(110e8);

        vm.prank(owner);
        oracle.unpause();

        (, int256 answer,, uint256 updatedAt,) = oracle.latestRoundData();

        assertEq(answer, int256(110e8));
        assertEq(updatedAt, block.timestamp);
    }

    function test_updatePriceByOwner_reverts_zeroPrice() external {
        vm.expectRevert(WTPriceOracle.ZeroPrice.selector);
        vm.prank(owner);
        oracle.updatePriceByOwner(0);
    }

    function test_pause_reverts_notPauser() external {
        vm.expectRevert(abi.encodeWithSelector(WTPriceOracle.NotPauser.selector, stranger));
        vm.prank(stranger);
        oracle.pause();
    }

    function test_pause_allowsPauser() external {
        vm.prank(pauser);
        oracle.pause();

        assertTrue(oracle.paused());
    }

    function test_pause_allowsOwner() external {
        vm.prank(owner);
        oracle.pause();

        assertTrue(oracle.paused());
    }

    function test_unpause_reverts_notOwner() external {
        vm.prank(pauser);
        oracle.pause();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        oracle.unpause();
    }

    function test_unpause_unpausesOracle() external {
        vm.prank(pauser);
        oracle.pause();

        vm.prank(owner);
        oracle.unpause();

        assertFalse(oracle.paused());
    }

    function test_setOperator_reverts_notOwner() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        oracle.setOperator(stranger, true);
    }

    function test_setOperator_updatesStatus_andEmitsEvent() external {
        vm.expectEmit(true, true, true, true, address(oracle));
        emit WTPriceOracle.OperatorChange(stranger, true);

        vm.prank(owner);
        oracle.setOperator(stranger, true);

        assertTrue(oracle.operators(stranger));
    }

    function test_setPauser_reverts_notOwner() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        oracle.setPauser(stranger, true);
    }

    function test_setPauser_updatesStatus_andEmitsEvent() external {
        vm.expectEmit(true, true, true, true, address(oracle));
        emit WTPriceOracle.PauserChange(stranger, true);

        vm.prank(owner);
        oracle.setPauser(stranger, true);

        assertTrue(oracle.pausers(stranger));
    }

    function test_setCooldown_reverts_notOwner() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        oracle.setCooldown(2 days);
    }

    function test_setCooldown_reverts_zeroValue() external {
        vm.expectRevert(WTPriceOracle.InvalidCooldown.selector);
        vm.prank(owner);
        oracle.setCooldown(0);
    }

    function test_setCooldown_updatesValue_andEmitsEvent() external {
        vm.expectEmit(true, true, true, true, address(oracle));
        emit WTPriceOracle.CooldownChange(COOLDOWN, 2 days);

        vm.prank(owner);
        oracle.setCooldown(2 days);

        assertEq(oracle.cooldown(), 2 days);
    }

    function test_setPriceDeviation_reverts_notOwner() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        oracle.setPriceDeviation(1e17);
    }

    function test_setPriceDeviation_reverts_zeroValue() external {
        vm.expectRevert(abi.encodeWithSelector(WTPriceOracle.InvalidPriceDeviation.selector, uint64(0)));
        vm.prank(owner);
        oracle.setPriceDeviation(0);
    }

    function test_setPriceDeviation_reverts_valueAboveWad() external {
        uint64 invalidPriceDeviation = uint64(1e18 + 1);

        vm.expectRevert(abi.encodeWithSelector(WTPriceOracle.InvalidPriceDeviation.selector, invalidPriceDeviation));
        vm.prank(owner);
        oracle.setPriceDeviation(invalidPriceDeviation);
    }

    function test_setPriceDeviation_updatesValue_andEmitsEvent() external {
        vm.expectEmit(true, true, true, true, address(oracle));
        emit WTPriceOracle.PriceDeviationChange(PRICE_DEVIATION, 1e17);

        vm.prank(owner);
        oracle.setPriceDeviation(1e17);

        assertEq(oracle.priceDeviation(), 1e17);
    }
}
