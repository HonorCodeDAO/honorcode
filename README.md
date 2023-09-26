# Honor Code

HONOR CODE is a reputation system for contribution scoring, prediction market,
and governance tool in an all-in-one set of contracts. 
It achieves these purposes by implementing a *semi-transferable token*, used to manage recognition in a DAO or software project. 

Each unit of HONOR is *vouched* to an *Artifact*, representing an entire Org, sub-module, or contribution. 
The "price" of a Vouch claim to an artifact depends on how much HONOR is already vouched, decreasing as a square root or other sublinear rate. Therefore, an investor will have to vouch more HONOR for a popular artifact to get the same claim as someone who vouched at an early stage. In return, vouching earns a piece of any money rewards directed at this node. As a result, vouching serves as a prediction market for contribution value, and
can serve as a results oracle for retroactive funding.

Additionally, the builder of an artifact receives some Vouch claim as a function of HONOR 
vouched over time, also tapered as a square root or sublinear function of HONOR-hours. 
This step allows for a measure of impact as time goes on, when the value of a contribution becomes more clear. 

There are corresponding contracts for allocating cash flow. *Geras* represents a
*virtual staked asset* attained by staking some LST such as staked ETH. The 
staker receives farmed HONOR instead of rewards, which go into the protocol. 
The *RewardFlow* contract allows vouchers for an artifact to allocate these 
rewards on a continuous basis to other Artifacts in the same Org. Each artifact
therefore becomes a miniature ongoing funding round!

This mechanism aims to solve the problems arising from fully liquid tokens (plutocracy, short-term speculation,
etc.) without the inflexibility of Soul-bounded tokens. For the retroactive public goods setting, 
this structure can act as a *Results Oracle*, estimating impact over time. The prediction market aspect
creates incentives to reward early supporters of a promising contribution and allocate recognition 
and financial rewards to builders. 