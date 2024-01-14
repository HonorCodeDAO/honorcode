pragma solidity ^0.8.13;

import "./IERC20.sol";


interface IWStETH is IERC20 {
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);

    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);

}