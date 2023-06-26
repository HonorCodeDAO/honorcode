// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./Artifact.sol";
import "../interfaces/IArtifact.sol";

contract Artifactory {
    function createArtifact(address builderAddr, address honorAddress, string memory artifactLoc) public returns(Artifact) {
        return new Artifact(builderAddr, honorAddress, artifactLoc);
    }
}
