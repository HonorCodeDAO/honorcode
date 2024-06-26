pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IGeras is IERC20 {

    function balanceOf(address addr) external view returns(uint);
    function vsaBalanceOf(address addr) external view returns(uint);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function vsaTransfer(address recipient, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint);
    function totalVSASupply() external view returns(uint);
    function stakeAsset(address stakeTarget) external returns (uint);
    function getStakedAsset(address stakeTarget) external view returns (uint);
    function getArtifactToRewardFlow(address) external view returns (address);
    function createRewardFlow(address artifactAddr) external returns(address);
    function payForward(address) external returns (address, uint);
    function submitAllocation(address, address, uint8) external returns (uint);
    function getHonorClaim(address account) external view returns (uint);
    function getLastUpdated(address account) external view returns (uint);
    function lastUpdated() external view returns (uint);
    function mintHonorClaim(address account) external returns (uint, uint);
    function distributeReward(uint amountToDistribute, uint rate) external;
    function distributeGeras(address rewardFlowAddr) external;
    function claimReward(uint gerasClaim, address claimer) external returns (uint);

    event VSATransfer(address indexed from, address indexed to, uint256 value);
    event Stake(address indexed from, address indexed to, uint256 value);
    event Unstake(address indexed from, address indexed to, uint256 value);

}