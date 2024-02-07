pragma solidity ^0.8.13;

interface IRewardFlowFactory {

    function createRewardFlow(address, address, address) external returns(address);
    function getArtiToRF(address) external view returns(address);

}