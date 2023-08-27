// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

// import "./Artifact.sol";
import "./SafeMath.sol";
import "./BudgetQueue.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/ISTT.sol";
import "../interfaces/IGeras.sol";
import "../interfaces/IRewardFlow.sol";
import "../interfaces/IRewardFlowFactory.sol";


// The virtual staked asset emits rewards that flow through the Artifact graph. 
// Each vouch claim has a certain amount of allocation power over the flow
// through each artifact. 
// One way to make the computation feasible would be to cap the number of 
// outbound flow slots, reserving the first for self-flow.
// However, the solution here is to do asynchronous flows triggered by 
// contract events, where the flows occur in round-robin fashion.


struct Allocation {
    address target;
    uint amount;
}

contract RewardFlowFactory is IRewardFlowFactory {
    mapping (address => address) artifactToRF;
    address private honorAddress;

    constructor(address honorAddr) {
        honorAddress = honorAddr;
        ISTT(honorAddr).setRewardFlowFactory();
    }

    function getArtiToRF(address artiOrRF) external override view returns(address) {
        return artifactToRF[artiOrRF];
    }


    function createRewardFlow(address artifactAddr_, address gerasAddr_) public returns(address) {
        require(artifactToRF[artifactAddr_] == address(0), 'RewardFlow for artifact exists');
        require(ISTT(honorAddress).balanceOf(artifactAddr_) != 0, 'Target artifact has no HONOR');

        artifactToRF[artifactAddr_] = address(new RewardFlow(artifactAddr_, gerasAddr_));
        require(artifactToRF[artifactToRF[artifactAddr_]] == address(0), 'Artifact for RewardFlow exists');
        artifactToRF[artifactToRF[artifactAddr_]] = artifactAddr_;

        IRewardFlow(artifactToRF[artifactAddr_]).setArtifact();
        return artifactToRF[artifactAddr_];
    }
}

