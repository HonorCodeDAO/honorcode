pragma solidity ^0.8.13;

interface IGeras {

    function balanceOf(address addr) external view returns(uint);
    function transfer(address sender, address recipient, uint256 amount) external;
    function stakeAsset(address stakeTarget, uint amt) external returns (uint);
    function getStakedAsset(address stakeTarget) external view returns (uint);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Stake(address indexed from, address indexed to, uint256 value);

}