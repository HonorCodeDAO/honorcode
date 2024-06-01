// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BQueue.sol";
import "./SafeMath.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/IGeras.sol";
import "../interfaces/ISTT.sol";
import "../interfaces/IRewardFlow.sol";
import "../interfaces/IRewardFlowFactory.sol";

/** 
    * The virtual staked asset emits rewards that flow through the Artifact graph. 
    * Each vouch claim has a certain amount of allocation power over the flow
    * through each artifact. 
    * One way to make the computation feasible would be to cap the number of 
    * outbound flow slots, reserving the first for self-flow.
    * However, the solution here is to do asynchronous flows triggered by 
    * contract events, where the flows occur in round-robin fashion.
    * Default is to keep all flow to the corresponding artifact.
*/
struct Allocation {
    address target;
    uint8 amount;
}

contract RewardFlowFactory is IRewardFlowFactory {
    mapping (address => address) artifactToRF;

    constructor() {
    }

    function getArtiToRF(address artiOrRF) external override view 
    returns(address) {
        return artifactToRF[artiOrRF];
    }

    function createRewardFlow(address honorAddr, address artifactAddr_, 
        address gerasAddr_) external override returns(address) {
        require(ISTT(honorAddr).balanceOf(artifactAddr_) != 0, 
            'Target artifact has no HONOR');
        require(IArtifact(artifactAddr_).honorAddr() == honorAddr, 
            'Artifact does not match HONOR');

        artifactToRF[artifactAddr_] = address(new RewardFlow(
            artifactAddr_, gerasAddr_));
        artifactToRF[artifactToRF[artifactAddr_]] = artifactAddr_;

        IRewardFlow(artifactToRF[artifactAddr_]).setArtifact();
        return artifactToRF[artifactAddr_];
    }
}

