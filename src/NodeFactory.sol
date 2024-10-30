// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ERC4626Rebalancer} from "./rebalancers/ERC4626Rebalancer.sol";
import {Escrow} from "./Escrow.sol";
import {Node} from "./Node.sol";
import {QueueManager} from "./QueueManager.sol";
import {Quoter} from "./Quoter.sol";

import {IERC4626Rebalancer} from "./interfaces/IERC4626Rebalancer.sol";
import {IEscrow} from "./interfaces/IEscrow.sol";
import {INode} from "./interfaces/INode.sol";
import {INodeFactory} from "./interfaces/INodeFactory.sol";
import {IQueueManager} from "./interfaces/IQueueManager.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title NodeFactory
/// @author ODND Studios
contract NodeFactory is INodeFactory {
    /* STORAGE */
    /// @inheritdoc INodeFactory
    mapping(address => bool) public isNode;

    /* EXTERNAL FUNCTIONS */
    /// @inheritdoc INodeFactory
    function deployFullNode(address asset, string memory name, string memory symbol, address owner, bytes32 salt)
        external
        returns (
            INode node,
            IEscrow escrow,
            IQuoter quoter,
            IQueueManager manager,
            IERC4626Rebalancer erc4626Rebalancer
        )
    {
        escrow = createEscrow(owner, salt);

        node = createNode(asset, name, symbol, address(escrow), address(0), address(this), salt);

        quoter = createQuoter(address(node), owner, salt);

        manager = createQueueManager(address(node), address(quoter), owner, salt);

        erc4626Rebalancer = createERC4626Rebalancer(address(node), owner, salt);

        node.setManager(address(manager));
        node.addRebalancer(address(erc4626Rebalancer));
        Ownable(address(node)).transferOwnership(owner);
    }

    /// @inheritdoc INodeFactory
    function createERC4626Rebalancer(address node, address owner, bytes32 salt)
        public
        returns (IERC4626Rebalancer rebalancer)
    {
        if (node == address(0) || owner == address(0)) revert ErrorsLib.ZeroAddress();
        rebalancer = IERC4626Rebalancer(address(new ERC4626Rebalancer{salt: salt}(node, owner)));
    }

    /// @inheritdoc INodeFactory
    function createEscrow(address owner, bytes32 salt) public returns (IEscrow escrow) {
        if (owner == address(0)) revert ErrorsLib.ZeroAddress();
        escrow = IEscrow(address(new Escrow{salt: salt}(owner)));
    }

    /// @inheritdoc INodeFactory
    function createNode(
        address asset,
        string memory name,
        string memory symbol,
        address escrow,
        address manager,
        address owner,
        bytes32 salt
    ) public returns (INode node) {
        if (asset == address(0) || escrow == address(0) || owner == address(0)) revert ErrorsLib.ZeroAddress();
        if (bytes(name).length == 0) revert ErrorsLib.InvalidName();
        if (bytes(symbol).length == 0) revert ErrorsLib.InvalidSymbol();

        node = INode(address(new Node{salt: salt}(asset, name, symbol, escrow, manager, new address[](0), owner)));

        isNode[address(node)] = true;
        emit EventsLib.CreateNode(address(node), asset, name, symbol, owner, salt);
    }

    /// @inheritdoc INodeFactory
    function createQueueManager(address node, address quoter, address owner, bytes32 salt)
        public
        returns (IQueueManager manager)
    {
        if (node == address(0) || quoter == address(0) || owner == address(0)) revert ErrorsLib.ZeroAddress();
        manager = IQueueManager(address(new QueueManager{salt: salt}(node, quoter, owner)));
    }

    /// @inheritdoc INodeFactory
    function createQuoter(address node, address owner, bytes32 salt) public returns (IQuoter quoter) {
        if (node == address(0) || owner == address(0)) revert ErrorsLib.ZeroAddress();
        quoter = IQuoter(address(new Quoter{salt: salt}(node, owner)));
    }
}
