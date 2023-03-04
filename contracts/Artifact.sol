// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./SafeMath.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/ISTT.sol";

// This contract represents an artifact, which is a desitnation of Honor and has its own 
// token to represent shares of.
// A "vouch" is comprised of a transfer of HONOR from one artifact to another, 
// by a holder of the first. HONOR is removed from the sender's balance for this artifact,  
// and added to the vouchee artifact.


contract Artifact is IArtifact {

    string public location; 
    address public honorAddr;
    address public builder;
    uint public honorWithin;
    uint public accHonorHours;
    uint public totalIncomingRewardFlow;
    uint public builderHonor;
    uint public accReward;
    uint64 private _lastUpdated;
    uint private _totalSupply;
    bool private _isProposed;
    bool private _isRoot;

    // Where are the incoming rewards coming from? These sum to the total flow. 
    // mapping (address => uint) incomeFlow;
    // Where do the incoming rewards flow? 
    // mapping (address => uint) budgetFlow;
    // Where is everybody voting for these rewards to flow? The aggregate value 
    // above will be calculated from a sum weighted (by vouch size) of individual submitted budgets. 
    // If not set, will default to status quo. 
    // mapping (address => mapping (address => uint)) budgets;

    mapping (address => uint) private _balances;
    mapping (address => uint) private _staked;

    constructor(address builderAddr, address honorAddress, string memory artifactLoc) {
        builder = builderAddr;
        location = artifactLoc;
        honorAddr = honorAddress;
        _balances[tx.origin] = 0;
        // Default is to keep all flow to this artifact.
        // budgetFlow[address(this)] = 1 << 32 - 1;
        _lastUpdated = uint64(block.timestamp);
    }

    /** 
      * Given some input honor to this artifact, return the output vouch amount. 
    */
    function vouch(address account) external override returns(uint vouchAmt) {
        uint totalHonor = ISTT(honorAddr).balanceOf(address(this));
        uint deposit = SafeMath.sub(totalHonor, honorWithin);

        // uint honorCbrt = SafeMath.floorCbrt(totalHonor);
        // uint prevHonorCbrt = SafeMath.floorCbrt(honorWithin);
        // vouchAmt = SafeMath.sub(honorCbrt * honorCbrt, prevHonorCbrt * prevHonorCbrt);

        vouchAmt = SafeMath.sub(SafeMath.floorSqrt(totalHonor), SafeMath.floorSqrt(honorWithin));

        emit Vouch(account, address(this), deposit, vouchAmt);
        _mint(account, vouchAmt);
        honorWithin += deposit;
        recomputeBuilderVouch();
    }

    function initVouch(address account, uint inputHonor) external returns(uint vouchAmt) {
        require(msg.sender == honorAddr, "Only used for initial root vouching");
        vouchAmt = SafeMath.floorSqrt(inputHonor);
        _mint(account, vouchAmt);
        honorWithin += inputHonor;
    }

    /** 
      * Given some input vouching claim to this artifact, return the output honor. 
    */
    function unvouch(address account, address to, uint unvouchAmt) external returns(uint hnrAmt) {

        require(_balances[account] >= unvouchAmt, "Insufficient vouching balance");
        // require(ISTT(honorAddr).balanceOf(to) != 0, "Invalid vouching target");

        uint vouchedPost = SafeMath.sub(_totalSupply, unvouchAmt);

        hnrAmt = SafeMath.sub(_totalSupply ** 2, vouchedPost ** 2);

        emit Unvouch(account, address(this), hnrAmt, unvouchAmt);
        honorWithin -= hnrAmt;
        _burn(account, unvouchAmt);
        _balances[account] -= unvouchAmt;
        recomputeBuilderVouch();
    }

    /* 
     * Only recompute for the specific address, to avoid having to sum everything. 
     */
    // function recomputeBudget(address account, address artifactFrom, address artifactTo) private returns (bool computed) {
    //     uint vouchAmt = _balances[account];
    //     if (vouchAmt == 0) { return true; }
    //     return true;
    // }

    // function setBudget(address account, address artifactFrom, address artifactTo, uint amount) private returns (bool budgetSet) {
    //     require(budgets[account][artifactFrom] >= amount && amount < 1 << 32);
    //     require(account == honorAddr || account == msg.sender);
    //     if (artifactFrom == address(this)) {
    //         require(budgets[account][artifactFrom] > amount);
    //     }
    //     budgets[account][artifactFrom] -= amount;
    //     budgets[account][artifactTo] += amount;
    //     return recomputeBudget(account);
    // }


    function recomputeBuilderVouch() private returns (uint newBuilderVouchAmt) {
        if (_isRoot) { return 0; }
        uint64 timeElapsed = uint64(block.timestamp) - _lastUpdated;
        uint newHonorHours = (uint(timeElapsed) * honorWithin) / 86400;
        newBuilderVouchAmt = SafeMath.floorCbrt(accHonorHours + newHonorHours) - SafeMath.floorCbrt(accHonorHours);
        accHonorHours += newHonorHours;
        _lastUpdated = uint64(block.timestamp);
        if (newBuilderVouchAmt <= 0) {
            return newBuilderVouchAmt;
        }
        emit Vouch(builder, address(this), 0, newBuilderVouchAmt);
        _mint(builder, newBuilderVouchAmt);
    }

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr];
    }

    function getBuilder() external override view returns(address) {
        return builder;
    }

    function internalHonor() external override view returns(uint) {
        return honorWithin;
    }

    function accumulatedHonorHours() external override view returns(uint) {
        return accHonorHours;
    }

    function receiveDonation() external override returns(uint) {
        uint totalHonor = ISTT(honorAddr).balanceOf(address(this));
        honorWithin += SafeMath.sub(totalHonor, honorWithin);
        return honorWithin;
    }

    function isValidated() external override view returns(bool) {
        return !_isProposed;
    }

    function setRoot() external override returns(bool) {
        require(msg.sender == honorAddr);
        _isRoot = true;
        return _isRoot;
    }

    function validate() external override returns(bool) {
        require(msg.sender == honorAddr);
        _isProposed = false;
        return !_isProposed;
    }

    function _mint(address account, uint256 amount) internal virtual {
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
}
