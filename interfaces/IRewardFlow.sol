pragma solidity ^0.8.13;

interface IRewardFlow {

    // function balanceOf(address addr) external view returns(uint);
    function artifactAddr() external view returns(address);
    function rfFactory() external view returns(address);
    function payForward() external returns(address, uint);
    function availableReward() external returns(uint);
    function setArtifact() external;
    function submitAllocation(address targetAddr, uint8 allocAmt) external returns(uint);
    function redeemReward(address claimer, uint redeemAmt) external returns (uint);
    event Allocate(address indexed from, address indexed to, uint256 value);
    event Distribute(address indexed from, address indexed to, uint256 value);

}