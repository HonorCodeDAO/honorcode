// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.13;

import "./Honor.sol";

contract HonorFactory {
    address private owner;
    mapping (string => address) private honorRegistry;

    constructor() {
        owner = msg.sender;
    }

    function createHonor(
        address artifactoryAddress, 
        string memory name) 
    public returns(address honorAddress) {
        require(honorRegistry[name] == address(0), 'HonorFactory: Name taken');
        honorAddress = address(new Honor(artifactoryAddress, name, msg.sender));
        honorRegistry[name] = honorAddress;
    }

    function getHonorAddress(string memory name) external view returns(address){
        return honorRegistry[name];
    }
}
