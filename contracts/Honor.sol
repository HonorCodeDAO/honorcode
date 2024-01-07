pragma solidity ^0.8.13;

import "../interfaces/IArtifactory.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IGeras.sol";
import "../interfaces/IRewardFlow.sol";
import "../interfaces/ISTT.sol";
import "./SafeMath.sol";


// This contract represents base HONOR. It keeps the verified list of 
// artifacts, acts as a go-between during vouching/unvouching artifacts, 
// and manages the cash flow collection and resulting HONOR mints.

contract Honor is ISTT {
    uint private _totalSupply;
    uint private _stakingMintPool;
    mapping (address => uint) private _balances;
    uint private _lastUpdated;
    address public rootArtifact;
    // Geras represents a virtual staked asset.
    address public gerasAddr;
    address public rewardFlowFactory;
    address public owner;
    uint constant VALIDATE_AMT = 1e18;
    address public artifactoryAddr;
    string public name; 


    constructor(
        address artifactoryAddress, 
        string memory honorName) {
        artifactoryAddr = artifactoryAddress;
        rootArtifact = (IArtifactory(artifactoryAddr).createArtifact(
            msg.sender, address(this), "rootArtifact"));

        _mint(rootArtifact, 10000e18);
        IArtifact(rootArtifact).initVouch(msg.sender, 10000e18);

        IArtifact(rootArtifact).validate();
        _lastUpdated = block.timestamp;
        owner = msg.sender;
        name = honorName;
    }

    function setOwner(address newOwner) external override {
        require(owner == msg.sender, 'Only owner can change owner');
        owner = newOwner;
    }

    function setRewardFlowFactory(address rfFactory) external override {
        // Disable this requirement in case we need to replace it. 
        // require(rewardFlowFactory == address(0), 'RF factory already set');
        require(msg.sender == owner, 'Only owner can modify RewardFlowFactory');
        rewardFlowFactory = rfFactory;
    }

    function setGeras(address gerasAddress) external override {
        require(gerasAddr == address(0), 'Geras already set');
        require(msg.sender == owner, 'Only owner modifies Geras');
        gerasAddr = gerasAddress;
    }

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr]; 
    }

    function balanceOfArtifact(address addr, address account) 
    public view returns(uint) {
        return IArtifact(addr).balanceOf(account);
    }

    function internalHonorBalanceOfArtifact(address addr) 
    public view returns(uint) {
        return IArtifact(addr).honorWithin();
    }
    
    function getArtifactBuilder(address addr) public view returns(address) {
        return IArtifact(addr).builder();
    }

    function getArtifactAccumulatedHonorHours(address addr) 
    public view returns(uint) {
        return IArtifact(addr).accHonorHours();
    }

    /* 
     * The presiding HONOR contract will manage housekeeping between the available artifacts. 
     * This includes checking whether the destination is validated, and overseeing the 
     * transfer of base HONOR. 
     */ 
    function vouch(address _from, address _to, uint amount) external override 
    returns(uint revouchAmt) {
        require(IArtifact(_from).honorAddr() == address(this), 
            'HONOR: artifact doesnt exist');
        require(_balances[_to] != 0 && _balances[_from] != 0 && (
            IArtifact(_to).isValidated()), "HONOR: Invalid vouch");
        require(IArtifact(_from).balanceOf(msg.sender) >= amount, 
            "HONOR: Insuff. vouch bal");

        uint hnrAmt = IArtifact(_from).unvouch(msg.sender, amount, false);
        _transfer(_from, _to, hnrAmt);

        revouchAmt = IArtifact(_to).vouch(msg.sender); 

        emit Vouch(msg.sender, _from, _to, hnrAmt);
    }

    /* 
     * Propose adding a new artifact that refers to certain link or document. 
     */ 
    function proposeArtifact(address _from, address builder, string memory loc, 
        bool should_validate) 
    external override returns(address proposedAddr) { 
        // We'll check if sender has a positive balance but will still fail below if insufficient
        require(IArtifact(_from).balanceOf(msg.sender) > 0, 
            "Insuff. proposer/source bal");
        proposedAddr = (IArtifactory(artifactoryAddr).createArtifact(
            builder, address(this), loc));

        IArtifact(_from).unvouch(msg.sender, VALIDATE_AMT, true);

        _transfer(_from, proposedAddr, VALIDATE_AMT);
        IArtifact(proposedAddr).initVouch(msg.sender, VALIDATE_AMT);
        emit Vouch(msg.sender, _from, proposedAddr, VALIDATE_AMT);

        // Most of the time, we would expect a two-stage propose/validate process,
        // but allow this for convenience.
        if (should_validate) { IArtifact(proposedAddr).validate(); }
    }

    /* 
     * After an artifact is proposed, it will need to be validated to be fully 
     * vouchable. This process should involve some version of token curation but 
     * for now requires additional HONOR commitment. 
     * The main difference between validated and unvalidated artifacts is 
     * the builder does not accumulate claims for the former. 
     */
    function validateArtifact(address _from, address addr) 
    external override returns(bool validated) { 
        if (IArtifact(addr).isValidated() && _balances[addr] > 0) {return true;}
        require(IArtifact(_from).balanceOf(msg.sender) >= VALIDATE_AMT, 
            "Insuff. val bal");

        uint hnrAmt = IArtifact(_from).unvouch(msg.sender, VALIDATE_AMT, true);
        _transfer(_from, addr, hnrAmt);
        IArtifact(addr).vouch(msg.sender); 
        emit Vouch(msg.sender, _from, addr, VALIDATE_AMT);
        return IArtifact(addr).validate();
    }

    /*
     *  We compute the rate at which HONOR is farmed out from a square root of 
     *  the total amount of VSA staked. The pivot point where the annual rate
     *  equals staked asset is 2^70 (~1000 ETH). Which means we multiply the 
     *  square root by 2^35.
    */
    function mintToStakers() public returns(uint farmedHonor) {
        uint stakeAmt = SafeMath.floorSqrt(
            IGeras(gerasAddr).totalVirtualStakedAsset()) << 35;
        // Will be minted at an annual rate.
        farmedHonor = ((block.timestamp - _lastUpdated) * stakeAmt) / 31536000;
        _lastUpdated = block.timestamp;
        _stakingMintPool += farmedHonor;
    }

    function mintToStaker() public returns(uint farmedHonor) {
        uint totalFarmedHonor;
        (farmedHonor, totalFarmedHonor) = IGeras(gerasAddr).mintHonorClaim(
            msg.sender);
        require(totalFarmedHonor >= farmedHonor && farmedHonor > 0, 
            'No farmed Honor available');
        uint hnrToMint = farmedHonor * _stakingMintPool / totalFarmedHonor;
        _stakingMintPool -= hnrToMint;
        _mint(rootArtifact, hnrToMint);
        IArtifact(rootArtifact).vouch(msg.sender);
    }

    function stakingMintPool() external override view returns (uint) {
        return _stakingMintPool;
    }


    function _mint(address account, uint256 amount) internal virtual {
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    /*
     *  We define semi-transferability as only allowing transfers internally, 
     *  which can only happen when proposing or vouching artifacts. 
    */
    function _transfer(address sender, address recipient, uint256 amount) 
    internal virtual {
        // require(IArtifact(recipient).isValidated(), 'recipient not validated');

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "HONOR: transfer exceeds bal");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }
}

