pragma solidity ^0.8.13;

interface IGeras {

    function balanceOf(address addr) external view returns(uint);
    function vsaBalanceOf(address addr) external view returns(uint);
    function transfer(address sender, address recipient, uint256 amount) external;
    function vsaTransfer(address sender, address recipient, uint256 amount) external;
    function totalSupply() external view returns (uint);
    function totalVSASupply() external view returns(uint);
    function stakeAsset(address stakeTarget) external returns (uint);
    function getStakedAsset(address stakeTarget) external view returns (uint);
    function getArtifactToRewardFlow(address) external returns (address);
    function payForward(address) external returns (address, uint);
    function submitAllocation(address, address, uint8) external returns (uint);
    function getHonorClaim(address account) external view returns (uint);
    function getLastUpdated(address account) external view returns (uint);
    function lastUpdated() external view returns (uint);
    function mintHonorClaim(address account) external returns (uint, uint);
    function distributeReward(uint amountToDistribute, uint rate) external;
    function distributeGeras(address rewardFlowAddr) external;
    function claimReward(uint gerasClaim, address claimer) external returns (uint);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Stake(address indexed from, address indexed to, uint256 value);
    event Unstake(address indexed from, address indexed to, uint256 value);

}