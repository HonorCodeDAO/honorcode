pragma solidity ^0.8.13;

interface IRewardFlow {

    // function balanceOf(address addr) external view returns(uint);
    function getArtifact() external view returns(address);
    event Transfer(address indexed from, address indexed to, uint256 value);

}