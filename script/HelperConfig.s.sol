//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract HelperConfig is Script {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    error ChainNotSupported();

    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 gasLane;
        uint256 interval;
        uint256 entranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2;
    }

    uint256 public constant SEPOLIA_CHAIN_ID = 1115111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;

    NetworkConfig public config;
    mapping(uint256 chainId => NetworkConfig) chainIdToNetwork;

    constructor() {
        chainIdToNetwork[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getOrCreateConfig(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainIdToNetwork[chainId].vrfCoordinatorV2 != address(0)) {
            return chainIdToNetwork[chainId];
        } else if (chainId == ANVIL_CHAIN_ID) {
            return getAnvilEthConfig();
        } else {
            revert ChainNotSupported();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getOrCreateConfig(block.chainid);
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        if (config.vrfCoordinatorV2 != address(0)) {
            return config;
        } else {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock mock = new VRFCoordinatorV2_5Mock(
                MOCK_BASE_FEE,
                MOCK_GAS_PRICE_LINK,
                MOCK_WEI_PER_UINT_LINK
            );
            config = NetworkConfig({
                subscriptionId: 0,
                gasLane: 0x873f3bcf0c6f44c9a7ff4eaaaf1f2ccf5ed8cc688c566f9a9c8ca41ecae3e722,
                interval: 30,
                entranceFee: 0.01 ether,
                callbackGasLimit: 5000000,
                vrfCoordinatorV2: address(mock)
            });
            return config;
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                subscriptionId: 0,
                gasLane: 0x873f3bcf0c6f44c9a7ff4eaaaf1f2ccf5ed8cc688c566f9a9c8ca41ecae3e722,
                interval: 30,
                entranceFee: 0.01 ether,
                callbackGasLimit: 5000000,
                vrfCoordinatorV2: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
            });
    }
}
