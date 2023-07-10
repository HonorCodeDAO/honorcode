// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./Artifactory.sol";
// import "./Geras.sol";
// import "./RewardFlow.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/ISTT.sol";
import "../interfaces/IGeras.sol";
import "../interfaces/IRewardFlow.sol";


// This contract represents base HONOR. It keeps the verified list of 
// artifacts, acts as a go-between during vouching/unvouching artifacts, 
// and manages the cash flow collection and resulting HONOR mints.

contract Honor is ISTT {
    mapping (address => uint) private _balances;
    mapping (address => uint) private _stakedAsset;
    mapping (address => uint) private _accStakingRewards;
    mapping (address => uint32) private _lastUpdated;
    // mapping (address => ArtifactData.data) artifacts;
    address public rootArtifact;
    address public stakedAssetAddr = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    address public gerasAddr;
    address public rewardFlow;
    uint private _totalSupply;
    uint constant VALIDATE_AMT = 1;
    // uint32 constant public INFLATION_PER_THOUSAND_PER_YEAR_STAKER = 500;
    // uint32 constant public INFLATION_PER_THOUSAND_PER_YEAR_VOUCHER = 500;
    uint32 constant public EXPECTED_REWARD_PER_YEAR_PER_THOUSAND_STAKED = 32;
    address public latestProposed;
    Artifactory afact;
    // RewardFlowFactory rfFact;
    // GerasFactory gFact;


    constructor() {
        afact = new Artifactory();
        // rfFact = new RewardFlowFactory();
        // gFact = new GerasFactory();
        // Artifact root = new Artifact(tx.origin, address(this), "rootArtifact");
        rootArtifact = address(afact.createArtifact(tx.origin, address(this), "rootArtifact"));
        // gerasAddr = address(gFact.createGeras(rootArtifact, address(this)));
        gerasAddr = address(new Geras(rootArtifact, address(this)));

        _mint(rootArtifact, 10000);
        // IArtifact(rootArtifact).vouch(tx.origin);
        require(_balances[rootArtifact] > 0, "root balance 0");
        IArtifact(rootArtifact).initVouch(msg.sender, 10000);
        _balances[rootArtifact] = 10000;
        IArtifact(rootArtifact).setRoot();
    }

    function initializeRF() external returns(address) {
        return rewardFlow;
    }

    function getStakedAssetAddress() public view returns(address) {
        return stakedAssetAddr; 
    }

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr]; 
    }

    function balanceOfArtifact(address addr, address account) public view returns(uint) {
        return IArtifact(addr).balanceOf(account);
    }

    function internalHonorBalanceOfArtifact(address addr) public view returns(uint) {
        return IArtifact(addr).getInternalHonor();
    }
    
    function getArtifactBuilder(address addr) public view returns(address) {
        return IArtifact(addr).getBuilder();
    }

    function getArtifactAccumulatedHonorHours(address addr) public view returns(uint) {
        return IArtifact(addr).accumulatedHonorHours();
    }

    function getRootArtifact() public view returns(address) {
        return rootArtifact; 
    }

    // function getArtifactRewardFlow(address addr) public view returns(address) {
    //     return IArtifact(addr).getRewardFlow(); 
    // }

    // function getNewRewardFlow(address stakedAssetAddr_, address artifactAddr_, address gerasAddr_) public returns(address) {
    //     return address(rfFact.createRewardFlow(stakedAssetAddr_, artifactAddr_, gerasAddr_)); 
    // }

    function getStakedAsset() external override view returns(address) {
        return stakedAssetAddr; 
    }

    function getGeras() external override view returns(address) {
        return gerasAddr; 
    }

    function updateStakingRewards(address addr) public returns (uint newRewards) { 
        newRewards = uint(block.timestamp - _lastUpdated[addr]) * _stakedAsset[addr];
        _accStakingRewards[addr] += newRewards; 
    }

    /* 
     * The presiding HONOR contract will manage housekeeping between the available artifacts. 
     * This includes checking whether the destination is validated, and overseeing the 
     * transfer of base HONOR. 
     */ 
    function vouch(address _from, address _to, uint amount) public returns(uint revouchAmt) {
        require(_balances[_to] != 0 && _balances[_from] != 0 && IArtifact(_to).isValidated(), 
            "Inval vouch");
        require(IArtifact(_from).balanceOf(tx.origin) >= amount, "Insuff. vouch bal");

        uint hnrAmt = IArtifact(_from).unvouch(tx.origin, amount);
        _transfer(_from, _to, hnrAmt);

        revouchAmt = IArtifact(_to).vouch(tx.origin); 

        emit Vouch(tx.origin, _from, _to, hnrAmt);
    }

    /* 
     * Propose adding a new artifact that refers to certain link or document. 
     */ 
    function proposeArtifact(address _from, address builder, string memory location) public returns(address proposedAddr) { 

        // Artifact newArtifact = new Artifact(builder, address(this), location); 
        // Artifact newArtifact = afact.createArtifact(builder, address(this), location);
        proposedAddr = address(afact.createArtifact(builder, address(this), location));

        require(IArtifact(_from).balanceOf(msg.sender) >= VALIDATE_AMT, "Insuff. proposer bal");

        uint hnrAmt = IArtifact(_from).unvouch(msg.sender, VALIDATE_AMT);
        _transfer(_from, proposedAddr, hnrAmt);
        IArtifact(proposedAddr).receiveDonation();
        latestProposed = proposedAddr;
    }

    /* 
     * After an artifact is proposed, it will need to be validated to be fully vouchable.
     * This process should involve some version of token curation but for now requires 
     * additional HONOR lockup. 
     */
    function validateArtifact(address _from, address addr) public returns(bool validated) { 
        if (IArtifact(addr).isValidated() && _balances[addr] > 0) {
            return true;
        }
        require(IArtifact(_from).balanceOf(msg.sender) >= VALIDATE_AMT, "Insuff. val bal");

        uint hnrAmt = IArtifact(_from).unvouch(msg.sender, VALIDATE_AMT);
        _transfer(_from, addr, hnrAmt);
        IArtifact(addr).receiveDonation();
        return IArtifact(_from).validate();
    }

    function _mint(address account, uint256 amount) internal virtual {
        // require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        // require(sender != address(0), "HONOR: tfer from zero");
        // require(recipient != address(0), "HONOR: tfer to zero");
        require(IArtifact(recipient).isValidated());

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "HONOR: tfer exceeds bal");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }
}