contract RewardFlow is IRewardFlow {
/** 
    * Where is everybody voting for these rewards to flow? The aggregate value 
    * above will be calculated from a sum weighted (by vouch size) of 
    * individual submitted budgets. 
    * If not set, will default to status quo. 
    * We can allow individuals to maintain their own partial allocations,
    * and if their 'budgets' entry is non-existent, assume the allocation is 
    * the full amount.  
    * NOTE: we have disabled the partial allocation procedure for now, to limit
    * complexity. 
    * However, payments occur according to a round-robin budget queue, and size
    * of grant depends on Honor holdings in that corresponding artifact. 
*/ 
    mapping (address => Allocation) allocations;
    mapping (address => uint) positions; 
    // mapping (address => BudgetQ) budgets;

    uint8 constant public FRACTION_TO_PASS = 4; 
    // uint32 constant public RATE_TO_ACCRUE = 100000;
    uint8 constant public MAX_ALLOC = 255;

    BudgetQ private bq;
    uint32 private _lastUpdated;
    address public artifactAddr;
    address public gerasAddr;
    address public rfFactory; 
    uint public accumulatedPayout;
    uint public availableReward;
    uint public totalGeras;
    bool public isRoot;
    bool public activeOnly;


    constructor(address artifactAddr_, address gerasAddr_) {
        require(IArtifact(artifactAddr_).rewardFlow() == address(0), 
            'RewardFlow exists for artifact');

        artifactAddr = artifactAddr_;
        gerasAddr = gerasAddr_;
        rfFactory = msg.sender;
        if (artifactAddr == ISTT(IArtifact(artifactAddr).honorAddr()).rootArtifact()) {
            isRoot = true;
        }
        // Default is to only allow rewards to flow to active (non-owner) members
        activeOnly = false;
        // Default is to keep all flow to this artifact.
        _lastUpdated = uint32(block.timestamp);
        BQueue.incrementFirst(bq);
        // We need a default entry to avoid a single allocator draining the pool
        allocations[address(this)] = Allocation(address(this), 255);

        positions[address(this)] = BQueue.getNextPos(bq);
        BQueue.enqueue(bq, address(this));
        emit Allocate(address(this), address(this), 255);
    }

    function setArtifact() external override {
        IArtifact(artifactAddr).setRewardFlow();
    }

    function setNonOwnerActive(bool active) external {
        require ((msg.sender == IArtifact(artifactAddr).builder()) ||
            (msg.sender == ISTT(IArtifact(artifactAddr).honorAddr()).owner()),
                'Only owner or builder can change activeOnly');
        activeOnly = active;
    }

    // Add some to the amount available to be paid out to others. The remainder
    // will stay in this rewardflow. 
    function receiveVSR() public override returns (uint amtToReceive) {
        require(IGeras(gerasAddr).vsaBalanceOf(address(this)) >= totalGeras,
            'Total Geras less than balance');
        amtToReceive = IGeras(gerasAddr).vsaBalanceOf(address(this)) - totalGeras;
        totalGeras += amtToReceive;
        availableReward += amtToReceive;
    }

    /** 
        * Dequeue the next item, calculate the amount to send, and transfer.
        * Formula is: (H_i/Sum_j(H) * accumulated / F)
        * where F is the constant FRACTION_TO_PASS, giving exponential decay:
        * (1 - 1/(F H_i/Sum_j(H))) ^ T. 
        * Additionally, we'll have the default allocation keep half to itself,
        * to lessen a repetitive drainage attack.
        * This function activates a recursive call, depth depends on "random"
        * transitions, with 1/3 chance of paying forward the target.
        * For optimal process, recommended to 1st distribute Geras if root RF. 
    */
    function payForward() external override returns (
        address target, uint rewardAmt) {
        receiveVSR();
        // Let's prevent unnecessary loops / propogation 
        if ((availableReward == 0) || _lastUpdated >= block.timestamp) { 
            return (address(this), 0);
        }
        address rewarderAddr = BQueue.peek(bq);
        IArtifact artifact_ = IArtifact(artifactAddr);
        uint nextV = artifact_.updateAccumulated(rewarderAddr);

        // Changing this first should prevent cycles at gate above, even though
        // there's no way for sender to be called via transfer (only RFs).
        _lastUpdated = uint32(block.timestamp);
        if (nextV == 0 || allocations[rewarderAddr].amount == 0 || (
            positions[rewarderAddr] == 0)) {
            BQueue.dequeue(bq);
            return (address(this), 0);
        }

        if (rewarderAddr == address(this)) {
            nextV = isRoot ? 0 : artifact_.accRewardClaim(
                artifactAddr, activeOnly) / 2;
            if (nextV == 0) { 
                BQueue.requeue(bq);
                return (address(this), 0); 
            }
        }

        target = allocations[rewarderAddr].target; 
        uint alloc = uint(allocations[rewarderAddr].amount);

        uint totalAccR = artifact_.accRewardClaim(artifactAddr, activeOnly);
        if (totalAccR == 0) {
            BQueue.requeue(bq);
            return (address(this), 0); 
        }
        uint amtToMove = availableReward * nextV / (
            artifact_.accRewardClaim(artifactAddr, activeOnly) * 2 * FRACTION_TO_PASS);
        rewardAmt = amtToMove * alloc / MAX_ALLOC;
        BQueue.requeue(bq);

        if (rewardAmt <= 0) { return (target, 0); }

        if (target != address(this)) {
            IGeras(gerasAddr).vsaTransfer(target, rewardAmt);
            totalGeras -= rewardAmt;
        }
        availableReward -= amtToMove;

        // accumulatedPayout += amtToMove * (MAX_ALLOC - alloc) / MAX_ALLOC;

        if (rewarderAddr != address(this) && (
            block.timestamp * amtToMove * 187) % 3 == 1) {
            IRewardFlow(target).payForward();
        }

    }

    function nextAllocator() external view returns (address) {
        return BQueue.peek(bq);
    }

    function nextAllocatedTarget() external view returns (address) {
        return allocations[BQueue.peek(bq)].target;
    }

    function nextAllocatedAmount() external view returns (uint) {
        return allocations[BQueue.peek(bq)].amount;
    }

    /** 
        * Redirect some amount of reward flow towards another artifact. 
        * This creates a new position for the sender, as well as entry within 
        * the budget queue. The allocation will be interpreted as a fraction 
        * of the RF that the sender currently claims: which is derived from 
        * the vouch-time of that sender.  If an allocation already exists for 
        * this sender, it is removed and replaced with this one. 
        * If the allocation amount is zero, remove completely.
    */
    function submitAllocation(address targetAddr, uint8 amt, address voucher) 
    external override returns (uint queuePosition) {

        require(amt <= MAX_ALLOC, 'Budget Allocation > 256');
        require(address(this) != targetAddr, 'No Artifact self-reward allowed');

        if (msg.sender != gerasAddr) { voucher = msg.sender; }

        require(IArtifact(artifactAddr).balanceOf(voucher) > 0, 
            'Sender has not vouched');
        require(IRewardFlowFactory(rfFactory).getArtiToRF(
            targetAddr) != address(0), 'Target RewardFlow not found');

        this.payForward();

        if (amt == 0) {
            positions[voucher] = 0;
            return 0;
        }
        if (positions[voucher] > 0) {
            queuePosition = positions[voucher];
        }
        else {
            queuePosition = BQueue.getNextPos(bq);
            BQueue.enqueue(bq, voucher);
            positions[voucher] = queuePosition;
        }

        allocations[voucher] = Allocation(targetAddr, amt);

        emit Allocate(voucher, targetAddr, amt);
    }

    /** 
        * Direct a redemption request to the artifact for processing. 
        * This contract holds the available Geras for all claims, while the artifact
        * tracks how much each claimer is entitled to given their vouching time. 
        * Once the artifact checks that this claimer is due some amount,
        * the request will be finalized and transferred by the Geras contract 
        * (or denied).
    */
    function redeemReward(address claimer, uint redeemAmt) external returns (
        uint availableGeras) {
        // The artifact checks that the claimer is valid and the returns the 
        // percentage that the redemption amounts to.
        uint totalClaim = IArtifact(artifactAddr).accRewardClaim(artifactAddr, activeOnly);
        uint availableClaim = IArtifact(artifactAddr).accRewardClaim(claimer, activeOnly);
        require(totalClaim > 0, 'RF: Total claim is zero');
        require(IGeras(gerasAddr).vsaBalanceOf(address(this)) > availableReward, 
            'No Geras is available');

        availableGeras = (IGeras(gerasAddr).vsaBalanceOf(
            address(this)) - availableReward) * availableClaim / totalClaim;

        require(redeemAmt <= availableGeras, 'RF Redemption exceeds available');

        // Go back to artifact and take redemption from accumulated claims.
        IArtifact(artifactAddr).redeemRewardClaim(
            claimer, availableClaim * redeemAmt / availableGeras);
        totalGeras -= redeemAmt;

        // This needs to convert into the actual asset and verify. 
        // IGeras(gerasAddr).vsaTransfer(address(this), claimer, gerasAmt);
        IGeras(gerasAddr).claimReward(redeemAmt, claimer);
    }

}


