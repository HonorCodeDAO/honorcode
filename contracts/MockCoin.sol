// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "../interfaces/IWStETH.sol";

// This coin-like contract is meant to test the reward flow aspects of the 
// overarching project. It will be rebasing over time, to emulate a yield
// bearing asset.

contract MockCoin is IWStETH {
    mapping (address => uint) private _balances;
    uint public total_supply = 10000e18;
    uint constant public TOTAL_PERCENT = 10000e18; 
    uint public lastUpdated;

    // event Transfer(address indexed _from, address indexed _to, uint256 _value);

    constructor() {
        _balances[msg.sender] = total_supply;
        lastUpdated = block.timestamp;
    }

    // function sendCoin(address receiver, uint amount) public returns(bool sufficient) {
    //     if (balances[msg.sender] < amount) return false;
    //     balances[msg.sender] -= amount;
    //     balances[receiver] += amount;
    //     emit Transfer(msg.sender, receiver, amount);
    //     return true;
    // }

    function totalSupply() public override view returns (uint) {
        return total_supply;
    }

    function rebase() public {
        total_supply += total_supply * ((block.timestamp - lastUpdated) >> 5) / 31536000;
        lastUpdated = block.timestamp;
    }

    function balanceOf(address addr) public override view returns(uint) {
        return _balances[addr];
    }

    function transfer(address recipient, uint256 amount) public override virtual returns (bool) {

        uint256 senderBalance = _balances[msg.sender];
        rebase();
        uint256 amtToSend = amount;
        require(senderBalance >= amtToSend, "MockCoin: tfer exceeds bal");
        _balances[msg.sender] = senderBalance - amtToSend;
        _balances[recipient] += amtToSend;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function getStETHByWstETH(uint256 _wstETHAmount) external override view returns (uint256) {
        return _wstETHAmount * total_supply / TOTAL_PERCENT;
    }

    function getWstETHByStETH(uint256 _stETHAmount) external override view returns (uint256) {
        return _stETHAmount * TOTAL_PERCENT / total_supply;
    }

    function stEthPerToken() external override view returns (uint256) {
        return (1 ether) * total_supply / TOTAL_PERCENT;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override virtual returns (bool) {
        return false;
    }

    function allowance(address owner, address spender) external override view returns (uint256) {
        return 0;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        return false;
    }


}
