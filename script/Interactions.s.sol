//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    uint256 public subId;
    function createSubscription(address _vrfCoordinator) public returns (uint256) {
        
        
        vm.startBroadcast();
        subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        
        return subId;
    }

    function run() public returns (uint256) {
        
    }
}

contract FundSubscrption is Script {
    uint256 public constant FUND_AMOUNT = 3 ether;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    function fundSuscrptionUsingConfig() public {
        
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint256 subscriptionId = config.getConfig().subscriptionId;
        address linkToken = config.getConfig().link;
        
        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            uint256 updatedSubId = createSub.run();
            
            subscriptionId = updatedSubId;
        }
        
        fundSubscrption(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscrption(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken
    ) public {
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT * 1000
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
       
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address recentDeploy) public {
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint256 subscriptionId = config.getConfig().subscriptionId;
        addConsumer(recentDeploy, vrfCoordinator, subscriptionId);
    }

    function addConsumer(
        address contractToAdd,
        address vrfCoordinator,
        uint256 subId
    ) public {
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAdd
        );
        vm.stopBroadcast();
    }

    function run() public {
        address recentDeploy = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(recentDeploy);
    }
}