contract Geras is IGeras {
    mapping (address => uint) private _balances;
    mapping (address => uint) private _stakedAsset;
    mapping (address => uint) private _stakedAssetBalances;
    // mapping (address => ArtifactData.data) artifacts;
    address public honorAddr;
    address public rootArtifact;
    address public stakedAssetAddr = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    uint public totalVirtualStakedAsset;
    uint public totalVirtualStakedReward;
    uint private _totalSupply;
    uint32 private _lastUpdated;

    uint32 constant public STAKED_ASSET_CONVERSION = 1;
    uint32 constant public EXPECTED_REWARD_PER_YEAR_PER_THOUSAND_STAKED = 32;
    // uint32 constant public STAKED_ASSET_CONVERSION = 1;


    // event Vouch(address _account, address indexed _from, address indexed _to, uint256 _value);
    // event Stake(address _account, address indexed _to, uint256 _value);

    constructor(address root, address hnrAddr) {
        rootArtifact = root;
        honorAddr = hnrAddr;
        _lastUpdated = uint32(block.timestamp);
    }

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr]; 
    } 

    function stakeAsset(address stakeTarget, uint amt) public override returns (uint) {
        require(stakeTarget == rootArtifact, 'Only stake with root artifact');
        // uint totalStaked = IERC20(stakedAssetAddr).balanceOf(address(this));
        // require(totalVirtualStakedAsset < totalStaked);

        // _stakedAsset[stakeTarget] += totalStaked - totalVirtualStakedAsset;
        if (_stakedAsset[stakeTarget] == 0) {_stakedAsset[stakeTarget] = amt;}
        else {_stakedAsset[stakeTarget] += amt;}
        
        _stakedAssetBalances[msg.sender] += amt;
        // _stakedAssetBalances[msg.sender] += totalStaked - totalVirtualStakedAsset;
        totalVirtualStakedAsset += amt;
        emit Stake(msg.sender, stakeTarget, amt);
        return _stakedAsset[stakeTarget];
    }

    function getStakedAsset(address stakeTarget) external view returns (uint) {
        return totalVirtualStakedAsset;//_stakedAsset[stakeTarget];
    }

    function unstakeAsset(address stakeTarget, uint amount) public {
        require(stakeTarget == rootArtifact);
        require(amount <= _stakedAssetBalances[msg.sender]);
        require(amount <= _stakedAsset[stakeTarget]);
        _stakedAsset[stakeTarget] -= amount;
        _stakedAssetBalances[msg.sender] -= amount;
        totalVirtualStakedAsset -= amount;
        IERC20(stakedAssetAddr).transfer(msg.sender, amount);
    }

    function distributeReward(address rewardFlowAddr) public {
        // For now, only root artifact can generate Geras.
        require(IRewardFlow(rewardFlowAddr).getArtifact() == rootArtifact, 'Only stake with root artifact');
        uint32 timeElapsed = uint32(block.timestamp) - _lastUpdated;

        uint newGeras = _stakedAsset[rootArtifact] * EXPECTED_REWARD_PER_YEAR_PER_THOUSAND_STAKED / 1024;
        _lastUpdated = uint32(block.timestamp);
        _mint(rewardFlowAddr, timeElapsed * newGeras / 31536000); 
        // IRewardFlow(rewardFlowAddr).payForward();
    }

    function transfer(address sender, address recipient, uint256 amount) public virtual {
        // require(sender != address(0), "GERAS: transfer from the zero address");
        // require(recipient != address(0), "GERAS: transfer to the zero address");
        require(IArtifact(IRewardFlow(sender).getArtifact()).isValidated());
        require(IArtifact(IRewardFlow(recipient).getArtifact()).isValidated());

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
