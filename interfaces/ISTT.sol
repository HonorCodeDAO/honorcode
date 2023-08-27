pragma solidity ^0.8.13;

interface ISTT {

    function balanceOf(address addr) external view returns(uint);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Vouch(address _account, address indexed _from, address indexed _to, uint256 _value);
    // function getArtifactRewardFlow(address addr) external view returns(address);
    // function getNewRewardFlow(address stakedAssetAddr_, address artifactAddr_, address gerasAddr_) external returns(address);
    function gerasAddr() external view returns(address);
    function stakedAssetAddr() external view returns(address);
    function rootArtifact() external view returns(address);
    function setRewardFlowFactory() external;


}