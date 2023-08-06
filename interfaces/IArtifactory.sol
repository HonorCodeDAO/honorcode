pragma solidity ^0.8.13;

interface IArtifactory {

    function createArtifact(address builderAddr, address honorAddr, string memory artifactLoc) external returns(address);
}