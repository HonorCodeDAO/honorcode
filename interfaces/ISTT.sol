pragma solidity ^0.8.13;

interface ISTT {

    function balanceOf(address addr) external view returns(uint);
    event Transfer(address indexed from, address indexed to, uint256 value);
    // function getArtifactRewardFlow(address addr) external view returns(address);
    // function getNewRewardFlow(address stakedAssetAddr_, address artifactAddr_, address gerasAddr_) external returns(address);
    function getGeras() external view returns(address);
    function getStakedAsset() external view returns(address);

}