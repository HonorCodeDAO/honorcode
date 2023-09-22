pragma solidity ^0.8.13;

import "../interfaces/IArtifact.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IGeras.sol";
import "../interfaces/IRewardFlow.sol";
import "../interfaces/ISTT.sol";
import "./SafeMath.sol";


// Geras represents the "spoils" of HONOR. It is used to hold the staked asset,
// tracking the farmed HONOR claims for stakers, and disperse cash flow rewards
// to vouch holders across the various artifacts, including root. 
contract Geras is IGeras {
    mapping (address => uint) private _balances;
    mapping (address => uint) private _stakedAsset;
    mapping (address => uint) private _stakedAssetBalances;
    address public honorAddr;
    address public rootArtifact;
    address public stakedAssetAddr;
    uint public totalVirtualStakedAsset;
    uint public totalVirtualStakedReward;
    uint public redeemableReward;
    uint public claimableReward;

    // Percentage of 1024
    // uint public claimableConversionRate = 128;
    uint private _totalSupply;
    uint32 private _lastUpdated;

    mapping (address => uint) private _accHonorClaims;
    mapping (address => uint) private _lastUpdatedStake;


    constructor(address root, address hnrAddr, address stakedAssetAddress) {
        rootArtifact = root;
        honorAddr = hnrAddr;
        stakedAssetAddr = stakedAssetAddress;
        _lastUpdated = uint32(block.timestamp);
    }

    function updateHonorClaims(address account) private {
        require(totalVirtualStakedAsset >= _stakedAssetBalances[account], 
            'total staked < acct bal');
        _accHonorClaims[address(this)] += totalVirtualStakedAsset * (
            block.timestamp - _lastUpdatedStake[address(this)]);
        _accHonorClaims[account] += _stakedAssetBalances[account] * (
            block.timestamp - _lastUpdatedStake[msg.sender]);
        _lastUpdatedStake[account] = block.timestamp;
        _lastUpdatedStake[address(this)] = block.timestamp;
    }

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr]; 
    } 

    function stakeAsset(address stakeTarget) public override returns (uint) {
        require(stakeTarget == rootArtifact, 'Only stake with root artifact');
        uint totalStaked = IERC20(stakedAssetAddr).balanceOf(address(this));
        require(totalVirtualStakedAsset < totalStaked, 
            'No asset transferred to stake');

        uint amt = totalStaked - totalVirtualStakedAsset;
        if (_stakedAsset[stakeTarget] == 0) {_stakedAsset[stakeTarget] = amt;}
        else {_stakedAsset[stakeTarget] += amt;}
        
        updateHonorClaims(msg.sender);
        _stakedAssetBalances[msg.sender] += amt;
        totalVirtualStakedAsset += amt;

        emit Stake(msg.sender, stakeTarget, amt);
        return _stakedAsset[stakeTarget];
    }

    function getStakedAsset(address stakeTarget) external override view 
    returns (uint) {
        return _stakedAsset[stakeTarget];
    }

    function getHonorClaim(address acct) external override view returns (uint) {
        return _accHonorClaims[acct];
    }

    function getLastUpdated(address acct) external override view returns (uint){
        return _lastUpdatedStake[acct];
    }

    function mintHonorClaim(address account) external override returns (
        uint accVSASeconds, uint accVSASecondsTotal) {
        require(msg.sender == honorAddr, 'Only Honor contract can mint.');
        updateHonorClaims(account);
        accVSASeconds = _accHonorClaims[account];
        accVSASecondsTotal = _accHonorClaims[address(this)];
        accVSASeconds = SafeMath.min(accVSASeconds, accVSASecondsTotal);
        _accHonorClaims[address(this)] -= accVSASeconds;
        _accHonorClaims[account] = 0;
        _lastUpdatedStake[account] = block.timestamp;
    }

    function unstakeAsset(address stakeTarget, uint amount) public {
        require(stakeTarget == rootArtifact);
        require(amount <= _stakedAssetBalances[msg.sender]);
        require(amount <= _stakedAsset[stakeTarget]);
        updateHonorClaims(msg.sender);

        _stakedAsset[stakeTarget] -= amount;
        _stakedAssetBalances[msg.sender] -= amount;
        totalVirtualStakedAsset -= amount;
        IERC20(stakedAssetAddr).transfer(msg.sender, amount);
    }

    function distributeGeras(address rewardFlowAddr) public {
        // For now, only root artifact can generate Geras.
        require(IRewardFlow(rewardFlowAddr).artifactAddr() == rootArtifact, 
            'Only stake with root artifact');
        uint32 timeElapsed = uint32(block.timestamp) - _lastUpdated;

        uint newGeras = _stakedAsset[rootArtifact] * 32 / 1024;
        _lastUpdated = uint32(block.timestamp);
        _mint(rewardFlowAddr, timeElapsed * newGeras / 31536000); 
        // IRewardFlow(rewardFlowAddr).payForward();
    }

    // function distributeReward(uint amountToDistribute) public {
    //     // For now, only owner can distribute the staked asset for Geras.
    //     require(msg.sender == ISTT(honorAddr).owner(), 'Only owner can distributeReward');
    //     require(amountToDistribute <= IERC20(stakedAssetAddr).balanceOf(address(this)));
    //     claimableReward += amountToDistribute;
    //     // IRewardFlow(rewardFlowAddr).payForward();
    // }


    // function claimReward(uint amountToDistribute) public {
    //     // Burn some of the address's geras claims.
    //     // require(msg.sender == ISTT(honorAddr).owner(), 'Only owner can distributeReward');
    //     require(amountToDistribute <= IERC20(stakedAssetAddr).balanceOf(address(this)));
    //     claimableReward -= amountToDistribute;
    //     // IRewardFlow(rewardFlowAddr).payForward();
    // }

    function transfer(address sender, address recipient, uint256 amount) 
    public virtual {
        // require(sender != address(0), "GERAS: transfer from the zero address");
        // require(recipient != address(0), "GERAS: transfer to the zero address");
        require(IArtifact(IRewardFlow(sender).artifactAddr()).isValidated() && (
            IArtifact(IRewardFlow(recipient).artifactAddr()).isValidated()), 
            'Both sender and receiver require validation');

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "GERAS: tfer exceeds bal");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}
