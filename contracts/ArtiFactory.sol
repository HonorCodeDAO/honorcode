// SPDX-License-Identifier: GNU GPLv3
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./Artifact.sol";
import "../interfaces/IArtifactory.sol";


contract Artifactory is IArtifactory {
    address private owner;
    constructor() {
        owner = msg.sender;
    }

    function createArtifact(address builderAddr, address honorAddr, 
        string memory artifactLoc) public override returns(address) {
        require(honorAddr == msg.sender, 'Only HONOR can createArtifact');
        return address(new Artifact(builderAddr, honorAddr, artifactLoc));
    }
}
