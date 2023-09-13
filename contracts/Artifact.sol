// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./SafeMath.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/ISTT.sol";
// import "./Geras.sol";
import "../interfaces/IRewardFlow.sol";
import "../interfaces/IRewardFlowFactory.sol";
// import "./RewardFlow.sol";

// This contract represents an artifact, which is a desitnation of Honor and has its own 
// token to represent shares of.
// A "vouch" is comprised of a transfer of HONOR from one artifact to another, 
// by a holder of the first. HONOR is removed from the sender's balance for this artifact,  
// and added to the vouchee artifact.


contract Artifact is IArtifact {

    uint32 private _lastUpdated;

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
    uint private _totalSupply;
    bool public isValidated;
    address public rewardFlow;

    uint public constant BUILDER_RATE = 1;

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
        _lastUpdated = uint32(block.timestamp);
        _accRewardClaims[address(this)] = 0;
        _lastUpdatedVouch[address(this)] = uint32(block.timestamp);
    }

    // function initializeRF() external returns(address rewardFlow) {
    //     // rewardFlow = address(new Geras(address(this), address(this)));
    //     // rewardFlow = address(new RewardFlow(ISTT(honorAddr).getStakedAsset(), address(this), ISTT(honorAddr).getGeras()));
    //     rewardFlow = address(ISTT(honorAddr).getNewRewardFlow(
    //         ISTT(honorAddr).getStakedAsset(), address(this), ISTT(honorAddr).getGeras()));
    // }

    // Intended to be used only once and only for the root artifact.
    // We can safely take the square root since there is no other amount in this artifact.
    // By setting the square root baseline = 2^60 once, we don't need it for the other ratios.
    function initVouch(address account, uint inputHonor) external returns(uint vouchAmt) {
        require(msg.sender == honorAddr && honorWithin == 0, "Initialization by HONOR only.");
        vouchAmt = SafeMath.floorSqrt(inputHonor) << 30;
        _mint(account, vouchAmt);
        honorWithin += inputHonor;
        // netHonor += inputHonor;
    }

    /** 
      * Keep a time-weighted record of the vouch claims of each vouching address. 
      * These will be updated asynchronously, although the total will always 
      * have the correct value since we know the total supply.
    */
    function updateAccumulated(address voucher) private returns (uint256) {

        _accRewardClaims[address(this)] += _totalSupply * (
            uint32(block.timestamp) - _lastUpdatedVouch[address(this)]);
        _lastUpdatedVouch[address(this)] = uint32(block.timestamp);
        if (voucher == address(this)) { return _accRewardClaims[address(this)];
        }
        if (balanceOf(voucher) == 0) {
            return 0;
        }
        _accRewardClaims[voucher] += balanceOf(voucher) * (
            uint32(block.timestamp) - _lastUpdatedVouch[voucher]);
        _lastUpdatedVouch[voucher] = uint32(block.timestamp);
        return _accRewardClaims[voucher];
    }

    /**
      * Given some amount to redeem by the artifact's RF contract, check how much 
      * vouch-time the claimer has accumulated and deduct. The return value is meant to be 
      * a ratio relative to the total available, so that the Geras contract knows how much
      * is redeemable by this claimer.
    */
    function redeemRewardClaim(address claimer, uint256 redeemAmt) external override returns (uint256 totalClaim) {
        require(msg.sender == rewardFlow);
        require(_accRewardClaims[claimer] >= redeemAmt, 'amount unavailable to redeem');
        totalClaim = _accRewardClaims[address(this)]; 
        _accRewardClaims[claimer] = _accRewardClaims[claimer] - redeemAmt;
        _accRewardClaims[address(this)] = _accRewardClaims[address(this)] - redeemAmt;
        // remainingClaim = _accRewardClaims[voucher];
    }

    /** 
      * Given some input honor to this artifact, return the output vouch amount. 
      * The change in vouch claim will be calculated from the difference in square 
      * roots of the HONOR added to this artifact (sqrt(honor_after) - sqrt(honor_before)). 
      * The same holds true for unvouching.
      *
      * The question of "which square root" will be answered by using 2^60 as 
      * a pivot point, given its proximity to 1e18. That is, the amount of wei where the 
      * same value is returned will be 2^60. The virtue of this value is that 
      * it can be renormalized by adding 30 bits to the calculated root. 
      * (or if cube roots are used, 20 bits can be added). Essentially we are 
      * taking sqrt(X) * sqrt(2^60) to keep the curves reasonably in line. 
    */
    function vouch(address account) external override returns(uint vouchAmt) {
        uint totalHonor = ISTT(honorAddr).balanceOf(address(this));
        uint deposit = SafeMath.sub(totalHonor, honorWithin);

        updateAccumulated(account);
        updateAccumulated(address(this));

        if (SafeMath.floorSqrt(honorWithin) > 2**10) {
            vouchAmt = ((((SafeMath.floorSqrt(totalHonor)) * _totalSupply) / ( 
                SafeMath.floorSqrt(honorWithin)))) - _totalSupply;
        }
        else {
            vouchAmt = SafeMath.floorSqrt(totalHonor) << 30;
        }
        emit Vouch(account, address(this), deposit, vouchAmt);
        _mint(account, vouchAmt);
        recomputeBuilderVouch();
        honorWithin += deposit;
        // netHonor += deposit;
    }

    /** 
      * Given some valid input vouching claim to this artifact, return the output honor. 
    */
    function unvouch(address account, uint unvouchAmt, bool isHonor) external override returns(uint hnrAmt) {

        // require(ISTT(honorAddr).balanceOf(to) != 0, "Invalid vouching target");
        updateAccumulated(address(this));
        updateAccumulated(account);

        if (!isHonor) {
            require(_balances[account] >= unvouchAmt, "Artifact: Insuff. vouch bal");

            uint vouchedPost = _totalSupply - unvouchAmt;
            // the following line assumes unchanging builder vouch claims:
            // hnrAmt = honorWithin * ((_totalSupply ** 2) >> 60) - honorWithin * ((vouchedPost ** 2) >> 60);
            // hnrAmt = hnrAmt / honorWithin;
            hnrAmt = honorWithin - ((honorWithin * (vouchedPost ** 2) / ((_totalSupply ** 2))));

        }
        else {
            require(honorWithin >= unvouchAmt && _balances[account] > 0, "Insuff. hnr vouch bal");
            hnrAmt = unvouchAmt;
            unvouchAmt = _totalSupply - ((((SafeMath.floorSqrt(honorWithin - hnrAmt)) * _totalSupply) / ( 
                SafeMath.floorSqrt(honorWithin))));
            require(_balances[account] >= unvouchAmt, "Insuff. final vouch bal");
        }

        emit Unvouch(account, address(this), hnrAmt, unvouchAmt);

        recomputeBuilderVouch();
        honorWithin -= hnrAmt;
        _burn(account, unvouchAmt);
        // _balances[account] -= unvouchAmt;
        // // netHonor -= hnrAmt;
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
        if (ISTT(honorAddr).rootArtifact() == address(this)) { 
            return 0; 
        }
        uint64 timeElapsed = uint32(block.timestamp) - _lastUpdated;
        uint newHonorQtrs = (uint(timeElapsed) * honorWithin) / 7776000;
        newBuilderVouchAmt = (SafeMath.floorCbrt((accHonorHours + newHonorQtrs)/BUILDER_RATE)<< 40) - (SafeMath.floorCbrt(accHonorHours) << 40);
        accHonorHours += newHonorQtrs;
        _lastUpdated = uint32(block.timestamp);
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

    function setRewardFlow() external override returns(address rewardFlow) {
        require(rewardFlow == address(0), 'Artifact rewardFlow already set ');

        require(IRewardFlowFactory(IRewardFlow(
            msg.sender).rfFactory()).getArtiToRF(address(this)) == msg.sender, "RF/artifact pair don't match");

        rewardFlow = msg.sender;
    }

    function receiveDonation() external override returns(uint) {
        require(msg.sender == honorAddr, 'Only HONOR contract can donate');
        honorWithin += SafeMath.sub(ISTT(honorAddr).balanceOf(address(this)), honorWithin);
        // netHonor += SafeMath.sub(totalHonor, honorWithin);
        return honorWithin;
    }

    function validate() external override returns(bool) {
        require(msg.sender == honorAddr, 'Invalid validation source');
        isValidated = true;
        return isValidated;
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
