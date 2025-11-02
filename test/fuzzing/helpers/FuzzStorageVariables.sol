// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/FuzzActors.sol";

import {INode, ComponentAllocation, NodeInitArgs} from "../../../src/interfaces/INode.sol";
import {INodeRegistry, RegistryType} from "../../../src/interfaces/INodeRegistry.sol";
import {Node} from "../../../src/Node.sol";
import {NodeFactory} from "../../../src/NodeFactory.sol";
import {NodeRegistry} from "../../../src/NodeRegistry.sol";
import {QuoterV1} from "../../../src/quoters/QuoterV1.sol";
import {ERC4626Router} from "../../../src/routers/ERC4626Router.sol";
import {ERC7540Router} from "../../../src/routers/ERC7540Router.sol";
import {FluidRewardsRouter} from "../../../src/routers/FluidRewardsRouter.sol";
import {IncentraRouter} from "../../../src/routers/IncentraRouter.sol";
import {MerklRouter} from "../../../src/routers/MerklRouter.sol";
import {OneInchV6RouterV1} from "../../../src/routers/OneInchV6RouterV1.sol";
import {Escrow} from "../../../src/Escrow.sol";

import {DigiftAdapter} from "../../../src/adapters/digift/DigiftAdapter.sol";
import {DigiftAdapterFactory} from "../../../src/adapters/digift/DigiftAdapterFactory.sol";
import {DigiftEventVerifier} from "../../../src/adapters/digift/DigiftEventVerifier.sol";
import {DigiftEventVerifierMock} from "../../mocks/DigiftEventVerifierMock.sol";
import {SubRedManagementMock} from "../../mocks/SubRedManagementMock.sol";
import {PriceOracleMock} from "../../mocks/PriceOracleMock.sol";

import {CapPolicy} from "../../../src/policies/CapPolicy.sol";
import {GatePolicy} from "../../../src/policies/GatePolicy.sol";
import {NodePausingPolicy} from "../../../src/policies/NodePausingPolicy.sol";
import {ProtocolPausingPolicy} from "../../../src/policies/ProtocolPausingPolicy.sol";
import {TransferPolicy} from "../../../src/policies/TransferPolicy.sol";

import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {ERC7540Mock} from "../../mocks/ERC7540Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FluidDistributorMock} from "../../mocks/FluidDistributorMock.sol";
import {IncentraDistributorMock} from "../../mocks/IncentraDistributorMock.sol";
import {MerklDistributorMock} from "../../mocks/MerklDistributorMock.sol";

/**
 * @title FuzzStorageVariables
 * @notice Global storage shared across the UniversalFuzzing suite
 * @dev Holds protocol deployment artifacts, actor tracking, and fuzz configuration
 */
contract FuzzStorageVariables is FuzzActors {
    // ==============================================================
    // FUZZING SUITE SETUP
    // ==============================================================

    address internal currentActor;
    bool internal _setActor = true;

    uint256 internal constant PRIME = 2_147_483_647;
    uint256 internal constant SEED = 22;
    uint256 internal iteration = 1;
    uint256 internal lastTimestamp;
    bool internal protocolSet;

    address[] internal TOKENS;
    address[] internal DONATEES;

    uint256 internal constant INITIAL_USER_BALANCE = 1_000_000 ether;
    bytes32 internal constant DEFAULT_SALT = bytes32(uint256(1));

    uint64 internal constant DEFAULT_PROTOCOL_MAX_SWING_FACTOR = 0.99 ether;
    uint64 internal constant DEFAULT_COMPONENT_TARGET_WEIGHT = 0.3 ether;
    uint64 internal constant DEFAULT_COMPONENT_MAX_DELTA = 0.01 ether;
    uint256 internal constant DEFAULT_NODE_CAP_AMOUNT = 5_000_000 ether;

    address[] internal ROUTERS;
    address[] internal REBALANCERS;
    address[] internal REMOVABLE_COMPONENTS;
    bytes4[] internal REGISTERED_POLICY_SELECTORS;
    address[] internal REGISTERED_POLICY_ADDRESSES;
    //==============================================================
    // REVERTS CONFIGURATION
    //==============================================================

    bool internal constant CATCH_REQUIRE_REVERT = true;
    bool internal constant CATCH_EMPTY_REVERTS = true;

    // ==============================================================
    // CORE PROTOCOL CONTRACTS
    // ==============================================================

    NodeRegistry internal registry;
    NodeFactory internal factory;
    QuoterV1 internal quoter;
    ERC4626Router internal router4626;
    ERC7540Router internal router7540;
    FluidRewardsRouter internal routerFluid;
    IncentraRouter internal routerIncentra;
    MerklRouter internal routerMerkl;
    OneInchV6RouterV1 internal routerOneInch;

    INode internal node;
    Escrow internal escrow;

    DigiftAdapterFactory internal digiftFactory;
    DigiftAdapter internal digiftAdapter;
    SubRedManagementMock internal subRedManagement;
    DigiftEventVerifierMock internal digiftEventVerifier;

    ERC20Mock internal assetToken;
    IERC20 internal asset;
    ERC4626Mock internal vault;
    ERC4626Mock internal vaultSecondary;
    ERC4626Mock internal vaultTertiary;
    ERC7540Mock internal liquidityPool;
    ERC7540Mock internal liquidityPoolSecondary;
    FluidDistributorMock internal fluidDistributor;
    IncentraDistributorMock internal incentraDistributor;
    MerklDistributorMock internal merklDistributor;
    ERC20Mock internal stToken;
    PriceOracleMock internal assetPriceOracleMock;
    PriceOracleMock internal digiftPriceOracleMock;

    CapPolicy internal capPolicy;
    GatePolicy internal gatePolicy;
    NodePausingPolicy internal nodePausingPolicy;
    ProtocolPausingPolicy internal protocolPausingPolicy;
    TransferPolicy internal transferPolicy;

    // ==============================================================
    // AUXILIARY STATE
    // ==============================================================

    ComponentAllocation internal defaultComponentAllocation;
    address[] internal COMPONENTS;
    address[] internal COMPONENTS_ERC4626;
    address[] internal COMPONENTS_ERC7540;
    address[] internal POLICIES;
}
