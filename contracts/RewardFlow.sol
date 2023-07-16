// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

// import "./Artifact.sol";
import "./SafeMath.sol";
import "./BudgetQueue.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/IGeras.sol";
import "../interfaces/IRewardFlow.sol";


// The virtual staked asset emits rewards that flow through the Artifact graph. 
// Each vouch claim has a certain amount of allocation power over the flow
// through each artifact. However, the number of outbound flows is capped 
// to make the computation feasible. 
// The first slot is reserved for self-flow, but the rest can be allocated to 
// any other valid artifact. 


struct Allocation {
    address target;
    uint amount;
}


contract RewardFlowFactory {
    function createRewardFlow(address artifactAddr_, address gerasAddr_) public returns(RewardFlow) {
        return new RewardFlow(artifactAddr_, gerasAddr_);
    }
}

contract RewardFlow is IRewardFlow {
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
    // address public honorAddr;
    uint public accumulatedPayout;
    uint public availableReward;
    uint public escrowedGeras;
    uint32 public _lastUpdated;


    constructor(address artifactAddr_, address gerasAddr_) {
        // require(IArtifact(artifactAddr).getBuilder() == msg.sender, 'Invalid RF builder');
        artifactAddr = artifactAddr_;
        gerasAddr = gerasAddr_;
        // stakedAssetAddr = stakedAssetAddr_;
        // Default is to keep all flow to this artifact.
        // budgetFlow[address(this)] = 1 << 32 - 1;
        _lastUpdated = uint32(block.timestamp);
        bq = new BudgetQueue(address(this));
    }

    function getArtifact() external override view returns (address) {
        return artifactAddr;
    }

    // When called, dequeue the next item, calculate the amount to send, and transfer.
    // Formula is: (H_i/Sum_j(H) * accumulated / F)
    // where F is the constant above, resulting in exponential decay (1 - 1/(F H_i/Sum_j(H))) ^ T. 
    function payForward() external returns (address rewardedAddr, uint rewardAmt) {
        // uint addedGeras = ISTT(gerasAddr).balanceOf(this.address) - availableReward - escrowedGeras;
        receiveVSR();
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

    function submitAllocation(address targetAddr, uint allocAmt) external returns (uint queuePosition) {

        require(allocAmt <= MAX_ALLOCATION, "Budget Allocation > 1024");
        require(IArtifact(artifactAddr).balanceOf(msg.sender) > 0, 'Sender has not vouched');
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

        return queuePosition;

    }


    // function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    //     require(sender != address(0), "HONOR: transfer from the zero address");
    //     require(recipient != address(0), "HONOR: transfer to the zero address");

    //     uint256 senderBalance = _balances[sender];
    //     require(senderBalance >= amount, "HONOR: transfer amount exceeds balance");
    //     _balances[sender] = senderBalance - amount;
    //     _balances[recipient] += amount;

    //     emit Transfer(sender, recipient, amount);
    // }

}


