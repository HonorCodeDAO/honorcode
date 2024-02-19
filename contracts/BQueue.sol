pragma solidity ^0.8.13;

// This queue is meant to approximate proportional allocation, but instead of 
// sending to all targets, an amount is propagated in round-robin format, 
// so that at most one forwarding occurs at a time. We can track an overflow 
// value that will be drawn from in the future to continue sending to each 
// desired address. The amount to be forwarded will depend on:
//  * the vouched HONOR of the voting address
//  * the amount allocated towards the destination address 
//  * the amount accumulated in the outflow, which grows over time


struct BudgetQ {
    mapping (uint32 => address) queue;
    uint32 first;
    uint32 last; 
}

library BQueue {

    function enqueue(BudgetQ storage bq, address newAddress) internal {
        bq.last += 1;
        bq.queue[bq.last] = newAddress;
    }

    function dequeue(BudgetQ storage bq) internal returns (address next) {
        require (bq.first <= bq.last); 
        next = bq.queue[bq.first];
        delete bq.queue[bq.first];
        bq.first += 1;
    }

    function requeue(BudgetQ storage bq) internal returns (address next) {
        require (bq.first <= bq.last, 'Malformed budget queue'); 
        next = bq.queue[bq.first];
        delete bq.queue[bq.first];
        bq.first += 1;
        enqueue(bq, next);
    }

    function peek(BudgetQ storage bq) internal view returns (address firstA) {
        require (bq.first <= bq.last, 'budget queue is empty'); 
        firstA = bq.queue[bq.first];
    }

    function peekLast(BudgetQ storage bq) internal view returns (address lastA) {
        require (bq.first <= bq.last, 'budget queue is empty'); 
        lastA = bq.queue[bq.last];
    }

    function isEmpty(BudgetQ storage bq) internal view returns (bool empty) {
        empty = bq.first == 0 || bq.first > bq.last;
    }

    function getNextPos(BudgetQ storage bq) internal view returns (uint nextPos) {
        nextPos = bq.last + 1; 
    }

    function incrementFirst(BudgetQ storage bq) internal {
        bq.first += 1; 
    }
}
