pragma solidity ^0.8.13;

import "../interfaces/IArtifact.sol";
import "../interfaces/IWStETH.sol";
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
    uint private _totalSupply;
    uint private _totalVSASupply;
    uint32 private _lastUpdated;

    mapping (address => uint) private _accHonorClaims;
    mapping (address => uint) private _lastUpdatedStake;
    mapping (address => uint) private _vsaBalances;
    mapping (address => uint) private _stakedAsset;
    mapping (address => uint) private _balances;
    mapping (address => address) private _artifactToRF;


    constructor(address hnrAddr, address _stakedAssetAddr) {
        rootArtifact = ISTT(hnrAddr).rootArtifact();
        honorAddr = hnrAddr;
        stakedAssetAddr = _stakedAssetAddr;
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
    function donateAsset(address stakeTarget) external {
        require(stakeTarget == rootArtifact, 'Only donate to root artifact');
        require(totalShares < IWStETH(stakedAssetAddr).balanceOf(address(this)), 
            'No asset transferred to donate'); 
        totalShares = IWStETH(stakedAssetAddr).balanceOf(address(this));
        distributeGeras(stakeTarget);
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
        require(IWStETH(stakedAssetAddr).balanceOf(address(this)) > totalShares,
            'No asset transferred to stake'); 
        // uint amt = IWStETH(stakedAssetAddr).getStETHByWstETH(
        //     IWStETH(stakedAssetAddr).balanceOf(address(this)) - totalShares);

        updateHonorClaims(msg.sender);
        uint amt = ((IWStETH(stakedAssetAddr).balanceOf(
            address(this)) - totalShares) * stakedToVsaRate) >> 60;

        _stakedAsset[stakeTarget] += amt;
        
        // _balances[msg.sender] += amt;
        // _totalSupply = _totalSupply + amt;
        _mint(msg.sender, amt);
        totalShares += amt;

        emit Stake(msg.sender, stakeTarget, amt);
        return _stakedAsset[stakeTarget];
    }

    function unstakeAsset(address stakeTarget, uint amount) public {
        require(stakeTarget == rootArtifact);
        require(amount <= _balances[msg.sender]);
        require(amount <= _stakedAsset[stakeTarget]);
        updateHonorClaims(msg.sender);

        _stakedAsset[stakeTarget] -= amount;
        _burn(msg.sender, amount);
        totalShares -= amount;
        // IWStETH(stakedAssetAddr).transfer(msg.sender, 
        //     IWStETH(stakedAssetAddr).getWstETHByStETH(amount));

        IWStETH(stakedAssetAddr).transfer(msg.sender, 
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

    function distributeGeras(address rewardFlowAddr) public {
        // For now, only root artifact can generate Geras.
        require(IRewardFlow(rewardFlowAddr).artifactAddr() == rootArtifact, 
            'Only stake with root artifact');

        updateHonorClaims(address(this));
        if (((_stakedAsset[rootArtifact] * stakedToVsaRate) >> 60) <= (
            _totalSupply + _totalVSASupply)) {
                return;
        }

        // Assume new Geras accumulates at a rate of ~3% per year per unit VSA.
        // The stakedToVsaRate tells us the target VSA amount, based on current
        // actual staked asset. This op mints enough new VSA to close the gap. 
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
        require(claimableReward + amountToDistribute <= IWStETH(
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
        require(gerasClaim <= _vsaBalances[msg.sender], 'Geras claim exceeds bal');
        vsrClaim = gerasClaim * claimableConversionRate / 1024;

        require(vsrClaim <= claimableReward, 'Claim reward exceeds claimable');
        require(vsrClaim <= IWStETH(stakedAssetAddr).balanceOf(address(this)), 
            'Insufficient VSA to claim reward');

        claimableReward -= vsrClaim;
        _vsaBurn(msg.sender, gerasClaim);
        IWStETH(stakedAssetAddr).transfer(claimer, vsrClaim);
    }

    function vsaTransfer(address sender, address recipient, uint256 amount) 
    public virtual {
        require(IArtifact(IRewardFlow(sender).artifactAddr()).isValidated() && (
            IArtifact(IRewardFlow(recipient).artifactAddr()).isValidated()), 
            'Both sender and receiver require validation');

        uint256 senderBalance = _vsaBalances[sender];
        require(senderBalance >= amount, "GERAS: vsa tfer exceeds bal");
        _vsaBalances[sender] = senderBalance - amount;
        _vsaBalances[recipient] += amount;
        emit VSATransfer(sender, recipient, amount);
    }


    function transfer(address sender, address recipient, uint256 amount) 
    public virtual {
        require(sender != address(0), "GERAS: transfer from the zero address");
        require(recipient != address(0), "GERAS: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "GERAS: tfer exceeds bal");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
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
    
}
