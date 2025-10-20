// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IPolicy {
    function onCheck(bytes calldata data) external view;
}
