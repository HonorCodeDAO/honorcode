pragma solidity ^0.8.13;

interface ISTT {

    /**
     * @dev Returns the amount of tokens vouched in `artifact`.
     */

    // struct data {
    //     uint posHNR;
    //     uint negHNR;
    //     uint posFlow;
    //     uint negFlow;
    //     bool isProposed;
    //     bool isLive;
    // }

    function balanceOf(address artifact) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    // function getArtifactData(address addr) public view returns (data memory);


}