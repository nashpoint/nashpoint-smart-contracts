// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RegistryType} from "src/interfaces/INodeRegistry.sol";

contract NodeRegistryMock is Ownable {
    mapping(address => mapping(RegistryType => bool)) public roles;

    constructor() Ownable(msg.sender) {}

    function setRegistryType(address addr, RegistryType type_, bool status) external onlyOwner {
        roles[addr][type_] = status;
    }

    function isNode(address node_) external view returns (bool) {
        return roles[node_][RegistryType.NODE];
    }

    function isRegistryType(address addr, RegistryType type_) external view returns (bool) {
        return roles[addr][type_];
    }
}