contract RewardFlow is IRewardFlow {

    // Where are the incoming rewards coming from? These sum to the total flow. 
    // mapping (address => uint) incomeFlow;
    // Where do the incoming rewards flow? 
    // mapping (address => uint) budgetFlow;
    // Where is everybody voting for these rewards to flow? The aggregate value 
    // above will be calculated from a sum weighted (by vouch size) of individual submitted budgets. 
    // If not set, will default to status quo. 
    mapping (address => Allocation) allocations;
    mapping (address => uint) positions; 

    // mapping (address => mapping (address => uint)) flows;
    // uint32 constant public MAX_SLOT_SIZE = 16; 

    uint32 constant public FRACTION_TO_PASS = 4; 
    // uint32 constant public RATE_TO_ACCRUE = 100000;
    uint32 constant public MAX_ALLOCATION = 1024;

    // RewardFlow[] private slots; 
    // uint[] budget; 
    BudgetQueue private bq;
    // uint public min_flow;
    // uint32 public min_flow_index;
    address public artifactAddr;
    address public gerasAddr;
    address public stakedAssetAddr;
    address public rfFactory; 
    // address public honorAddr;
    uint public accumulatedPayout;
    uint public availableReward;
    uint public escrowedGeras;
    uint32 public _lastUpdated;


    constructor(address artifactAddr_, address gerasAddr_) {
        // require(IArtifact(artifactAddr).getBuilder() == msg.sender, 'Invalid RF builder');
        // require(IArtifact(artifactAddr).rewardFlow() == address(0));

        artifactAddr = artifactAddr_;
        gerasAddr = gerasAddr_;
        rfFactory = msg.sender;
        // stakedAssetAddr = stakedAssetAddr_;
        // Default is to keep all flow to this artifact.
        // budgetFlow[address(this)] = 1 << 32 - 1;
        _lastUpdated = uint32(block.timestamp);
        bq = new BudgetQueue(address(this));
    }

    function setArtifact() external override {
        IArtifact(artifactAddr).setRewardFlow();
    }

    // When called, dequeue the next item, calculate the amount to send, and transfer.
    // Formula is: (H_i/Sum_j(H) * accumulated / F)
    // where F is the constant above, resulting in exponential decay (1 - 1/(F H_i/Sum_j(H))) ^ T. 
    function payForward() external returns (address rewardedAddr, uint rewardAmt) {
        // uint addedGeras = ISTT(gerasAddr).balanceOf(this.address) - availableReward - escrowedGeras;
        receiveVSR();
        if (bq.isEmpty()) { return (address(this), 0);}
        address rewarderAddr = bq.peek();
        IArtifact artifact_ = IArtifact(artifactAddr);
        uint nextV = artifact_.balanceOf(rewarderAddr);

        if (nextV == 0 || allocations[rewarderAddr].amount == 0) {
            bq.dequeue();
            return (rewarderAddr, 0);
        }
        rewardedAddr = allocations[rewarderAddr].target; 
        uint alloc = allocations[rewarderAddr].amount;

        // uint32 timeElapsed = uint32(block.timestamp) - _lastUpdated;
        // uint amtToMove = SafeMath.max(availableReward, availableReward * timeElapsed / RATE_TO_ACCRUE);

        uint amtToMove = availableReward * nextV / (artifact_.totalSupply() * FRACTION_TO_PASS);
        rewardAmt = amtToMove * alloc / MAX_ALLOCATION;
        IGeras(gerasAddr).transfer(address(this), rewardedAddr, rewardAmt);
        availableReward -= amtToMove;
        accumulatedPayout += amtToMove * (MAX_ALLOCATION - alloc) / MAX_ALLOCATION;

        bq.requeue();
        if ((uint(block.timestamp) * amtToMove) % 2 == 1) {
            IRewardFlow(rewardedAddr).payForward();
        }

    }

    function receiveVSR() public returns (uint amtToReceive) {
        amtToReceive =  IGeras(gerasAddr).balanceOf(address(this)) - availableReward - escrowedGeras;
        availableReward += amtToReceive;
    }


    /** 
        * Redirect some amount of reward flow towards another artifact. 
        * This will create a new position for the sender, as well as entry within the budget queue.
        * The allocation will be interpreted as a fraction of the RF that the sender 
        * currently claims: which is derived from the vouch-time of that sender.
        * If an allocation already exists for this sender, it should be removed and replaced 
        * with this one. 
    */
    function submitAllocation(address targetAddr, uint allocAmt) external returns (uint queuePosition) {

        require(allocAmt <= MAX_ALLOCATION, 'Budget Allocation > 1024');
        require(IArtifact(artifactAddr).balanceOf(msg.sender) > 0, 'Sender has not vouched');
        require(address(this) != targetAddr, 'Artifact self-reward not allowed');
        require(IRewardFlowFactory(rfFactory).getArtiToRF(targetAddr) != address(0), 'RewardFlow not found');

        if (positions[msg.sender] > 0) {
            queuePosition = positions[msg.sender];
        }
        else {
            queuePosition = bq.getNextPos();
            bq.enqueue(msg.sender);
            positions[msg.sender] = queuePosition;
        }

        allocations[msg.sender] = Allocation(targetAddr, allocAmt);
        emit Allocate(msg.sender, targetAddr, allocAmt);
    }

    /** 
        * Direct a redemption request to the artifact for processing. 
        * This contract holds the available Geras for all claims, while the artifact
        * tracks how much each claimer is entitled to given their vouching time. 
        * Once the artifact checks that this claimer is due some amount,
        * the request will be finalized and transferred by the Geras contract (or denied).
    */
    function redeemReward(address claimer, uint redeemAmt) external returns (uint gerasAmt) {

        uint totalClaim = IArtifact(artifactAddr).redeemRewardClaim(claimer, redeemAmt);
        uint gerasAmt = IGeras(gerasAddr).balanceOf(address(this)) * redeemAmt / totalClaim;

        // This needs to convert into the actual asset and verify that the claimer is valid. 
        IGeras(gerasAddr).transfer(address(this), claimer, gerasAmt);

    }

}


