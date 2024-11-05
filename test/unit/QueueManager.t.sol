// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "../BaseTest.sol";
import {QueueManager} from "src/QueueManager.sol";
import {IQueueManager, QueueState} from "src/interfaces/IQueueManager.sol";
import {INode} from "src/interfaces/INode.sol";
import {Node} from "src/Node.sol";
import {ErrorsLib} from "src/libraries/ErrorsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";

contract QueueManagerHarness is QueueManager {
    constructor(address node_) QueueManager(node_) {}

    function calculatePrice(uint128 assets, uint128 shares) external view returns (uint256 price) {
        return _calculatePrice(assets, shares);
    }

    function calculateShares(uint128 assets, uint256 price, MathLib.Rounding rounding) external view returns (uint128 shares) {
        return _calculateShares(assets, price, rounding);
    }

    function calculateAssets(uint128 shares, uint256 price, MathLib.Rounding rounding) external view returns (uint128 assets) {
        return _calculateAssets(shares, price, rounding);
    }

    function processDeposit(address user, uint128 sharesUp, uint128 sharesDown, address receiver) external {
        QueueState storage state = queueStates[user];
        _processDeposit(state, sharesUp, sharesDown, receiver);
    }
}

contract MockQuoter {
    uint128 public price;
    
    constructor(uint128 _price) {
        price = _price;
    }
    
    function getPrice(address) external view returns (uint128) {
        return price;
    }
    
    function setPrice(uint128 _price) external {
        price = _price;
    }
}

