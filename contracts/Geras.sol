// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IArtifact.sol";
import "../interfaces/IGeras.sol";
import "../interfaces/IRewardFlow.sol";
import "../interfaces/IRewardFlowFactory.sol";
import "../interfaces/ISTT.sol";
import "./SafeMath.sol";


/**
 * Geras represents the "spoils" of HONOR: in this case, a virtual staked asset. 
 * It is used to hold a staked asset, track the farmed HONOR claims for stakers, 
 * and disperse cash flow rewards to vouchers across the various artifacts.
 * For the sake of convenience, we want this contract to be the manager for 
 * RF-related functions, allowing us to use artifact addresses instead of RFs.
 * In this way, Geras : RewardFlow :: Honor : Artifact.
 */ 

contract GerasFactory {
    constructor() {
    }

    function createGeras(address hnrAddr, address stakedAssetAddr,
        string memory name) public returns (address) {
        return address(new Geras(hnrAddr, stakedAssetAddr, name));
    }

}


contract Geras is IGeras {
    address public honorAddr;
    address public rootArtifact;
    address public stakedAssetAddr;
    address public rewardFlowFactory;
    uint public totalShares;
    uint public redeemableReward;
    uint public claimableReward;

    // Percentage of 1024
    uint public claimableConversionRate = 1024;
    // This will decrease at a rate 32 / 1024 per year.
    uint public stakedToVsaRate = 2 ** 60;
    uint public lastDistRate = 2 ** 60;
    string public name; 

    uint private _totalSupply;
    uint private _totalVSASupply;
    uint32 private _lastUpdated;

    mapping (address => uint) private _accHonorClaims;
    mapping (address => uint) private _lastUpdatedStake;
    mapping (address => uint) private _vsaBalances;
    mapping (address => uint) private _stakedAsset;
    mapping (address => address) private _artifactToRF;
    mapping (address => uint) private _balances;
    mapping (address => mapping(address => uint256)) private _allowances;

    constructor(address hnrAddr, address _stakedAssetAdr, string memory _name) {
        rootArtifact = ISTT(hnrAddr).rootArtifact();
        honorAddr = hnrAddr;
        name = _name;
        stakedAssetAddr = _stakedAssetAdr;
        _lastUpdated = uint32(block.timestamp);
        _lastUpdatedStake[address(this)] = block.timestamp;
    }

    function updateHonorClaims(address account) private {
        require(_totalSupply >= _balances[account], 
            'total staked < acct bal');
        if (block.timestamp > _lastUpdatedStake[address(this)]) {
            stakedToVsaRate += (block.timestamp - _lastUpdatedStake[address(this)]) << 30;
            _accHonorClaims[address(this)] += _totalSupply * (
                block.timestamp - _lastUpdatedStake[address(this)]);
            _lastUpdatedStake[address(this)] = block.timestamp;
        }
        if (account == address(this)) { return; }
        if ((_lastUpdatedStake[account] == 0) || (_balances[account] == 0)) {
            _lastUpdatedStake[account] = block.timestamp;
            return;
        }
        _accHonorClaims[account] += _balances[account] * (
            block.timestamp - _lastUpdatedStake[msg.sender]);
        _lastUpdatedStake[account] = block.timestamp;
    }

    function vsaBalanceOf(address addr) public view returns(uint) {
        return _vsaBalances[addr]; 
    } 

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr]; 
    } 

    function setRewardFlowFactory(address rfFactory) external {
        require(rewardFlowFactory == address(0), 'RF factory already set');
        require(msg.sender == ISTT(honorAddr).owner(), 
            'Only owner can modify RewardFlowFactory');
        rewardFlowFactory = rfFactory;
    }

    /** 
     *  Wrapper for the RFFactory getArtiToRF function. 
     */
    function getArtifactToRewardFlow(address artOrRF) external override view
    returns (address) {
        return IRewardFlowFactory(rewardFlowFactory).getArtiToRF(artOrRF);
    }

    /** 
     *  Wrapper for the RFFactory createRewardFlow function. 
     */
    function createRewardFlow(address artifactAddr) external override 
    returns(address) {
        require(_artifactToRF[artifactAddr] == address(0), 
            'RewardFlow for artifact exists');
        _artifactToRF[artifactAddr] = IRewardFlowFactory(rewardFlowFactory).
        createRewardFlow(honorAddr, artifactAddr, address(this));
        require(_artifactToRF[_artifactToRF[artifactAddr]] == address(0), 
            'Artifact for RewardFlow exists');
        _artifactToRF[_artifactToRF[artifactAddr]] = artifactAddr;

        return _artifactToRF[artifactAddr];
    }

    /** 
     *  Wrapper for the RF payForward function. 
     */
    function payForward(address artifactToPay) external override returns (
        address target, uint amtToReceive) {
        require(_artifactToRF[artifactToPay] != address(0), 
            'RewardFlow does not exist');
        (target, amtToReceive) = IRewardFlow(
            _artifactToRF[artifactToPay]).payForward();
    }
    
    /** 
     *  Wrapper for the RF submitAllocation function. 
     */
    function submitAllocation(address artToAlloc, address targetAddr, 
        uint8 allocAmt) external override returns (uint queuePosition) {
        require((_artifactToRF[artToAlloc] != address(0)) && (
            _artifactToRF[targetAddr] != address(0)), 'RewardFlow not set');
        queuePosition = IRewardFlow(_artifactToRF[artToAlloc]).submitAllocation(
                _artifactToRF[targetAddr], allocAmt, msg.sender);
    }

    /** 
     *  Wrapper for the RF redeemReward function. 
     */
    function redeemReward(address artifactToRedeem, address claimer, 
        uint redeemAmt) external returns (uint) {
        require(_artifactToRF[artifactToRedeem] != address(0), 
            'RewardFlow does not exist');
        return IRewardFlow(_artifactToRF[artifactToRedeem]).redeemReward(
            claimer, redeemAmt);
    }

    // We may want to allow cash infusions without claims, and calling this 
    // function prevents others from claiming a new staking position.
    function donateAsset(address donateTarget) external {
        require(donateTarget == rootArtifact, 'Only donate to root artifact');
        require(totalShares < IERC20(stakedAssetAddr).balanceOf(address(this)), 
            'No asset transferred to donate'); 
        totalShares = IERC20(stakedAssetAddr).balanceOf(address(this));
        distributeGeras(donateTarget);
    }


    /**
     *  The wrapped asset will be passed into this contract in terms of shares.
     *  However, all accounting will be done in terms of the underlying staked 
     *  asset, stETH in this case. When a stake is removed, they will receive
     *  fewer shares, but the same amount of stETH, as intended.
     *  We need to keep track of both, because otherwise we won't know how much
     *  is transferred as opposed to accrued through rebasing.
     *  In addition, we have new Geras entering the system at a rate = 32/1024
     *  per year, which then becomes claimable VSA by vouchers.
     *  Thus, stakers will need to have their shares debased at this same rate 
     *  so there is enough to be claimed by everybody. 
     */
    function stakeAsset(address stakeTarget) external override returns (uint) {
        require(stakeTarget == rootArtifact, 'Only stake with root artifact');
        require(IERC20(stakedAssetAddr).balanceOf(address(this)) > totalShares,
            'GERAS: No asset transferred to stake'); 

        updateHonorClaims(msg.sender);
        ISTT(honorAddr).mintToStakers();
        uint amt = ((IERC20(stakedAssetAddr).balanceOf(
            address(this)) - totalShares) * stakedToVsaRate) >> 60;

        _stakedAsset[stakeTarget] += amt;
        
        // _balances[msg.sender] += amt;
        // _totalSupply = _totalSupply + amt;
        _mint(msg.sender, amt);
        totalShares += amt;

        emit Stake(msg.sender, stakeTarget, amt);
        return amt;
    }

    function unstakeAsset(address stakeTarget, uint amount) public {
        require(stakeTarget == rootArtifact, 'Only stake with root artifact');
        require((amount <= _balances[msg.sender]) && (
            amount <= _stakedAsset[stakeTarget]),
            'GERAS: No asset available to unstake');
        updateHonorClaims(msg.sender);
        ISTT(honorAddr).mintToStakers();

        _stakedAsset[stakeTarget] -= amount;
        _burn(msg.sender, amount);
        totalShares -= amount;

        IERC20(stakedAssetAddr).transfer(msg.sender, 
            (amount << 60) / stakedToVsaRate);
        emit Unstake(msg.sender, stakeTarget, amount);
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

    function lastUpdated() external override view returns (uint){
        return _lastUpdated;
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

    // Assume new Geras accumulates at a rate of ~3% per year per unit VSA.
    // The stakedToVsaRate tells us the target VSA amount, based on current
    // actual staked asset. This op mints enough new VSA to close the gap. 
    function distributeGeras(address rewardFlowAddr) public {
        // For now, only root artifact can generate Geras.
        require(IRewardFlow(rewardFlowAddr).artifactAddr() == rootArtifact, 
            'Only stake with root artifact');

        updateHonorClaims(address(this));
        if (((_stakedAsset[rootArtifact] * stakedToVsaRate) >> 60) <= (
            _totalSupply + _totalVSASupply)) {
                return;
        }

        _vsaMint(rewardFlowAddr, ((_stakedAsset[rootArtifact] * stakedToVsaRate) 
            >> 60) - (_totalSupply + _totalVSASupply));
        IRewardFlow(rewardFlowAddr).receiveVSR();

        // We should probably do this, at least once...
        // IRewardFlow(rewardFlowAddr).payForward();
    }

    /* 
        The owner decides how much of the staked asset rewards to distribute,
        with the understanding it doesn't exceed existing claims on the 
        staked asset.
    */
    function distributeReward(uint amountToDistribute, uint rate) public {
        // For now, only owner can distribute the staked asset for Geras.
        require(msg.sender == ISTT(honorAddr).owner(), 
            'Only owner can distributeReward');
        require(claimableReward + amountToDistribute <= IERC20(
            stakedAssetAddr).balanceOf(address(this)) - _totalSupply,
            'Geras: payout xceeds VSA rewards'
        );
        claimableReward += amountToDistribute;
        claimableConversionRate = rate;
        // IRewardFlow(rewardFlowAddr).payForward();
    }

    /*
        Each RewardFlow instance has some Geras claim, and it can interact with
        this contract to convert the claim into rewards from the staked-asset.  
        Since we don't know exactly when the Geras was received, we'll have to 
        treat it all equally and convertable at the current rate.
        We assume that the RewardFlow address who makes this request has already
        verified the claimer deserves the amount. 
    */
    function claimReward(uint gerasClaim, address claimer) public 
    returns (uint vsrClaim) {
        // Burn some of the address's geras claims.
        require(gerasClaim <= _vsaBalances[msg.sender], 
            'GERAS: claim exceeds bal');
        vsrClaim = gerasClaim * claimableConversionRate / 1024;

        require(vsrClaim <= claimableReward, 'Claim reward exceeds claimable');
        require(vsrClaim <= IERC20(stakedAssetAddr).balanceOf(address(this)), 
            'GERAS: Insuff. VSA to claim reward');

        claimableReward -= vsrClaim;
        _vsaBurn(msg.sender, gerasClaim);
        IERC20(stakedAssetAddr).transfer(claimer, vsrClaim);
    }

    function vsaTransfer(address recipient, uint256 amount) 
    public virtual returns (bool) {
        require(IArtifact(IRewardFlow(msg.sender).artifactAddr()).isValidated() && (
            IArtifact(IRewardFlow(recipient).artifactAddr()).isValidated()), 
            'GERAS: sender/receiver require validation');

        uint256 senderBalance = _vsaBalances[msg.sender];
        require(senderBalance >= amount, "GERAS: vsa tfer exceeds bal");
        _vsaBalances[msg.sender] = senderBalance - amount;
        _vsaBalances[recipient] += amount;
        emit VSATransfer(msg.sender, recipient, amount);
        return (true);
    }


    function transfer(address recipient, uint256 amount) 
    public virtual returns (bool) {
        require(recipient != address(0), "GERAS: transfer to the zero address");
        require(_balances[msg.sender] >= amount, "GERAS: tfer exceeds bal");
        updateHonorClaims(msg.sender);
        updateHonorClaims(recipient);

        _balances[msg.sender] = _balances[msg.sender] - amount;
        _balances[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return (true);
    }

    function _vsaMint(address account, uint256 amount) internal virtual {
        _totalVSASupply += amount;
        _vsaBalances[account] += amount;
        emit VSATransfer(address(0), account, amount);
    }

    function _vsaBurn(address account, uint256 amount) internal virtual {
        require(account != address(0), "Geras: burn from zero");

        uint256 accountBalance = _vsaBalances[account];
        require(accountBalance >= amount, "Geras: vsa burn exceeds bal");
        _vsaBalances[account] = accountBalance - amount;
        _totalVSASupply -= amount;

        emit VSATransfer(account, address(0), amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "Geras: burn from zero");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "Geras: burn exceeds bal");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }

    function totalVSASupply() external override view returns (uint256) {
        return _totalVSASupply;
    }

    // These are placeholder functions to match ERC20.
    function transferFrom(address sender, address recipient, uint256 amount) public override virtual returns (bool) {
        return false;
    }

    function allowance(address owner, address spender) external override view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount, true);
        return true;
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        require((owner != address(0)) || (spender == address(0)), 
            "GERAS: Approval for 0 address");
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }
}
