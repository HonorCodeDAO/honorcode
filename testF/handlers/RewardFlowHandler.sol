pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IRewardFlow} from "../../interfaces/IRewardFlow.sol";
import {IArtifact} from "../../interfaces/IArtifact.sol";
import {IGeras} from "../../interfaces/IGeras.sol";
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

    // function transfer(uint amount) external {
    //     amount = bound(amount, 1000, 1 ether);
    //     vm.startPrank(owner);
    //     IGeras(gerasAddr).transfer(gerasAddr, amount);
    //     vm.stopPrank();
    // }

    function payForward(uint flowIdx, uint duration) external {
        duration = uint32(bound(duration, 1000, 1000000));
        vm.startPrank(owner);        
        if (IRewardFlow(rfs[flowIdx % rfs.length]).availableReward() == 0) {
            IRewardFlow(rfs[0]).submitAllocation(
                rfs[flowIdx % rfs.length], uint8(128), owner);
        }
        vm.warp(block.timestamp + duration);
        IRewardFlow(rfs[flowIdx % rfs.length]).payForward();
        vm.stopPrank();
    }

    function submitAllocation(uint allocatorIdx, uint granteeIdx, uint amt) external {
        if ((allocatorIdx % rfs.length) == (granteeIdx % rfs.length)) {
            granteeIdx += 1;
        }
        vm.startPrank(owner);
        IRewardFlow(rfs[allocatorIdx % rfs.length]).submitAllocation(
            rfs[granteeIdx % rfs.length], uint8(amt % 256), owner);
        vm.stopPrank();
    }

    function redeemReward(uint redeemerIdx, uint amt, uint duration) external {
        duration = uint32(bound(duration, 1000, 1000000));
        vm.startPrank(owner);
        amt = (bound(amt, 1000, IArtifact(IRewardFlow(
            rfs[redeemerIdx % rfs.length]).artifactAddr()).accRewardClaim(owner)));
        vm.warp(block.timestamp + duration);
        IRewardFlow(rfs[redeemerIdx % rfs.length]).redeemReward(owner, amt);
        vm.stopPrank();
    }

    function distributeGeras(uint duration) external {
        duration = uint32(bound(duration, 1000, 1000000));
        vm.warp(block.timestamp + duration);
        vm.startPrank(owner);
        IGeras(gerasAddr).distributeGeras(rfs[0]);
        vm.stopPrank();
    }

    function distributeReward(uint amt, uint rate, uint duration) external {
        amt = bound(amt, 1000, 0.01 ether);
        duration = uint32(bound(duration, 1000, 1000000));
        rate = uint32(bound(rate, 1, 1024));
        vm.warp(block.timestamp + duration);
        IGeras(gerasAddr).distributeReward(amt, rate);
    }

}