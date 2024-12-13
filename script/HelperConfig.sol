//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
contract HelperConfig is Script {
    error HelperConfig__InvalidNetworkId();

    uint256 private constant SEPOLIA_NETWORK_ID = 1115511;
    uint256 private constant LOCAL_CHAIN_ID = 31337;
    uint96 private constant BASE_FEE_MOCK = 0.25 ether;
    uint96 private constant GAS_PRICE_MOCK = 1e9;
    int256 private constant WEI_PER_UNIT_LINK_MOCK = 4e15;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_NETWORK_ID] = getSepoliaConfig();
    }

    function getConfigByCHainId(uint256 _chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[_chainId].vrfCoordinator != address(0)) {
            return networkConfigs[SEPOLIA_NETWORK_ID];
        } else if (LOCAL_CHAIN_ID == _chainId) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidNetworkId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByCHainId(block.chainid);
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: address(0) //cange to actual contact address
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        } else {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock vrfCoordinatorMock =
                new VRFCoordinatorV2_5Mock(BASE_FEE_MOCK, GAS_PRICE_MOCK, WEI_PER_UNIT_LINK_MOCK);
                LinkToken linkToken  = new LinkToken();
            vm.stopBroadcast();


            return NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinatorMock),
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                subscriptionId: 0,
                link: address(linkToken)
            });
        }
    }
}
