pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IArtifact} from "../../interfaces/IArtifact.sol";
import {Honor} from "../../contracts/Honor.sol";


contract HonorHandler is Test {

    mapping (uint => address) public knownArtifacts; 
    Honor private hnr;
    uint public artifactCount;
    address[] public actors;

    constructor(Honor _hnr, address[3] memory known) {
        hnr = _hnr;
        for (uint i; i < known.length; i++) {
            knownArtifacts[i] = known[i]; 
        }
        artifactCount = known.length;
    }

    function proposeArtifact(uint senderIdx) external {
        string memory artifactName = new string(artifactCount);
        vm.startPrank(hnr.owner());
        knownArtifacts[artifactCount] = hnr.proposeArtifact(
            hnr.rootArtifact(), 
            hnr.owner(), 
            artifactName, true);
        vm.stopPrank();
        artifactCount += 1;
    }

    function vouch(uint amt, uint senderIdx, uint receiverIdx) external {
        amt = bound(amt, 0 ether, 25 ether);
        senderIdx = senderIdx % artifactCount;
        if ((receiverIdx % artifactCount) == senderIdx) {
            receiverIdx += 1;
        }
        vm.startPrank(hnr.owner());
        hnr.vouch(knownArtifacts[senderIdx], 
            knownArtifacts[receiverIdx % artifactCount], 
            amt % IArtifact(knownArtifacts[senderIdx]).totalSupply(), true);
        vm.stopPrank();
    }

    function mintToStaker(uint duration) external {
        duration = uint32(bound(duration, 1000, 1000000));
        vm.warp(block.timestamp + duration);
        vm.startPrank(address(555));
        hnr.mintToStakers();
        hnr.mintToStaker();
        vm.stopPrank();
    }

}