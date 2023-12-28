pragma solidity ^0.8.13;

interface ISTT {

    function balanceOf(address addr) external view returns(uint);
    function totalSupply() external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Vouch(address _account, address indexed _from, address indexed _to, uint256 _value);
    function setOwner(address newOwner) external;
    function setRewardFlowFactory() external;
    function setGeras(address gerasAddress) external;
    function gerasAddr() external view returns(address);
    function stakedAssetAddr() external view returns(address);
    function rootArtifact() external view returns(address);
    function owner() external view returns(address);
    function rewardFlowFactory() external view returns(address);
    function stakingMintPool() external view returns (uint);
    function proposeArtifact(address _from, address builder, string memory loc, bool should_validate) external returns(address);
    function validateArtifact(address _from, address addr) external returns(bool);
    function vouch(address _from, address _to, uint amount) external returns(uint);
    // function internalHonorBalanceOfArtifact(address addr) external view returns(uint);


}