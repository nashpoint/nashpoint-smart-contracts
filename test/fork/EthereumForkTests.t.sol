// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "test/BaseTest.sol";
import {Node} from "src/Node.sol";
import {INode, ComponentAllocation} from "src/interfaces/INode.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

// centrifuge interfaces
// import {IInvestmentManager} from "test/interfaces/centrifuge/IInvestmentManager.sol";
// import {IPoolManager} from "test/interfaces/centrifuge/IPoolManager.sol";
// import {IRestrictionManager} from "test/interfaces/centrifuge/IRestrictionManager.sol";
// import {ITranche} from "test/interfaces/centrifuge/ITranche.sol";
// import {IGateway} from "test/interfaces/centrifuge/IGateway.sol";

import {console2} from "forge-std/console2.sol";

// CONTRACT & STATE:
// https://etherscan.io/address/0x1d01ef1997d44206d839b78ba6813f60f1b3a970
// taken from block 20591573
// evm version: cancun

contract EthereumForkTests is BaseTest {
    uint256 ethereumFork;
    uint256 blockNumber = 20591573;
    address ERC7540VaultAddress = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;

    // centrifuge: fork test contracts and addresses
    // IInvestmentManager public investmentManager;
    // IRestrictionManager public restrictionManager;
    // IPoolManager public poolManager;
    // IGateway public gateway;
    // ITranche public share;
    // address public root;

    function setUp() public override {
        string memory ETHEREUM_RPC_URL = vm.envString("ETHEREUM_RPC_URL");
        ethereumFork = vm.createFork(ETHEREUM_RPC_URL, blockNumber);
        vm.selectFork(ethereumFork);
        super.setUp();
    }

    function test_canSelectEthereum() public {
        vm.selectFork(ethereumFork);
        assertEq(vm.activeFork(), ethereumFork);
    }

    function test_usdcAddress_ethereum() public view {
        string memory name = IERC20Metadata(usdcEthereum).name();
        uint256 totalSupply = IERC20Metadata(usdcEthereum).totalSupply();
        assertEq(name, "USD Coin");
        assertEq(totalSupply, 25385817571885697);
        assertEq(IERC20Metadata(usdcEthereum).decimals(), 6);
    }
}
