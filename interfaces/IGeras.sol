pragma solidity ^0.8.13;

interface IGeras {

    function balanceOf(address addr) external view returns(uint);
    function transfer(address sender, address recipient, uint256 amount) external;
    function stakeAsset(address stakeTarget) external returns (uint);
    function getStakedAsset(address stakeTarget) external view returns (uint);
    function totalVirtualStakedAsset() external view returns(uint);
    function getHonorClaim(address account) external view returns (uint);
    function getLastUpdated(address account) external view returns (uint);
    function lastUpdated() external view returns (uint);
    function mintHonorClaim(address account) external returns (uint, uint);
    function distributeReward(uint amountToDistribute, uint rate) external;
    function claimReward(uint gerasClaim, address claimer) external returns (uint);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Stake(address indexed from, address indexed to, uint256 value);

}