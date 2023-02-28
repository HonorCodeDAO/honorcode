pragma solidity ^0.8.13;

interface IArtifact {

    /**
     * @dev Returns the amount of tokens vouched in `artifact`.
     */
    function balanceOf(address account) external view returns (uint256);
    function vouch(address account) external returns (uint256);
    function unvouch(address to, uint256 unvouchAmt) external returns(uint256);



}