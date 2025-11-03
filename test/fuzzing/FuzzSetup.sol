// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./helpers/FuzzStorageVariables.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC4626StaticVault} from "../mocks/vaults/ERC4626StaticVault.sol";
import {ERC4626LinearYieldVault} from "../mocks/vaults/ERC4626LinearYieldVault.sol";
import {ERC4626NegativeYieldVault} from "../mocks/vaults/ERC4626NegativeYieldVault.sol";
import {ERC7540StaticVault} from "../mocks/vaults/ERC7540StaticVault.sol";
import {ERC7540LinearYieldVault} from "../mocks/vaults/ERC7540LinearYieldVault.sol";
import {ERC7540NegativeYieldVault} from "../mocks/vaults/ERC7540NegativeYieldVault.sol";
import {ERC7540Mock} from "../mocks/ERC7540Mock.sol";
import {AggregationRouterV6Mock} from "../mocks/AggregationRouterV6Mock.sol";
import {SimpleProxy} from "./mocks/SimpleProxy.sol";

/**
 * @title FuzzSetup
 * @notice Responsible for deploying and configuring the Node protocol test environment
 * @dev Mirrors the deployment pattern used in the Foundry test suite to keep behaviour aligned
 */
contract FuzzSetup is FuzzStorageVariables {
    // ==============================================================
    // PRIMARY ENTRYPOINTS
    // ==============================================================

    /**
     * @notice Deterministic fuzzing environment setup invoked from `Fuzz` constructor
     */
    function fuzzSetup() internal {
        fuzzSetup(false);
    }

    function fuzzSetup(bool isEchidna) internal {
        if (protocolSet) {
            return;
        }

        _initUsers();

        // Avoid underflow in Node.initialize (matches BaseTest behaviour)
        vm.warp(block.timestamp + 1 days);

        _deployCoreInfrastructure(isEchidna);
        _configureRegistry();
        _deployNode();
        _seedUserBalancesAndApprovals();
        _setupFuzzingArrays();
        _labelAddresses();

        // Ensure rebalance window has elapsed so deposits/mints are enabled
        vm.warp(block.timestamp + 1 days);
        vm.prank(rebalancer);
        node.startRebalance();

        protocolSet = true;
    }

    /**
     * @notice Randomized setup hook invoked by PreconditionsBase when protocol state is unset
     */
    function randomSetup(bool seed1, uint256 seed2, uint8 seed3) public {
        if (!protocolSet) {
            fuzzSetup();
        }

        _applyRandomizedConfiguration(seed1, seed2, seed3);
        protocolSet = true;
    }

    // ==============================================================
    // DEPLOYMENT HELPERS
    // ==============================================================

    function _deployCoreInfrastructure(bool isEchidna) internal {
        // Deploy registry behind UUPS proxy to match production architecture
        NodeRegistry registryImpl = new NodeRegistry();
        registry = NodeRegistry(
            address(
                new ERC1967Proxy(
                    address(registryImpl),
                    abi.encodeWithSelector(
                        NodeRegistry.initialize.selector,
                        owner,
                        protocolFeesAddress,
                        0,
                        0,
                        DEFAULT_PROTOCOL_MAX_SWING_FACTOR
                    )
                )
            )
        );

        Node nodeImplementation = new Node(address(registry));
        factory = new NodeFactory(address(registry), address(nodeImplementation));
        quoter = new QuoterV1(address(registry));
        router4626 = new ERC4626Router(address(registry));
        router7540 = new ERC7540Router(address(registry));
        fluidDistributor = new FluidDistributorMock();
        routerFluid = new FluidRewardsRouter(address(registry), address(fluidDistributor));

        incentraDistributor = new IncentraDistributorMock();
        routerIncentra = new IncentraRouter(address(registry), address(incentraDistributor));

        address merklDistributorAddr = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
        SimpleProxy merklDistributorProxy = _prepareProxy(merklDistributorAddr, isEchidna);
        MerklDistributorMock merklDistributorImpl = new MerklDistributorMock();
        merklDistributorProxy.setImplementation(address(merklDistributorImpl));
        merklDistributor = MerklDistributorMock(merklDistributorAddr);
        routerMerkl = new MerklRouter(address(registry));
        routerOneInch = new OneInchV6RouterV1(address(registry));

        address aggregationAddress = routerOneInch.ONE_INCH_AGGREGATION_ROUTER_V6();
        SimpleProxy aggregationRouterProxy = _prepareProxy(aggregationAddress, isEchidna);
        AggregationRouterV6Mock aggregationRouterImpl = new AggregationRouterV6Mock();
        aggregationRouterProxy.setImplementation(address(aggregationRouterImpl));

        assetToken = new ERC20Mock("Test Token", "TEST");
        asset = IERC20(address(assetToken));
        vault = new ERC4626StaticVault(address(asset), "Static Immediate Vault", "siVAULT");
        vaultSecondary = new ERC4626LinearYieldVault(address(asset), "Linear Immediate Vault", "liVAULT", 5e13);
        vaultTertiary = new ERC4626NegativeYieldVault(address(asset), "Declining Immediate Vault", "diVAULT", 3e13);
        liquidityPool = new ERC7540StaticVault(IERC20(address(asset)), "Static Async Vault", "saVAULT", poolManager);
        liquidityPoolSecondary =
            new ERC7540LinearYieldVault(IERC20(address(asset)), "Linear Async Vault", "laVAULT", poolManager, 4e13);
        liquidityPoolTertiary =
            new ERC7540NegativeYieldVault(IERC20(address(asset)), "Declining Async Vault", "daVAULT", poolManager, 2e13);

        stToken = new ERC20Mock("Digift Security Token", "DST");
        subRedManagement = new SubRedManagementMock();
        assetPriceOracleMock = new PriceOracleMock(8);
        digiftPriceOracleMock = new PriceOracleMock(8);
        digiftEventVerifier = new DigiftEventVerifierMock(owner);

        capPolicy = new CapPolicy(address(registry));
        gatePolicy = new GatePolicy(address(registry));
        nodePausingPolicy = new NodePausingPolicy(address(registry));
        protocolPausingPolicy = new ProtocolPausingPolicy(address(registry));
        transferPolicy = new TransferPolicy(address(registry));

        defaultComponentAllocation = ComponentAllocation({
            targetWeight: DEFAULT_COMPONENT_TARGET_WEIGHT,
            maxDelta: DEFAULT_COMPONENT_MAX_DELTA,
            router: address(router4626),
            isComponent: true
        });
    }

    function _configureRegistry() internal {
        vm.startPrank(owner);
        registry.setRegistryType(address(factory), RegistryType.FACTORY, true);
        registry.setRegistryType(address(router4626), RegistryType.ROUTER, true);
        registry.setRegistryType(address(router7540), RegistryType.ROUTER, true);
        registry.setRegistryType(address(routerFluid), RegistryType.ROUTER, true);
        registry.setRegistryType(address(routerIncentra), RegistryType.ROUTER, true);
        registry.setRegistryType(address(routerMerkl), RegistryType.ROUTER, true);
        registry.setRegistryType(address(routerOneInch), RegistryType.ROUTER, true);
        registry.setRegistryType(rebalancer, RegistryType.REBALANCER, true);
        registry.setRegistryType(address(quoter), RegistryType.QUOTER, true);

        router4626.setWhitelistStatus(address(vault), true);
        router4626.setWhitelistStatus(address(vaultSecondary), true);
        router4626.setWhitelistStatus(address(vaultTertiary), true);
        router7540.setWhitelistStatus(address(liquidityPool), true);
        router7540.setWhitelistStatus(address(liquidityPoolSecondary), true);
        router7540.setWhitelistStatus(address(liquidityPoolTertiary), true);
        vm.stopPrank();
    }

    function _deployNode() internal {
        bytes[] memory payload = new bytes[](5);
        payload[0] = abi.encodeWithSelector(INode.addRouter.selector, address(router4626));
        payload[1] = abi.encodeWithSelector(INode.addRebalancer.selector, rebalancer);
        payload[2] = abi.encodeWithSelector(
            INode.addComponent.selector,
            address(vault),
            defaultComponentAllocation.targetWeight,
            defaultComponentAllocation.maxDelta,
            defaultComponentAllocation.router
        );
        payload[3] = abi.encodeWithSelector(INode.updateTargetReserveRatio.selector, 0.2 ether);
        payload[4] = abi.encodeWithSelector(INode.setQuoter.selector, address(quoter));

        address escrowAddress;
        (node, escrowAddress) =
            factory.deployFullNode(NodeInitArgs("Test Node", "TNODE", address(asset), owner), payload, DEFAULT_SALT);
        escrow = Escrow(escrowAddress);
        _registerManagedNode(address(node), escrowAddress);

        vm.startPrank(owner);
        node.setMaxDepositSize(1e36);
        node.addRouter(address(router7540));
        node.addRouter(address(routerFluid));
        node.addRouter(address(routerIncentra));
        node.addRouter(address(routerMerkl));
        node.addRouter(address(routerOneInch));
        node.setRebalanceCooldown(0);
        node.updateComponentAllocation(address(vault), 0.3 ether, 0.01 ether, address(router4626));
        node.addComponent(address(vaultSecondary), 0.2 ether, 0.01 ether, address(router4626));
        node.addComponent(address(vaultTertiary), 0.15 ether, 0.01 ether, address(router4626));
        node.addComponent(address(liquidityPool), 0.1 ether, 0.01 ether, address(router7540));
        node.addComponent(address(liquidityPoolSecondary), 0.05 ether, 0.01 ether, address(router7540));
        node.addComponent(address(liquidityPoolTertiary), 0.05 ether, 0.01 ether, address(router7540));
        node.updateTargetReserveRatio(0.15 ether);

        address[] memory liquidationQueue = new address[](6);
        liquidationQueue[0] = address(vault);
        liquidationQueue[1] = address(vaultSecondary);
        liquidationQueue[2] = address(vaultTertiary);
        liquidationQueue[3] = address(liquidityPool);
        liquidationQueue[4] = address(liquidityPoolSecondary);
        liquidationQueue[5] = address(liquidityPoolTertiary);
        node.setLiquidationQueue(liquidationQueue);

        capPolicy.setCap(address(node), DEFAULT_NODE_CAP_AMOUNT);

        address[] memory whitelistActors = new address[](USERS.length + 5);
        for (uint256 i = 0; i < USERS.length; i++) {
            whitelistActors[i] = USERS[i];
        }
        whitelistActors[USERS.length] = owner;
        whitelistActors[USERS.length + 1] = rebalancer;
        whitelistActors[USERS.length + 2] = address(router4626);
        whitelistActors[USERS.length + 3] = address(router7540);
        whitelistActors[USERS.length + 4] = vaultSeeder;

        gatePolicy.add(address(node), whitelistActors);
        nodePausingPolicy.add(address(node), whitelistActors);
        transferPolicy.add(address(node), whitelistActors);

        protocolPausingPolicy.add(_singleton(owner));
        vm.stopPrank();

        uint64 originalWindow = Node(address(node)).rebalanceWindow();
        uint64 tempWindow = 10_000_000_000;
        vm.startPrank(owner);
        node.setRebalanceWindow(tempWindow);
        vm.stopPrank();

        _seedNode(200_000 ether);

        vm.startPrank(owner);
        node.setRebalanceWindow(originalWindow);
        vm.stopPrank();
        _seedERC4626(address(vault), 400_000 ether);
        _seedERC4626(address(vaultSecondary), 200_000 ether);
        _seedERC4626(address(vaultTertiary), 100_000 ether);
        _seedERC7540(address(liquidityPool), 150_000 ether);
        _seedERC7540(address(liquidityPoolSecondary), 75_000 ether);
        _seedERC7540(address(liquidityPoolTertiary), 50_000 ether);

        assetPriceOracleMock.setLatestRoundData(1, 1e8, block.timestamp, block.timestamp, 1);
        digiftPriceOracleMock.setLatestRoundData(1, 2e10, block.timestamp, block.timestamp, 1);

        DigiftAdapter implementation =
            new DigiftAdapter(address(subRedManagement), address(registry), address(digiftEventVerifier));
        digiftFactory = new DigiftAdapterFactory(address(implementation), owner);

        DigiftAdapter.InitArgs memory initArgs = DigiftAdapter.InitArgs({
            name: "Digift Adapter",
            symbol: "dGIF",
            asset: address(assetToken),
            assetPriceOracle: address(assetPriceOracleMock),
            stToken: address(stToken),
            dFeedPriceOracle: address(digiftPriceOracleMock),
            priceDeviation: 1e15,
            settlementDeviation: 1e16,
            priceUpdateDeviation: 4 days,
            minDepositAmount: 1_000e6,
            minRedeemAmount: 10e18
        });

        vm.startPrank(owner);
        digiftAdapter = DigiftAdapter(digiftFactory.deploy(initArgs));
        router7540.setWhitelistStatus(address(digiftAdapter), true);
        digiftEventVerifier.setWhitelist(address(digiftAdapter), true);
        digiftAdapter.setManager(rebalancer, true);
        digiftAdapter.setNode(address(node), true);
        vm.stopPrank();

        subRedManagement.setManager(rebalancer, true);
        subRedManagement.setWhitelist(address(digiftAdapter), true);

        vm.startPrank(owner);
        digiftEventVerifier.configureSettlement(DigiftEventVerifier.EventType.SUBSCRIBE, 1e18, 0);
        digiftEventVerifier.configureSettlement(DigiftEventVerifier.EventType.REDEEM, 0, 1e18);
        vm.stopPrank();
    }

    // ==============================================================
    // STATE INITIALISATION
    // ==============================================================

    function _seedUserBalancesAndApprovals() internal {
        address[] memory actors = new address[](USERS.length + 3);
        for (uint256 i = 0; i < USERS.length; i++) {
            actors[i] = USERS[i];
        }
        actors[USERS.length] = owner;
        actors[USERS.length + 1] = rebalancer;
        actors[USERS.length + 2] = vaultSeeder;

        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            assetToken.mint(actor, INITIAL_USER_BALANCE);

            vm.startPrank(actor);
            assetToken.approve(address(node), type(uint256).max);
            node.approve(address(node), type(uint256).max);
            vm.stopPrank();
        }

        assetToken.mint(randomUser, INITIAL_USER_BALANCE);

        // Provide liquidity to escrow to simulate seeded reserves when required
        assetToken.mint(address(escrow), INITIAL_USER_BALANCE / 10);

        assetToken.mint(address(node), INITIAL_USER_BALANCE);

        vm.startPrank(address(node));
        assetToken.approve(address(digiftAdapter), type(uint256).max);
        digiftAdapter.approve(address(digiftAdapter), type(uint256).max);
        vm.stopPrank();
    }

    function _setupFuzzingArrays() internal {
        if (TOKENS.length == 0) {
            TOKENS.push(address(assetToken));
            TOKENS.push(address(vault));
            TOKENS.push(address(vaultSecondary));
            TOKENS.push(address(vaultTertiary));
            TOKENS.push(address(liquidityPool));
            TOKENS.push(address(liquidityPoolSecondary));
            TOKENS.push(address(liquidityPoolTertiary));
            TOKENS.push(address(stToken));
        }

        if (COMPONENTS.length == 0) {
            COMPONENTS.push(address(vault));
            COMPONENTS.push(address(vaultSecondary));
            COMPONENTS.push(address(vaultTertiary));
            COMPONENTS.push(address(liquidityPool));
            COMPONENTS.push(address(liquidityPoolSecondary));
            COMPONENTS.push(address(liquidityPoolTertiary));
            COMPONENTS.push(address(digiftAdapter));
        }

        if (COMPONENTS_ERC4626.length == 0) {
            COMPONENTS_ERC4626.push(address(vault));
            COMPONENTS_ERC4626.push(address(vaultSecondary));
            COMPONENTS_ERC4626.push(address(vaultTertiary));
        }

        if (COMPONENTS_ERC7540.length == 0) {
            COMPONENTS_ERC7540.push(address(liquidityPool));
            COMPONENTS_ERC7540.push(address(liquidityPoolSecondary));
            COMPONENTS_ERC7540.push(address(liquidityPoolTertiary));
            COMPONENTS_ERC7540.push(address(digiftAdapter));
        }

        if (POLICIES.length == 0) {
            POLICIES.push(address(capPolicy));
            POLICIES.push(address(gatePolicy));
            POLICIES.push(address(nodePausingPolicy));
            POLICIES.push(address(protocolPausingPolicy));
            POLICIES.push(address(transferPolicy));
        }

        if (ROUTERS.length == 0) {
            ROUTERS.push(address(router4626));
            ROUTERS.push(address(router7540));
            ROUTERS.push(address(routerFluid));
            ROUTERS.push(address(routerIncentra));
            ROUTERS.push(address(routerMerkl));
            ROUTERS.push(address(routerOneInch));
        }

        if (REBALANCERS.length == 0) {
            REBALANCERS.push(rebalancer);
        }

        if (DONATEES.length == 0) {
            DONATEES.push(address(node));
            DONATEES.push(address(escrow));

            for (uint256 i = 0; i < ROUTERS.length; i++) {
                DONATEES.push(ROUTERS[i]);
            }
            for (uint256 i = 0; i < COMPONENTS.length; i++) {
                DONATEES.push(COMPONENTS[i]);
            }
            for (uint256 i = 0; i < POLICIES.length; i++) {
                DONATEES.push(POLICIES[i]);
            }
        }
    }

    function _labelAddresses() internal {
        vm.label(address(registry), "NodeRegistry");
        vm.label(address(factory), "NodeFactory");
        vm.label(address(quoter), "QuoterV1");
        vm.label(address(router4626), "ERC4626Router");
        vm.label(address(router7540), "ERC7540Router");
        vm.label(address(routerFluid), "FluidRewardsRouter");
        vm.label(address(routerIncentra), "IncentraRouter");
        vm.label(address(routerMerkl), "MerklRouter");
        vm.label(address(routerOneInch), "OneInchV6RouterV1");
        vm.label(routerOneInch.ONE_INCH_AGGREGATION_ROUTER_V6(), "OneInchAggregationRouterV6");
        vm.label(address(node), "Node");
        vm.label(address(escrow), "Escrow");
        vm.label(address(asset), "Asset");
        vm.label(address(vault), "Vault");
        vm.label(address(vaultSecondary), "VaultSecondary");
        vm.label(address(vaultTertiary), "VaultTertiary");
        vm.label(address(liquidityPool), "LiquidityPool");
        vm.label(address(liquidityPoolSecondary), "LiquidityPoolSecondary");
        vm.label(address(liquidityPoolTertiary), "LiquidityPoolTertiary");
        vm.label(address(capPolicy), "CapPolicy");
        vm.label(address(gatePolicy), "GatePolicy");
        vm.label(address(nodePausingPolicy), "NodePausingPolicy");
        vm.label(address(protocolPausingPolicy), "ProtocolPausingPolicy");
        vm.label(address(transferPolicy), "TransferPolicy");

        vm.label(owner, "Owner");
        vm.label(rebalancer, "Rebalancer");
        vm.label(protocolFeesAddress, "ProtocolFees");
        vm.label(vaultSeeder, "VaultSeeder");
        vm.label(randomUser, "RandomUser");
        vm.label(address(fluidDistributor), "FluidDistributor");
        vm.label(address(incentraDistributor), "IncentraDistributor");
        vm.label(address(merklDistributor), "MerklDistributor");
        vm.label(address(digiftAdapter), "DigiftAdapter");
        vm.label(address(digiftFactory), "DigiftAdapterFactory");
        vm.label(address(digiftEventVerifier), "DigiftEventVerifier");
        vm.label(address(subRedManagement), "SubRedManagement");
        vm.label(address(assetPriceOracleMock), "AssetPriceOracle");
        vm.label(address(digiftPriceOracleMock), "DigiftPriceOracle");
        vm.label(address(stToken), "SecurityToken");
        vm.label(poolManager, "PoolManager");

        vm.label(USER1, "USER1");
        vm.label(USER2, "USER2");
        vm.label(USER3, "USER3");
        vm.label(USER4, "USER4");
        vm.label(USER5, "USER5");
        vm.label(USER6, "USER6");
    }

    // ==============================================================
    // RANDOMISATION HOOK
    // ==============================================================

    function _applyRandomizedConfiguration(bool seed1, uint256 seed2, uint8 seed3) internal {
        vm.startPrank(owner);

        uint256 maxDepositFloor = 10_000 ether;
        uint256 maxDepositRange = 1_000_000 ether;
        uint256 randomizedMaxDeposit = maxDepositFloor + (seed2 % maxDepositRange);
        node.setMaxDepositSize(randomizedMaxDeposit);

        uint64 managementFeeBps = uint64((seed2 % 1_000) * 1e15); // up to 10%
        node.setAnnualManagementFee(managementFeeBps);

        if (seed1) {
            uint64 swingFactor = uint64(bound(uint256(seed3), 1, 50)) * 1e16; // 0.01% - 0.5%
            node.enableSwingPricing(true, swingFactor);
        } else {
            node.enableSwingPricing(false, 0);
        }

        vm.stopPrank();
    }

    function _defaultComponentAllocations(uint256 count)
        internal
        view
        returns (ComponentAllocation[] memory allocations)
    {
        allocations = new ComponentAllocation[](count);
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = ComponentAllocation({
                targetWeight: DEFAULT_COMPONENT_TARGET_WEIGHT,
                maxDelta: DEFAULT_COMPONENT_MAX_DELTA,
                router: address(router4626),
                isComponent: true
            });
        }
    }

    function _defaultReserveAllocation() internal view returns (ComponentAllocation memory) {
        return ComponentAllocation({
            targetWeight: 0.1 ether,
            maxDelta: DEFAULT_COMPONENT_MAX_DELTA,
            router: address(router4626),
            isComponent: true
        });
    }

    function _getCurrentReserveRatio() public view returns (uint256 reserveRatio) {
        if (node.totalAssets() == 0) {
            return 0;
        }
        reserveRatio = Math.mulDiv(asset.balanceOf(address(node)), 1e18, node.totalAssets());
    }

    function _seedNode(uint256 amount) internal {
        if (amount == 0) return;
        assetToken.mint(vaultSeeder, amount);
        vm.startPrank(vaultSeeder);
        asset.approve(address(node), amount);
        node.deposit(amount, vaultSeeder);
        vm.stopPrank();
    }

    function _seedERC4626(address component, uint256 amount) internal {
        if (amount == 0) return;
        assetToken.mint(vaultSeeder, amount);
        vm.startPrank(vaultSeeder);
        asset.approve(component, amount);
        ERC4626(component).deposit(amount, vaultSeeder);
        vm.stopPrank();
    }

    function _seedERC7540(address component, uint256 amount) internal {
        if (amount == 0) return;
        assetToken.mint(vaultSeeder, amount);
        vm.startPrank(vaultSeeder);
        asset.approve(component, amount);
        ERC7540Mock(component).requestDeposit(amount, vaultSeeder, vaultSeeder);
        vm.stopPrank();
    }

    function _userDeposits(address user_, uint256 amount_) internal returns (uint256 shares) {
        vm.startPrank(user_);
        asset.approve(address(node), amount_);
        shares = node.deposit(amount_, user_);
        vm.stopPrank();
    }

    function _setAllocationToAsyncVault(address liquidityPool_, uint64 allocation) internal {
        vm.startPrank(owner);
        uint64 reserveAllocation = uint64(1 ether) - allocation;
        node.updateTargetReserveRatio(reserveAllocation);
        node.updateComponentAllocation(address(vault), 0, 0, address(router4626));
        node.removeComponent(address(vault), false);
        node.addComponent(address(liquidityPool_), allocation, 0, address(router7540));
        router7540.setWhitelistStatus(address(liquidityPool_), true);
        vm.stopPrank();
    }

    function _prepareProxy(address target, bool isEchidna) internal returns (SimpleProxy proxy) {
        if (!isEchidna) {
            vm.etch(target, type(SimpleProxy).runtimeCode);
        }

        proxy = SimpleProxy(payable(target));
    }

    // ==============================================================
    // TEST HELPERS
    // ==============================================================

    function setActiveNodeForTest(uint256 index) public {
        if (!protocolSet) {
            fuzzSetup();
        }
        _setActiveNodeByIndex(index);
    }

    function managedNodeCountForTest() public view returns (uint256) {
        return _managedNodeCount();
    }

    function forceNodeContextForTest(uint256 index) public {
        if (!protocolSet) {
            fuzzSetup();
        }
        testNodeOverrideEnabled = true;
        testNodeOverrideIndex = index;
        _setActiveNodeByIndex(index);
        if (address(node) != address(0)) {
            vm.startPrank(rebalancer);
            try node.startRebalance() {}
            catch {
                // ignore reverts in tests; deposit preconditions will handle
            }
            vm.stopPrank();
        }
    }

    function clearNodeContextOverrideForTest() public {
        testNodeOverrideEnabled = false;
    }

    function componentsByRouterForTest(address targetRouter) public view returns (address[] memory matches) {
        if (address(node) == address(0)) {
            return new address[](0);
        }

        address[] memory nodeComponents = node.getComponents();
        uint256 count;
        for (uint256 i = 0; i < nodeComponents.length; i++) {
            ComponentAllocation memory allocation = node.getComponentAllocation(nodeComponents[i]);
            if (allocation.isComponent && allocation.router == targetRouter) {
                count++;
            }
        }

        matches = new address[](count);
        uint256 cursor;
        for (uint256 i = 0; i < nodeComponents.length; i++) {
            ComponentAllocation memory allocation = node.getComponentAllocation(nodeComponents[i]);
            if (allocation.isComponent && allocation.router == targetRouter) {
                matches[cursor] = nodeComponents[i];
                cursor++;
            }
        }
    }
}
