// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FuzzStorageVariables.sol";

/**
 * @title HelperFunctions
 * @notice Centralized location for all reusable helper functions in the UniversalFuzzing framework
 *
 * @dev This contract serves as the single source of truth for utility functions that are used
 *      across multiple handlers, preconditions, postconditions, or properties.
 */
contract HelperFunctions is FuzzStorageVariables {
    function generateFuzzNumber(uint256 iteration, uint256 seed) internal returns (uint256) {
        uint256 result;
        unchecked {
            result = iteration * PRIME + seed;
        }
        return uint256(keccak256(abi.encodePacked(result)));
    }

    function toString(address value) internal pure returns (string memory str) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(value)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    // ==============================================================
    // INTERNAL HELPERS (SHARED)
    // ==============================================================

    function _appendUnique(address[] storage list, address value) internal {
        if (value == address(0)) {
            return;
        }
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == value) {
                return;
            }
        }
        list.push(value);
    }

    function _registerManagedNode(address nodeAddr, address escrowAddr) internal {
        if (nodeAddr == address(0) || escrowAddr == address(0)) {
            return;
        }

        if (MANAGED_NODE_ESCROWS[nodeAddr] == address(0)) {
            if (MANAGED_NODES.length >= MAX_MANAGED_NODES) {
                return;
            }
            MANAGED_NODES.push(nodeAddr);
            _appendUnique(TOKENS, nodeAddr);
            _appendUnique(DONATEES, nodeAddr);
            _appendUnique(DONATEES, escrowAddr);
        }

        MANAGED_NODE_ESCROWS[nodeAddr] = escrowAddr;
    }

    function _setActiveNode(address nodeAddr) internal {
        if (nodeAddr == address(0)) {
            return;
        }

        address escrowAddr = MANAGED_NODE_ESCROWS[nodeAddr];
        if (escrowAddr == address(0)) {
            return;
        }

        node = INode(nodeAddr);
        escrow = Escrow(escrowAddr);
    }

    function _setActiveNodeByIndex(uint256 index) internal {
        if (index >= MANAGED_NODES.length) {
            return;
        }

        _setActiveNode(MANAGED_NODES[index]);
    }

    function _recordDigiftPendingDeposit(address nodeAddr, address component, uint256 assets) internal {
        if (nodeAddr == address(0) || component == address(0) || assets == 0) {
            return;
        }

        DIGIFT_PENDING_DEPOSITS.push(DigiftPendingDepositRecord({node: nodeAddr, component: component, assets: assets}));
    }

    function _pendingDigiftDepositCount() internal view returns (uint256) {
        return DIGIFT_PENDING_DEPOSITS.length;
    }

    function _getDigiftPendingDeposit(uint256 index) internal view returns (DigiftPendingDepositRecord memory) {
        if (index >= DIGIFT_PENDING_DEPOSITS.length) {
            return DigiftPendingDepositRecord({node: address(0), component: address(0), assets: 0});
        }
        return DIGIFT_PENDING_DEPOSITS[index];
    }

    function _consumeDigiftPendingDeposit(uint256 index) internal returns (DigiftPendingDepositRecord memory record) {
        uint256 length = DIGIFT_PENDING_DEPOSITS.length;
        if (length == 0 || index >= length) {
            return DigiftPendingDepositRecord({node: address(0), component: address(0), assets: 0});
        }

        record = DIGIFT_PENDING_DEPOSITS[index];
        if (index != length - 1) {
            DIGIFT_PENDING_DEPOSITS[index] = DIGIFT_PENDING_DEPOSITS[length - 1];
        }
        DIGIFT_PENDING_DEPOSITS.pop();
    }

    function _recordDigiftForwardedDeposit(DigiftPendingDepositRecord memory record) internal {
        if (record.node == address(0) || record.component == address(0) || record.assets == 0) {
            return;
        }
        DIGIFT_FORWARDED_DEPOSITS.push(record);
    }

    function _forwardedDigiftDepositCount() internal view returns (uint256) {
        return DIGIFT_FORWARDED_DEPOSITS.length;
    }

    function _getDigiftForwardedDeposit(uint256 index) internal view returns (DigiftPendingDepositRecord memory) {
        if (index >= DIGIFT_FORWARDED_DEPOSITS.length) {
            return DigiftPendingDepositRecord({node: address(0), component: address(0), assets: 0});
        }
        return DIGIFT_FORWARDED_DEPOSITS[index];
    }

    function _consumeDigiftForwardedDeposit(uint256 index)
        internal
        returns (DigiftPendingDepositRecord memory record)
    {
        uint256 length = DIGIFT_FORWARDED_DEPOSITS.length;
        if (length == 0 || index >= length) {
            return DigiftPendingDepositRecord({node: address(0), component: address(0), assets: 0});
        }

        record = DIGIFT_FORWARDED_DEPOSITS[index];
        if (index != length - 1) {
            DIGIFT_FORWARDED_DEPOSITS[index] = DIGIFT_FORWARDED_DEPOSITS[length - 1];
        }
        DIGIFT_FORWARDED_DEPOSITS.pop();
    }

    function _recordDigiftPendingRedemption(address nodeAddr, address component, uint256 shares) internal {
        if (nodeAddr == address(0) || component == address(0) || shares == 0) {
            return;
        }

        DIGIFT_PENDING_REDEMPTIONS.push(
            DigiftPendingRedemptionRecord({node: nodeAddr, component: component, shares: shares})
        );
    }

    function _pendingDigiftRedemptionCount() internal view returns (uint256) {
        return DIGIFT_PENDING_REDEMPTIONS.length;
    }

    function _getDigiftPendingRedemption(uint256 index) internal view returns (DigiftPendingRedemptionRecord memory) {
        if (index >= DIGIFT_PENDING_REDEMPTIONS.length) {
            return DigiftPendingRedemptionRecord({node: address(0), component: address(0), shares: 0});
        }
        return DIGIFT_PENDING_REDEMPTIONS[index];
    }

    function _consumeDigiftPendingRedemption(uint256 index)
        internal
        returns (DigiftPendingRedemptionRecord memory record)
    {
        uint256 length = DIGIFT_PENDING_REDEMPTIONS.length;
        if (length == 0 || index >= length) {
            return DigiftPendingRedemptionRecord({node: address(0), component: address(0), shares: 0});
        }

        record = DIGIFT_PENDING_REDEMPTIONS[index];
        if (index != length - 1) {
            DIGIFT_PENDING_REDEMPTIONS[index] = DIGIFT_PENDING_REDEMPTIONS[length - 1];
        }
        DIGIFT_PENDING_REDEMPTIONS.pop();
    }

    function _recordDigiftForwardedRedemption(DigiftPendingRedemptionRecord memory record) internal {
        if (record.node == address(0) || record.component == address(0) || record.shares == 0) {
            return;
        }
        DIGIFT_FORWARDED_REDEMPTIONS.push(record);
    }

    function _forwardedDigiftRedemptionCount() internal view returns (uint256) {
        return DIGIFT_FORWARDED_REDEMPTIONS.length;
    }

    function _getDigiftForwardedRedemption(uint256 index)
        internal
        view
        returns (DigiftPendingRedemptionRecord memory)
    {
        if (index >= DIGIFT_FORWARDED_REDEMPTIONS.length) {
            return DigiftPendingRedemptionRecord({node: address(0), component: address(0), shares: 0});
        }
        return DIGIFT_FORWARDED_REDEMPTIONS[index];
    }

    function _consumeDigiftForwardedRedemption(uint256 index)
        internal
        returns (DigiftPendingRedemptionRecord memory record)
    {
        uint256 length = DIGIFT_FORWARDED_REDEMPTIONS.length;
        if (length == 0 || index >= length) {
            return DigiftPendingRedemptionRecord({node: address(0), component: address(0), shares: 0});
        }

        record = DIGIFT_FORWARDED_REDEMPTIONS[index];
        if (index != length - 1) {
            DIGIFT_FORWARDED_REDEMPTIONS[index] = DIGIFT_FORWARDED_REDEMPTIONS[length - 1];
        }
        DIGIFT_FORWARDED_REDEMPTIONS.pop();
    }

    function _managedNodeCount() internal view returns (uint256) {
        return MANAGED_NODES.length;
    }

    function _setRandomActiveNode(uint256 seed) internal {
        uint256 totalNodes = MANAGED_NODES.length;
        if (totalNodes == 0) {
            return;
        }

        uint256 index = seed % totalNodes;
        _setActiveNodeByIndex(index);
    }

    function _singleton(address value) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = value;
    }

    function _toArray(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }

    function _toArrayTwo(address addr1, address addr2) internal pure returns (address[] memory arr) {
        arr = new address[](2);
        arr[0] = addr1;
        arr[1] = addr2;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _donateeIndexForNode(address target) internal view returns (uint256) {
        for (uint256 i = 0; i < DONATEES.length; i++) {
            if (DONATEES[i] == target) {
                return i;
            }
        }
        revert("fuzz_guided_node_withdraw: donatee missing");
    }
}
