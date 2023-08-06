// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./SafeMath.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/ISTT.sol";
// import "./Geras.sol";
// import "../interfaces/IRewardFlow.sol";
// import "./RewardFlow.sol";

// This contract represents an artifact, which is a desitnation of Honor and has its own 
// token to represent shares of.
// A "vouch" is comprised of a transfer of HONOR from one artifact to another, 
// by a holder of the first. HONOR is removed from the sender's balance for this artifact,  
// and added to the vouchee artifact.


contract Artifact is IArtifact {

    string public location; 
    address public honorAddr;
    address public builder;
    // uint public antihonorWithin;
    uint public honorWithin;
    // uint public netHonor;
    uint public accHonorHours;
    // uint public totalIncomingRewardFlow;
    uint public builderHonor;
    // uint public accReward;
    // uint public virtualStaked;
    uint64 private _lastUpdated;
    uint private _totalSupply;
    bool private _isProposed;
    address public rewardFlow;

    // uint public constant rewardMult = 1;

    // mapping (address => mapping (address => uint)) budgets;

    mapping (address => uint) private _balances;
    // mapping (address => uint) private _staked;

    // These mappings are necessary to track the relative share of each claim.
    // The reward flows are time-weighted, so they need to be synced together.
    mapping (address => uint) private _accRewardClaims;
    mapping (address => uint) private _lastUpdatedVouch;


    constructor(address builderAddr, address honorAddress, string memory artifactLoc) {
        builder = builderAddr;
        location = artifactLoc;
        honorAddr = honorAddress;
        _balances[tx.origin] = 0;
        // Default is to keep all flow to this artifact.
        // budgetFlow[address(this)] = 1 << 32 - 1;
        _lastUpdated = uint64(block.timestamp);
        _accRewardClaims[address(this)] = 0;
        _lastUpdatedVouch[address(this)] = uint64(block.timestamp);
    }

    // function initializeRF() external returns(address rewardFlow) {
    //     // rewardFlow = address(new Geras(address(this), address(this)));
    //     // rewardFlow = address(new RewardFlow(ISTT(honorAddr).getStakedAsset(), address(this), ISTT(honorAddr).getGeras()));
    //     rewardFlow = address(ISTT(honorAddr).getNewRewardFlow(
    //         ISTT(honorAddr).getStakedAsset(), address(this), ISTT(honorAddr).getGeras()));
    // }


    function initVouch(address account, uint inputHonor) external returns(uint vouchAmt) {
        // require(msg.sender == honorAddr, "Initial");
        vouchAmt = SafeMath.floorSqrt(inputHonor);
        _mint(account, vouchAmt);
        honorWithin += inputHonor;
        // netHonor += inputHonor;
    }


    function updateAccumulated(address voucher) private returns (uint256 acc) {

        _accRewardClaims[address(this)] += _totalSupply * (
            _lastUpdatedVouch[address(this)] - uint64(block.timestamp));
        _lastUpdatedVouch[address(this)] = uint64(block.timestamp);
        if (voucher == address(this)) { 
            acc = _accRewardClaims[address(this)];
            return acc;
        }
        if (balanceOf(voucher) == 0) {
            return 0;
        }
        _accRewardClaims[voucher] += balanceOf(voucher) * (
            _lastUpdatedVouch[voucher] - uint64(block.timestamp));
        _lastUpdatedVouch[voucher] = uint64(block.timestamp);
        acc = _accRewardClaims[voucher];
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
        // updateAccumulated(account);

        vouchAmt = SafeMath.sub(SafeMath.floorSqrt(totalHonor), SafeMath.floorSqrt(honorWithin));

        emit Vouch(account, address(this), deposit, vouchAmt);
        _mint(account, vouchAmt);
        recomputeBuilderVouch();
        honorWithin += deposit;
        // netHonor += deposit;
    }


    /** 
      * Given some input honor to this artifact, return the output vouch amount. 
    */
    // function antivouch(address account) external override returns(uint vouchAmt) {
    //     uint totalHonor = ISTT(honorAddr).balanceOf(address(this));
    //     uint deposit = SafeMath.sub(totalHonor, honorWithin + antihonorWithin);

    //     // uint honorCbrt = SafeMath.floorCbrt(totalHonor);
    //     // uint prevHonorCbrt = SafeMath.floorCbrt(honorWithin);
    //     // vouchAmt = SafeMath.sub(honorCbrt * honorCbrt, prevHonorCbrt * prevHonorCbrt);

    //     vouchAmt = SafeMath.sub(SafeMath.floorSqrt(totalHonor), SafeMath.floorSqrt(honorWithin));

    //     emit Vouch(account, address(this), deposit, vouchAmt);
    //     _mint(account, vouchAmt);
    //     recomputeBuilderVouch();
    //     antihonorWithin += deposit;
    //     netHonor -= deposit;

    // }


    /** 
      * Given some valid input vouching claim to this artifact, return the output honor. 
    */
    function unvouch(address account, uint unvouchAmt) external override returns(uint hnrAmt) {

        require(_balances[account] >= unvouchAmt, "Insuff. vouch bal");
        // require(ISTT(honorAddr).balanceOf(to) != 0, "Invalid vouching target");
        // updateAccumulated(account);
        uint vouchedPost = SafeMath.sub(_totalSupply, unvouchAmt);

        hnrAmt = SafeMath.sub(_totalSupply ** 2, vouchedPost ** 2);

        emit Unvouch(account, address(this), hnrAmt, unvouchAmt);
        recomputeBuilderVouch();
        honorWithin -= hnrAmt;
        _burn(account, unvouchAmt);
        // _balances[account] -= unvouchAmt;
        // // netHonor -= hnrAmt;
    }

    /** 
      * Given some valid input vouching claim to this artifact, return the output honor. 
    */
    // function unantivouch(address account, address to, uint unvouchAmt) external returns(uint hnrAmt) {

    //     require(_balances[account] >= unvouchAmt, "Insufficient vouching balance");
    //     // require(ISTT(honorAddr).balanceOf(to) != 0, "Invalid vouching target");

    //     uint vouchedPost = SafeMath.sub(_totalSupply, unvouchAmt);

    //     hnrAmt = SafeMath.sub(_totalSupply ** 2, vouchedPost ** 2);

    //     emit Unvouch(account, address(this), hnrAmt, unvouchAmt);
    //     recomputeBuilderVouch();
    //     antihonorWithin -= hnrAmt;
    //     netHonor += hnrAmt;
    //     _burn(account, unvouchAmt);
    //     _balances[account] -= unvouchAmt;
    // }

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

    // function accumulateReward(uint64 timeElapsed) private {
    //     accReward += virtualStaked * uint(timeElapsed) / rewardMult;
    // }

    /* 
     * The amount of the vouch claim going to the builder will increase based on the vouched HONOR over time. 
     */
    function recomputeBuilderVouch() private returns (uint newBuilderVouchAmt) {
        if (ISTT(honorAddr).getRootArtifact() == address(this)) { 
            return 0; 
        }
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
        // if (addr==address(this)) {
        //     return _balances[msg.sender];
        // }
        return _balances[addr];
    }

    function getBuilder() external override view returns(address) {
        return builder;
    }

    function getInternalHonor() external override view returns(uint) {
        return honorWithin;
    }

    function getHonorAddr() external override view returns(address) {
        return honorAddr;
    }

    // function getNetHonor() external override view returns(uint) {
    //     return netHonor;
    // }

    function getRewardFlow() external override view returns(address) {
        return rewardFlow;
    }

    function accumulatedHonorHours() external override view returns(uint) {
        return accHonorHours;
    }

    function receiveDonation() external override returns(uint) {
        honorWithin += SafeMath.sub(ISTT(honorAddr).balanceOf(address(this)), honorWithin);
        // netHonor += SafeMath.sub(totalHonor, honorWithin);
        return honorWithin;
    }

    function isValidated() external override view returns(bool) {
        return !_isProposed;
    }

    function validate() external override returns(bool) {
        require(msg.sender == honorAddr, 'Invalid validation source');
        _isProposed = false;
        return !_isProposed;
    }


    function _mint(address account, uint256 amount) internal virtual {
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "Art: burn from zero");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "Art: burn exceeds bal");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }
}
