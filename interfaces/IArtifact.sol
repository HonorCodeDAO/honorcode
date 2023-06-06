pragma solidity ^0.8.13;

interface IArtifact {

    function balanceOf(address account) external view returns (uint256);
    function vouch(address account) external returns (uint256);
    function unvouch(address account, address to, uint256 unvouchAmt) external returns(uint256);
    function isValidated() external view returns(bool);
    function validate() external returns(bool);
    function receiveDonation() external returns(uint);
    function getInternalHonor() external view returns(uint);
    function getNetHonor() external view returns(uint);
    function getBuilder() external view returns(address);
    function accumulatedHonorHours() external view returns(uint);
    function totalSupply() external view returns (uint256);
    function setRoot() external returns(bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Vouch(address indexed _vouchingAddr, address indexed _to, uint256 _honorAmt, uint256 _vouchAmt);
    event Unvouch(address indexed _vouchingAddr, address indexed _from, uint256 _honorAmt, uint256 _vouchAmt);
}