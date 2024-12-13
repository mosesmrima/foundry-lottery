//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {DeployRaffle} from "../../script/DeployRaffle.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
contract RafleTest is Test {
    event RaffleEntered(address indexed player);
    Raffle public raffle;
    HelperConfig public helperConfig;

    address immutable PLAYER1 = makeAddr("player1");
    uint256 constant STARTING_PLAYERBALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER1, STARTING_PLAYERBALANCE);
    }

    function testInitialRaffleStateIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffleRvertsWithInsufficientFunds() public {
        vm.prank(PLAYER1);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenEntered() public {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();

        address recordedPlayer = raffle.getPlayerAdress(0);
        assertEq(recordedPlayer, PLAYER1);
    }

    function testEnteringEmitsEvent() public {
        vm.prank(PLAYER1);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testEnteringRaffleWhileCalculatingReverts() public {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(1);
        raffle.performUpkeep();
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testUpkeepReturnsFalseIfNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testUpkeepReturnsFalseIfRaffleIsnOpen() public {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(1);
        raffle.performUpkeep();
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepOnlyRunsWhenCheckUpKeepReturnsTrue() public {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(1);
        raffle.performUpkeep();
    }

    function testPerforUpkeepRevertsOnCheckUpKepFalse() public {
        uint256 balance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
        balance = entranceFee;
        numPlayers = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNeeded.selector,
                balance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep();
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsEventWithRequestId()
        public
    {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    function testFullFillRandomWordsCanOnlyBeCalledAfterPerformUpkeepIsCalled(
        uint256 _requestId
    ) public {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            _requestId,
            address(raffle)
        );
    }

    function testWinnerPickedArrayResetsMoneySent() public {
        uint256 startingIndex = 1;
        uint256 additionalEntrants = 4;
        address expectedWinner = address(1);
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_PLAYERBALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimestamp = raffle.getLastTimestamp();
        uint256 startingWinnerBalance = expectedWinner.balance;
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 endingTimestamp = raffle.getLastTimestamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);
        uint256 winnerBalance = expectedWinner.balance;

        assert(expectedWinner == recentWinner);
        assert(endingTimestamp > startingTimestamp);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingWinnerBalance + prize);
    }
}
