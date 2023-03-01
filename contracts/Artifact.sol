// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./SafeMath.sol";
import "./Babylonian.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/ISTT.sol";

// This contract represents an artifact, which is a desitnation of Honor and has its own 
// token to represent shares of.
// A "vouch" is comprised of a transfer of HONOR from one artifact to another, 
// by a holder of the first. HONOR is removed from the sender's balance for this artifact,  
// and added to the vouchee artifact.


contract Artifact is IArtifact {

    string public location; 
    address public honorAddr;
    address public builder;
    uint public honorWithin;
    uint public accHonorHours;
    uint public builderHonor;
    uint public rewardFlow;
    uint public accReward;
    uint private _totalSupply;
    bool private _isProposed;

    // Where do the incoming rewards flow? 
    mapping (address => uint32) budgetFlow;
    // Where is everybody voting for these rewards to flow? The aggregate value 
    // above will be calculated from a weighted sum of individual submitted budgets. 
    mapping (address => mapping (address => uint32)) budgets;

    uint public constant ALPHANUM = 2;
    uint public constant ALPHADENOM = 3;
    uint public constant BETANUM = 1;
    uint public constant BETADENOM = 3;

    mapping (address => uint) private _balances;

    event Vouch(address indexed _vouchingAddr, address indexed _to, uint256 _honorAmt, uint256 _vouchAmt);
    event Unvouch(address indexed _vouchingAddr, address indexed _from, uint256 _honorAmt, uint256 _vouchAmt);

    constructor(address builderAddr, address honorAddress, string memory artifactLoc) {
        builder = builderAddr;
        location = artifactLoc;
        honorAddr = honorAddress;
        _balances[tx.origin] = 0;
        budgetFlow[address(this)] = uint32(1);
    }

    /** 
      * Given some input honor to this artifact, return the output vouch amount. 
    */
    function vouch(address account) external returns(uint vouchAmt) {
        uint totalHonor = ISTT(honorAddr).balanceOf(address(this));
        uint deposit = SafeMath.sub(totalHonor, honorWithin);

        // uint honorCbrt = SafeMath.floorCbrt(totalHonor);
        // uint prevHonorCbrt = SafeMath.floorCbrt(honorWithin);
        // vouchAmt = SafeMath.sub(honorCbrt * honorCbrt, prevHonorCbrt * prevHonorCbrt);

        vouchAmt = SafeMath.sub(Babylonian.sqrt(totalHonor), Babylonian.sqrt(honorWithin));

        emit Vouch(account, address(this), deposit, vouchAmt);
        _mint(account, vouchAmt);
        honorWithin += deposit;
        // _balances[account] += vouchAmt;
        recomputeBudget();
    }

    function initVouch(address account, uint inputHonor) external returns(uint vouchAmt) {
        require(msg.sender == honorAddr, "Only used for initial root vouching");
        vouchAmt = Babylonian.sqrt(inputHonor);
        _mint(account, vouchAmt);
        honorWithin += inputHonor;
        recomputeBudget();
    }

    /** 
      * Given some input vouching claim to this artifact, return the output honor. 
    */
    function unvouch(address account, address to, uint unvouchAmt) external returns(uint hnrAmt) {

        require(_balances[account] >= unvouchAmt, "Insufficient vouching balance");
        // require(ISTT(honorAddr).balanceOf(to) != 0, "Invalid vouching target");

        // uint prevVouchSqrt = SafeMath.floorSqrt(_totalSupply);
        // uint unvouchSqrt = SafeMath.floorSqrt(SafeMath.sub(_totalSupply, unvouchAmt));
        uint vouchedPost = SafeMath.sub(_totalSupply, unvouchAmt);

        hnrAmt = SafeMath.sub(_totalSupply ** 2, vouchedPost ** 2);

        emit Unvouch(account, address(this), hnrAmt, unvouchAmt);
        honorWithin -= hnrAmt;
        _burn(account, unvouchAmt);
        _balances[account] -= unvouchAmt;
        recomputeBudget();
    }

    function recomputeBudget() private returns (bool computed) {
        return true;
    }

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr];
    }

    function receiveDonation() external returns(uint) {
        uint totalHonor = ISTT(honorAddr).balanceOf(address(this));
        honorWithin += SafeMath.sub(totalHonor, honorWithin);
        return honorWithin;
    }

    function isValidated() external view returns(bool) {
        return !_isProposed;
    }

    function validate() external returns(bool) {
        require(msg.sender == honorAddr);
        _isProposed = false;
        return !_isProposed;
    }
    

    function _mint(address account, uint256 amount) internal virtual {
        // require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        // emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        // emit Vouch(account, address(0), amount);
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
}
