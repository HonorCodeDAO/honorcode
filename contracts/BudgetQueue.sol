// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./SafeMath.sol";

// This queue is meant to approximate proportional allocation, but instead of sending to all 
// targets, an amount is propagated in round-robin format, so that at most one forwarding 
// occurs at a time. We can track an overflow value that will be drawn from in the future to 
// continue sending to each desired address. 
// The amount to be forwarded will depend on:
//  * the vouched HONOR of the voting address
//  * the amount allocated towards the destination address 
//  * the amount accumulated in the outflow, which grows over time
//  
contract BudgetQueue {
    mapping (uint32 => address) queue;
    uint32 private first = 1;
    uint32 private last = 0; 
    address rewardFlowAddr;

    constructor(address rewardFlowAddr_) {
        rewardFlowAddr = rewardFlowAddr_;
    }

    function enqueue(address newAddress) public {
        last += 1;
        queue[last] = newAddress;
    }

    function dequeue() public returns (address next) {
        require (first <= last); 
        next = queue[first];
        delete queue[first];
        first += 1;
    }

    function requeue() public returns (address next) {
        require (first <= last); 
        next = queue[first];
        delete queue[first];
        first += 1;
        enqueue(next);
    }

    function peek() public view returns (address) {
        require (first <= last, 'budget queue is empty'); 
        return queue[first];
    }

    function isEmpty() public view returns (bool) {
        return first > last;
    }

    function getNextPos() public view returns (uint) {
        return last + 1; 
    }
}


contract BudgetQueueFactory {
    function createBudgetQueue(address rewardFlowAddr_) public returns(BudgetQueue) {
        return new BudgetQueue(rewardFlowAddr_);
    }
}
