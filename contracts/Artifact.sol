// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./SafeMath.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/ISTT.sol";
import "../interfaces/IRewardFlow.sol";
import "../interfaces/IRewardFlowFactory.sol";

// This contract represents an artifact, which is a desitnation of Honor and 
// has its own token to represent shares of: the vouch claim.
// A "vouch" is comprised of a transfer of HONOR from one artifact to another, 
// by a holder of the first. HONOR is removed from the sender's balance for this 
// artifact, and added to the vouchee artifact.
// In return, some amount of vouch claim token will be redeemed/burned to the 
// sending artifact, and minted from the receiving one. This will be governed 
// according to a two-way quadratic bonding curve.


contract Artifact is IArtifact {

    uint32 private _lastUpdated;
    uint private _totalSupply;
    mapping (address => uint) private _balances;

    // These mappings are necessary to track the relative share of each claim.
    // The reward flows are time-weighted, so they need to be synced together.
    mapping (address => uint) private _accRewardClaims;
    mapping (address => uint32) private _lastUpdatedVouch;

    string public location; 
    address public honorAddr;
    address public builder;
    uint public honorWithin;
    uint public accHonorHours;
    bool public isValidated;
    address public rewardFlow;

    // Currently unutilized but making room for future extensions.
    uint public antihonorWithin;
    int public netHonor;
    
    constructor(
        address builderAddr,  
        address honorAddress, 
        string memory artifactLoc) {
        builder = builderAddr;
        location = artifactLoc;
        honorAddr = honorAddress;
        _balances[builderAddr] = 0;
        _lastUpdated = uint32(block.timestamp);
        _accRewardClaims[address(this)] = 0;
        _lastUpdatedVouch[address(this)] = uint32(block.timestamp);
    }

    /* 
     * Intended to be used only once upon initialization/validation.
     * We can safely take the square root since there is no other amount in this 
     * artifact. By setting the square root baseline = 2^60 once, we don't need 
     * it for the other ratios. Here, we could probably use fixed values for 
     * the VALIDATE_AMT but this illustrates the bonding process.
     * Unfortunately, we cannot simply take the HONOR deposited to this artifact
     * because the honor contract will not have been constructed for the root. 
     */
    function initVouch(address account, uint inputHonor)
    external returns(uint vouchAmt) {
        require(msg.sender == honorAddr && honorWithin == 0, 
            'Initialization by HONOR only.');
        if (inputHonor == 0) {
            inputHonor = ISTT(honorAddr).balanceOf(address(this));
            require(inputHonor > 0, 'No HONOR transferred to init.');
        }

        vouchAmt = SafeMath.floorSqrt(inputHonor) << 30;
        _mint(account, vouchAmt);
        honorWithin = inputHonor;
        _lastUpdatedVouch[account] = uint32(block.timestamp);

        // netHonor += inputHonor;
    }

    /** 
      * Keep time-weighted record of the vouch claims of each vouching address. 
      * These will be updated asynchronously, although the total will always 
      * have the correct value since we know the total supply.
    */
    function updateAccumulated(address voucher) public override returns (uint) {

        // We don't want an infinite loop, but we do want to include the builder
        // in the new total. 
        // if (voucher != builder) { recomputeBuilderVouch(); }

        if (uint32(block.timestamp) == _lastUpdatedVouch[voucher]) {
            return _accRewardClaims[voucher];
        }

        _accRewardClaims[address(this)] += _totalSupply * (
            uint32(block.timestamp) - _lastUpdatedVouch[address(this)]);
        _lastUpdatedVouch[address(this)] = uint32(block.timestamp);

        if (voucher == address(this)) { return _accRewardClaims[address(this)];}
        if (_lastUpdatedVouch[voucher] != 0) {
            if (_balances[voucher] == 0) { return _accRewardClaims[voucher]; }
            _accRewardClaims[voucher] += _balances[voucher] * (
                uint32(block.timestamp) - _lastUpdatedVouch[voucher]);
        }
        _lastUpdatedVouch[voucher] = uint32(block.timestamp);
        return _accRewardClaims[voucher];
    }

    /**
      * Given some amount to redeem by the artifact's RF contract, check how  
      * much vouch-time the claimer has accumulated and deduct. The return value 
      * is meant to be a ratio relative to the total available, so that the 
      * Geras contract knows how much is redeemable by this claimer.
    */
    function redeemRewardClaim(address claimer, uint256 redeemAmt) 
    external override {
        // require(msg.sender == rewardFlow, 'Only RF can redeem reward');
        require(_accRewardClaims[claimer] >= redeemAmt, 
            'redeem amount exceeds accRewardClaims');
        _accRewardClaims[claimer] = _accRewardClaims[claimer] - redeemAmt;
        _accRewardClaims[address(this)] = _accRewardClaims[address(this)] - redeemAmt;
    }

    function accRewardClaim(address claimer, bool activeOnly) 
    external override view returns (uint) {
        if (!activeOnly) {
            return _accRewardClaims[claimer];
        }
        if  (claimer == address(this)) {
            return _accRewardClaims[claimer] - (
            _accRewardClaims[ISTT(honorAddr).owner()]);
        }
        return (claimer == ISTT(honorAddr).owner()) ? 0 : (
            _accRewardClaims[claimer]);
    } 

    function vouchAmtPerHonor(uint honorAmt) external override view returns (
        uint) {
        return _totalSupply - ((((
            SafeMath.floorSqrt(honorWithin - honorAmt)) * _totalSupply) / ( 
            SafeMath.floorSqrt(honorWithin))));
    }

    function honorAmtPerVouch(uint vouchAmt) external override view returns (
        uint) {
        return honorWithin - ((honorWithin * ((_totalSupply - vouchAmt) ** 2) /(
                (_totalSupply ** 2))));
    }

    /** 
      * Given some input honor to this artifact, return the output vouch amount. 
      * The change in vouch claim will be calculated from the difference in 
      * square roots of the HONOR added to this artifact 
      * (sqrt(honor_after) - sqrt(honor_before)). 
      * The same holds true for unvouching.
      *
      * The question of "which square root" will be answered by using 2^60 as 
      * a pivot point, given its proximity to 1e18. That is, the amount of wei 
      * where the same value is returned will be 2^60. The virtue of this value 
      * is that it can be renormalized by adding 30 bits to the calculated root. 
      * (or if cube roots are used, 20 bits can be added). Essentially we are 
      * taking sqrt(X) * sqrt(2^60) to keep the curves reasonably in line. 
      * The formula for Delta(V) is:
      * V_out = sqrt(H_T + H_in) * V_T / sqrt(H_T) - V_T
    */
    function vouch(address account) external override returns(uint vouchAmt) {
        uint totalHonor = ISTT(honorAddr).balanceOf(address(this));
        require(totalHonor > honorWithin, 'No new HONOR added to vouch');
        uint deposit = totalHonor - honorWithin;

        updateAccumulated(account);

        if (SafeMath.floorSqrt(honorWithin) > 2**10) {
            vouchAmt = ((((SafeMath.floorSqrt(totalHonor)) * _totalSupply) / ( 
                SafeMath.floorSqrt(honorWithin)))) - _totalSupply;
        }
        else {
            vouchAmt = SafeMath.floorSqrt(totalHonor) << 30;
        }
        emit Vouch(account, address(this), deposit, vouchAmt);
        _mint(account, vouchAmt);
        if (isValidated) { recomputeBuilderVouch(); }
        honorWithin += deposit;
        // netHonor += deposit;
    }

    /** 
       Given some valid input vouching claim to this artifact, return the HONOR. 
       Delta(H) is calculated as:
       H_out = H_T - (H_T * (V_T - V_in)^2) / V_T^2

       OR 

       V_in = V_T - (V_T * sqrt(H_T - H_out) / sqrt(H_T))
    */
    function unvouch(address account, uint unvouchAmt, bool isHonor) 
    external override returns(uint hnrAmt) {
        require(account == msg.sender || msg.sender == honorAddr, 
            'Only Honor or sender can unvouch');
        updateAccumulated(account);

        if (!isHonor) {
            require(_balances[account] >= unvouchAmt, 
                'Artifact: Insuff. vouch bal');

            uint vouchedPost = _totalSupply - unvouchAmt;
            hnrAmt = honorWithin - ((honorWithin * (vouchedPost ** 2) / (
                (_totalSupply ** 2))));
        }
        else {
            require(honorWithin >= unvouchAmt && _balances[account] > 0, 
                'Insuff. honor vouch bal');
            hnrAmt = unvouchAmt;
            unvouchAmt = _totalSupply - ((((
                SafeMath.floorSqrt(honorWithin - hnrAmt)) * _totalSupply) / ( 
                SafeMath.floorSqrt(honorWithin))));
            require(_balances[account] >= unvouchAmt, 'Insuff final vouch bal');
        }

        emit Unvouch(account, address(this), hnrAmt, unvouchAmt);

        if (isValidated) { recomputeBuilderVouch(); }
        
        honorWithin -= hnrAmt;
        _burn(account, unvouchAmt);
        // netHonor -= hnrAmt;
    }

    /** 
      * Given some input antihonor to this artifact, return the vouch amount. 
    */
    function antivouch(address account) external override returns(uint vouchAmt) {
    //     uint totalHonor = ISTT(honorAddr).balanceOf(address(this));
    //     uint deposit = SafeMath.sub(totalHonor, honorWithin + antihonorWithin);
    //     emit Vouch(account, address(this), deposit, vouchAmt);
    //     _mint(account, vouchAmt);
    //     recomputeBuilderVouch();
    //     antihonorWithin += deposit;
    //     netHonor -= deposit;
        require(false, 'antivouch unimplemented.');
        return 0;
    }

    /** 
      * Given some valid input vouching claim to this artifact, return the honor. 
    */
    function unantivouch(address account, uint unvouchAmt, bool isHonor) 
    external override returns(uint hnrAmt) {
    //     require(_balances[account] >= unvouchAmt, "Insufficient vouching balance");
    //     // require(ISTT(honorAddr).balanceOf(to) != 0, "Invalid vouching target");
    //     uint vouchedPost = SafeMath.sub(_totalSupply, unvouchAmt);
    //     emit Unvouch(account, address(this), hnrAmt, unvouchAmt);
    //     recomputeBuilderVouch();
    //     antihonorWithin -= hnrAmt;
    //     netHonor += hnrAmt;
    //     _burn(account, unvouchAmt);
    //     _balances[account] -= unvouchAmt;

        require(false, 'unantivouch unimplemented.');
        return 0;
    }

    /* 
     * The amount of the vouch claim going to the builder will increase based on 
     * the vouched HONOR over time, which is tracked by accumulated HONOR hours. 
     * However, below a floor of 2^30 we do not add to the builder amount, 
     * because the cube root would be too distorted.
     * This means that the builder comp begins at 2^50 = 2^10 * 2^40 units.
     */
    function recomputeBuilderVouch() private returns (uint newBuilderVouchAmt) {
        if (ISTT(honorAddr).rootArtifact() == address(this)) { 
            return 0; 
        }
        uint newHonorQtrs = ((block.timestamp - uint(_lastUpdated)) * (
            honorWithin)) / 7776000;
        newBuilderVouchAmt = (SafeMath.floorCbrt((
            (accHonorHours + newHonorQtrs) >> 30) << 30) << 40) - (
            SafeMath.floorCbrt((accHonorHours >> 30) << 30) << 40);
        accHonorHours += newHonorQtrs;
        _lastUpdated = uint32(block.timestamp);
        if (newBuilderVouchAmt <= 0) {
            return newBuilderVouchAmt;
        }
        emit Vouch(builder, address(this), 0, newBuilderVouchAmt);
        _mint(builder, newBuilderVouchAmt);
        updateAccumulated(builder);
    }

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr];
    }

    function setRewardFlow() external override returns(address) {
        // require(rewardFlow == address(0), 'Artifact rewardFlow already set');
        require(ISTT(honorAddr).rewardFlowFactory() == IRewardFlow(
            msg.sender).rfFactory(), 'Invalid rewardFlowFactory');
        require(IRewardFlowFactory(IRewardFlow(
            msg.sender).rfFactory()).getArtiToRF(address(this)) == msg.sender, 
        "RF/artifact pair don't match");

        rewardFlow = msg.sender;
        return rewardFlow;
    }

    function receiveDonation() external override returns(uint) {
        require(msg.sender == honorAddr, 'Only HONOR contract can donate');
        honorWithin += SafeMath.sub(ISTT(honorAddr).balanceOf(address(this)), 
            honorWithin);
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
        require(account != address(0), "Artifact: burn from zero");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "Artifact: burn exceeds bal");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }
}
