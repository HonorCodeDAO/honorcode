pragma solidity ^0.8.13;

interface IGeras {

    function balanceOf(address addr) external view returns(uint);
    function transfer(address sender, address recipient, uint256 amount) external;
    event Transfer(address indexed from, address indexed to, uint256 value);

}