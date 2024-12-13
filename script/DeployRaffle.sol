//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.sol";
import {CreateSubscription, AddConsumer, FundSubscrption} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
           
            config.subscriptionId = createSub.createSubscription(config.vrfCoordinator);
            console.log("sub Id, ", config.subscriptionId);
            
          
            FundSubscrption fundSubscription = new FundSubscrption();
            
            
            fundSubscription.fundSubscrption(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link
            );
        }
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addCosumer = new AddConsumer();
        addCosumer.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subscriptionId
        );

        return (raffle, helperConfig);
    }

    function run() external {
        
    }
}
