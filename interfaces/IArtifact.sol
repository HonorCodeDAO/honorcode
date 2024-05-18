pragma solidity ^0.8.13;

interface IArtifact {

    function balanceOf(address account) external view returns (uint256);
    function initVouch(address account, uint inputHonor) external returns(uint);
    function updateAccumulated(address voucher) external returns (uint); 
    function vouch(address account) external returns (uint256);
    function unvouch(address account, uint256 unvouchAmt, bool isHonor) external returns(uint256);
    function antivouch(address account) external returns(uint);
    function unantivouch(address account, uint unvouchAmt, bool isHonor) external returns(uint);
    function isValidated() external view returns(bool);
    function validate() external returns(bool);
    function receiveDonation() external returns(uint);
    function honorWithin() external view returns(uint);
    function honorAddr() external view returns(address);
    function location() external view returns(string memory);
    function vouchAmtPerHonor(uint honorAmt) external view returns (uint);
    function honorAmtPerVouch(uint vouchAmt) external view returns (uint);
    // function getNetHonor() external view returns(uint);
    function builder() external view returns(address);
    function accHonorHours() external view returns(uint);
    function totalSupply() external view returns (uint256);
    function rewardFlow() external view returns(address);
    function setRewardFlow() external returns(address);
    function accRewardClaim(address claimer) external returns (uint);
    function redeemRewardClaim(address voucher, uint256 redeemAmt) external;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Vouch(address indexed _vouchingAddr, address indexed _to, uint256 _honorAmt, uint256 _vouchAmt);
    event Unvouch(address indexed _vouchingAddr, address indexed _from, uint256 _honorAmt, uint256 _vouchAmt);
}