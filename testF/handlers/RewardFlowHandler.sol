pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IRewardFlow} from "../../interfaces/IRewardFlow.sol";
import {IArtifact} from "../../interfaces/IArtifact.sol";
import {RewardFlow} from "../../contracts/RewardFlow.sol";
import {Geras} from "../../contracts/Geras.sol";


contract RewardFlowHandler is Test {
    address[] public rfs;
    address public gerasAddr;
    address public owner;

    constructor(address[3] memory known, address geras, address rootOwner) {
        rfs = known;
        gerasAddr = geras;
        owner = rootOwner;
    }

    function payForward(uint flowIdx, uint duration) external {
        duration = uint32(bound(duration, 1000, 1000000));
        vm.warp(block.timestamp + duration);
        IRewardFlow(rfs[flowIdx % rfs.length]).payForward();
    }

    function submitAllocation(uint allocatorIdx, uint granteeIdx, uint amt) external {
        if ((allocatorIdx % rfs.length) == (granteeIdx % rfs.length)) {
            granteeIdx += 1;
        }
        vm.startPrank(owner);
        IRewardFlow(rfs[allocatorIdx % rfs.length]).submitAllocation(
            rfs[granteeIdx % rfs.length], uint8(amt % 256));
        vm.stopPrank();
    }

    function redeemReward(uint redeemerIdx, uint amt, uint duration) external {
        duration = uint32(bound(duration, 1000, 1000000));
        vm.warp(block.timestamp + duration);
        vm.startPrank(owner);
        IRewardFlow(rfs[redeemerIdx % rfs.length]).redeemReward(msg.sender, amt);
        vm.stopPrank();
    }

}