contract QueueManagerTest is BaseTest {
    QueueManager public manager;
    QueueManagerHarness public harness;
    MockQuoter public mockQuoter;
    address public controller;
    
    function setUp() public override {
        super.setUp();
        
        // Setup mock quoter
        mockQuoter = new MockQuoter(1 ether); // 1:1 initial price
        
        // Setup node with mocks
        vm.startPrank(owner);
        node.setQuoter(address(mockQuoter));       
        vm.stopPrank();
        
        // Deploy manager and harness
        manager = new QueueManager(address(node));
        harness = new QueueManagerHarness(address(node));
        
        // Setup test addresses
        controller = makeAddr("controller");
        
        // Label addresses
        vm.label(address(manager), "QueueManager");
        vm.label(address(harness), "QueueManagerHarness");
        vm.label(address(mockQuoter), "MockQuoter");
        vm.label(controller, "Controller");
    }

    function test_deployment() public {
        QueueManager newManager = new QueueManager(address(node));
        assertEq(address(newManager.node()), address(node));
    }

    function test_deployment_RevertIf_ZeroNode() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new QueueManager(address(0));
    }

    function testPrice() public {
        assertEq(harness.calculatePrice(1, 0), 0);
        assertEq(harness.calculatePrice(0, 1), 0);
        assertEq(harness.calculatePrice(1 ether, 1 ether), 1 ether);
        assertEq(harness.calculatePrice(2 ether, 1 ether), 2 ether);
        assertEq(harness.calculatePrice(1 ether, 2 ether), 0.5 ether);
    }

    function test_requestDeposit() public {
        vm.prank(address(node));
        assertTrue(manager.requestDeposit(100, controller));
        assertEq(manager.pendingDepositRequest(controller), 100);
    }

    function test_requestDeposit_revert_NotNode() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.requestDeposit(100, controller);
    }

    function test_requestDeposit_revert_ZeroAmount() public {
        vm.prank(address(node));
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        manager.requestDeposit(0, controller);
    }

    function test_requestRedeem() public {
        vm.prank(address(node));
        assertTrue(manager.requestRedeem(100, controller));
        assertEq(manager.pendingRedeemRequest(controller), 100);
    }

    function test_requestRedeem_revert_NotNode() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.requestRedeem(100, controller);
    }

    function test_requestRedeem_revert_ZeroAmount() public {
        vm.prank(address(node));
        vm.expectRevert(ErrorsLib.ZeroAmount.selector);
        manager.requestRedeem(0, controller);
    }

    function test_fulfillDepositRequest() public {
        // Setup initial request
        vm.prank(address(node));
        manager.requestDeposit(100, controller);

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("mint(address,uint256)"))),
            abi.encode()
        );
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("onDepositClaimable(address,uint128,uint128)"))),
            abi.encode()
        );

        // Test fulfillment
        vm.prank(rebalancer);
        manager.fulfillDepositRequest(controller, 50, 50);

        // Verify state changes
        (
            uint128 maxMint,
            uint128 maxWithdraw,
            uint256 depositPrice,
            uint256 redeemPrice,
            uint128 pendingDepositRequest,
            uint128 pendingRedeemRequest
        ) = manager.queueStates(controller);

        assertEq(pendingDepositRequest, 50);
        assertEq(maxMint, 50);
        assertEq(depositPrice, 1 ether);
    }

    function test_fulfillDepositRequest_revert_NotRebalancer() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.fulfillDepositRequest(controller, 50, 50);
    }

    function test_fulfillDepositRequest_revert_NoPendingRequest() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NoPendingDepositRequest.selector);
        manager.fulfillDepositRequest(controller, 50, 50);
    }

    function test_fulfillRedeemRequest_revert_NotRebalancer() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.fulfillRedeemRequest(controller, 50, 50);
    }

    function test_fulfillRedeemRequest_revert_NoPendingRequest() public {
        vm.prank(rebalancer);
        vm.expectRevert(ErrorsLib.NoPendingRedeemRequest.selector);
        manager.fulfillRedeemRequest(controller, 50, 50);
    }

    function test_convertToShares() public {
        assertEq(manager.convertToShares(100 ether), 100 ether); // 1:1 price
        
        // Change price and test again
        mockQuoter.setPrice(2 ether);
        assertEq(manager.convertToShares(100 ether), 50 ether); // 2:1 price
    }

    function test_convertToAssets() public {
        assertEq(manager.convertToAssets(100 ether), 100 ether); // 1:1 price
        
        // Change price and test again
        mockQuoter.setPrice(2 ether);
        assertEq(manager.convertToAssets(100 ether), 200 ether); // 1:2 price
    }

    function test_maxDeposit() public {
        // Setup initial request
        vm.prank(address(node));
        manager.requestDeposit(100 ether, controller);

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("mint(address,uint256)"))),
            abi.encode()
        );
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("onDepositClaimable(address,uint128,uint128)"))),
            abi.encode()
        );
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("escrow()"))),
            abi.encode(address(escrow))
        );

        // Setup state with deposit price
        vm.prank(rebalancer);
        manager.fulfillDepositRequest(controller, 100 ether, 100 ether);

        assertEq(manager.maxDeposit(controller), 100 ether);
    }

    function test_maxMint() public {
        // Setup initial request
        vm.prank(address(node));
        manager.requestDeposit(100 ether, controller);

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("mint(address,uint256)"))),
            abi.encode()
        );
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("onDepositClaimable(address,uint128,uint128)"))),
            abi.encode()
        );
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("escrow()"))),
            abi.encode(address(escrow))
        );

        // Setup state
        vm.prank(rebalancer);
        manager.fulfillDepositRequest(controller, 100 ether, 100 ether);

        assertEq(manager.maxMint(controller), 100 ether);
    }

    function test_maxWithdraw() public {
        // Setup initial redeem request
        vm.prank(address(node));
        manager.requestRedeem(100 ether, controller);

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("burn(address,uint256)"))),
            abi.encode()
        );
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("onRedeemClaimable(address,uint128,uint128)"))),
            abi.encode()
        );

        // Setup state with redeem price by fulfilling request
        vm.prank(rebalancer);
        manager.fulfillRedeemRequest(controller, 100 ether, 100 ether);

        // Test maxWithdraw
        assertEq(manager.maxWithdraw(controller), 100 ether);
    }

    function test_maxRedeem() public {
        // Setup initial redeem request
        vm.prank(address(node));
        manager.requestRedeem(100 ether, controller);

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("burn(address,uint256)"))),
            abi.encode()
        );
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("onRedeemClaimable(address,uint128,uint128)"))),
            abi.encode()
        );  

        // Setup state with redeem price by fulfilling request
        vm.prank(rebalancer);
        manager.fulfillRedeemRequest(controller, 100 ether, 100 ether);

        assertEq(manager.maxRedeem(controller), 100 ether);
    }   

    function test_pendingDepositRequest() public {        
        vm.prank(address(node));
        manager.requestDeposit(100 ether, controller);

        assertEq(manager.pendingDepositRequest(controller), 100 ether);
    }

    function test_pendingRedeemRequest() public {
        vm.prank(address(node));
        manager.requestRedeem(100 ether, controller);

        assertEq(manager.pendingRedeemRequest(controller), 100 ether);
    }

    function test_deposit() public {
        // Setup initial request
        vm.prank(address(node));
        manager.requestDeposit(100 ether, controller);

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("mint(address,uint256)"))),
            abi.encode()
        );

        // Give Escrow the tokens it needs
        deal(address(node), address(escrow), 100 ether);

        // Setup escrow approval
        vm.prank(address(escrow));
        node.approve(address(manager), 100 ether);

        // Test deposit
        vm.prank(rebalancer);
        manager.fulfillDepositRequest(controller, 100 ether, 100 ether);

        vm.prank(address(node));
        manager.deposit(100 ether, controller, controller);

        assertEq(node.balanceOf(controller), 100 ether);
    }

    function test_deposit_revert_notNode() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.deposit(100 ether, controller, controller);
    }

    function test_deposit_revert_exceedsMaxDeposit() public {
        vm.prank(address(node));
        manager.requestDeposit(100 ether, controller);

        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("maxDeposit(address)"))),
            abi.encode(90 ether)
        );

        vm.prank(address(node));
        vm.expectRevert(ErrorsLib.ExceedsMaxDeposit.selector);
        manager.deposit(100 ether, controller, controller);
    }

    function test_mint() public {
        // Setup initial request
        vm.prank(address(node));
        manager.requestDeposit(100 ether, controller);

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("mint(address,uint256)"))),
            abi.encode()
        );

        // Give Escrow the tokens it needs
        deal(address(node), address(escrow), 100 ether);

        // Setup escrow approval
        vm.prank(address(escrow));
        node.approve(address(manager), 100 ether);

        // Test deposit
        vm.prank(rebalancer);
        manager.fulfillDepositRequest(controller, 100 ether, 100 ether);

        vm.prank(address(node));
        manager.mint(100 ether, controller, controller);

        assertEq(node.balanceOf(controller), 100 ether);
    }

    function test_mint_revert_notNode() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.mint(100 ether, controller, controller);
    }

    function test_mint_revert_exceedsMaxMint() public {
        vm.prank(address(node));
        manager.requestDeposit(100 ether, controller);

        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("maxMint(address)"))),
            abi.encode(90 ether)
        );

        vm.prank(address(node));
        vm.expectRevert(ErrorsLib.ExceedsMaxMint.selector);
        manager.mint(100 ether, controller, controller);
        
    }

    function test_redeem() public {
        // Setup initial request
        vm.prank(address(node));
        manager.requestRedeem(100 ether, controller);   

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("burn(address,uint256)"))),
            abi.encode()
        );

        // Setup escrow approval
        vm.prank(address(escrow));
        asset.approve(address(manager), 100 ether);  

        // Give Escrow the tokens it needs
        deal(address(asset), address(escrow), 100 ether);

        // Test redeem
        vm.prank(rebalancer);
        manager.fulfillRedeemRequest(controller, 100 ether, 100 ether);

        vm.prank(address(node));
        manager.redeem(100 ether, controller, controller);

        assertEq(asset.balanceOf(controller), 100 ether);
    }

    function test_redeem_revert_notNode() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.redeem(100 ether, controller, controller);
    }

    function test_redeem_revert_exceedsMaxRedeem() public {
        vm.prank(address(node));
        manager.requestRedeem(100 ether, controller);

        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("maxRedeem(address)"))),
            abi.encode(90 ether)
        );

        vm.prank(address(node));
        vm.expectRevert(ErrorsLib.ExceedsMaxRedeem.selector);
        manager.redeem(100 ether, controller, controller);
    }

    function test_withdraw() public {
        // Setup initial request
        vm.prank(address(node));
        manager.requestRedeem(100 ether, controller);   

        // Setup node mock expectations
        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("burn(address,uint256)"))),
            abi.encode()
        );

        // Setup escrow approval
        vm.prank(address(escrow));
        asset.approve(address(manager), 100 ether);  

        // Give Escrow the tokens it needs
        deal(address(asset), address(escrow), 100 ether);

        // Test redeem
        vm.prank(rebalancer);
        manager.fulfillRedeemRequest(controller, 100 ether, 100 ether);

        vm.prank(address(node));
        manager.withdraw(100 ether, controller, controller);

        assertEq(asset.balanceOf(controller), 100 ether);
    }

    function test_withdraw_revert_notNode() public {
        vm.prank(randomUser);
        vm.expectRevert(ErrorsLib.InvalidSender.selector);
        manager.withdraw(100 ether, controller, controller);
    }  

    function test_withdraw_revert_exceedsMaxWithdraw() public {
        vm.prank(address(node));
        manager.requestRedeem(100 ether, controller);

        vm.mockCall(
            address(node),
            abi.encodeWithSelector(bytes4(keccak256("maxWithdraw(address)"))),
            abi.encode(90 ether)
        );

        vm.prank(address(node));
        vm.expectRevert(ErrorsLib.ExceedsMaxWithdraw.selector);
        manager.withdraw(100 ether, controller, controller);    
    }

    function test_calculateShare_returnZeroIf_ZeroPrice() public view {
        assertEq(harness.calculateShares(0, 1 ether, MathLib.Rounding.Down), 0);
        assertEq(harness.calculateShares(1 ether, 0, MathLib.Rounding.Down), 0);        
    }

    function test_calculateAsset_returnZeroIf_ZeroPrice() public view {
        assertEq(harness.calculateAssets(0, 1 ether, MathLib.Rounding.Down), 0);
        assertEq(harness.calculateAssets(1 ether, 0, MathLib.Rounding.Down), 0);
    }
}
