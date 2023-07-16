pragma solidity ^0.8.13;

interface IRewardFlow {

    // function balanceOf(address addr) external view returns(uint);
    function getArtifact() external view returns(address);
    function payForward() external returns(address, uint);
    // function receiveVSR() external returns (uint);
    function submitAllocation(address targetAddr, uint allocAmt) external returns(uint);
    event Allocate(address indexed from, address indexed to, uint256 value);
    event Distribute(address indexed from, address indexed to, uint256 value);

}