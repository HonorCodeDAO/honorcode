pragma solidity ^0.8.13;

interface IArtifact {

    function balanceOf(address account) external view returns (uint256);
    function initVouch(address account, uint inputHonor) external returns(uint);
    function vouch(address account) external returns (uint256);
    function unvouch(address account, uint256 unvouchAmt) external returns(uint256);
    function isValidated() external view returns(bool);
    function validate() external returns(bool);
    function receiveDonation() external returns(uint);
    function honorWithin() external view returns(uint);
    function honorAddr() external view returns(address);
    // function getNetHonor() external view returns(uint);
    function builder() external view returns(address);
    function accHonorHours() external view returns(uint);
    function totalSupply() external view returns (uint256);
    function rewardFlow() external view returns(address);
    function setRewardFlow() external returns(address);

    function redeemRewardClaim(address voucher, uint256 redeemAmt) external returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Vouch(address indexed _vouchingAddr, address indexed _to, uint256 _honorAmt, uint256 _vouchAmt);
    event Unvouch(address indexed _vouchingAddr, address indexed _from, uint256 _honorAmt, uint256 _vouchAmt);
}