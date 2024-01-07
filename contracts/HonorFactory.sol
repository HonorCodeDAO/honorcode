pragma solidity ^0.8.13;

import "./Honor.sol";

contract HonorFactory {
    address private owner;
    mapping (address => address) private honorRegistry;

    constructor() {
        owner = msg.sender;
    }

    function createHonor(
        address artifactoryAddress, 
        string memory name) 
    public returns(address) {

        honorRegistry[artifactoryAddress] = address(
            new Honor(artifactoryAddress, name));
        honorRegistry[honorRegistry[artifactoryAddress]] = artifactoryAddress;
        return honorRegistry[artifactoryAddress];
    }

    function getHonorArtiFactory(address addr) external view returns(address) {
        return honorRegistry[addr];
    }
}
