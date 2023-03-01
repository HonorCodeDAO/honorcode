// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./Artifact.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/ISTT.sol";


// This contract represents base HONOR. It keeps the verified list of 
// artifacts, acts as a go-between during vouching/unvouching artifacts, 
// and manages the cash flow collection and resulting HONOR mints.

library ArtifactData {
  struct data {
     uint posHNR;
     uint negHNR;
     uint posFlow;
     uint negFlow;
     bool isProposed;
     bool isLive;
   }
}

contract Honor is ISTT {
    mapping (address => uint) private _balances;
    mapping (address => ArtifactData.data) artifacts;
    address public rootArtifact;
    uint private _totalSupply;
    uint constant VALIDATE_AMT = 1;

    event Vouch(address _account, address indexed _from, address indexed _to, uint256 _value);

    constructor() {
        Artifact root = new Artifact(tx.origin, address(this), "rootArtifact");
        rootArtifact = address(root);
        _mint(rootArtifact, 10000);
        // IArtifact(rootArtifact).vouch(tx.origin);
        require(_balances[rootArtifact] > 0, "root balance 0");
        root.initVouch(msg.sender, 10000);
        _balances[rootArtifact] = 10000;
        root.setRoot();
    }

    function balanceOf(address addr) public view returns(uint) {
        return _balances[addr]; 
    }

    function balanceOfArtifact(address addr, address account) public view returns(uint) {
        return IArtifact(addr).balanceOf(account);
    }

    function internalHonorBalanceOfArtifact(address addr) public view returns(uint) {
        return IArtifact(addr).internalHonor();
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

    function getArtifactData(address addr) public view returns (ArtifactData.data memory) {
        return artifacts[addr];
    }

    

    // function getArtifactBalance(address addr) public view returns(uint) {
    //     return int(artifacts[addr].posHNR) - int(artifacts[addr].negHNR);
    // }

    function vouch(address _from, address _to, uint amount) public returns(uint revouchAmt) {
        require(_balances[_to] != 0 && _balances[_from] != 0 && IArtifact(_to).isValidated(), 
            "Invalid vouching target");
        require(IArtifact(_from).balanceOf(msg.sender) >= amount, "Insufficient vouch balance");

        uint hnrAmt = IArtifact(_from).unvouch(msg.sender, _to, amount);
        _transfer(_from, _to, hnrAmt);

        revouchAmt = IArtifact(_to).vouch(msg.sender); 

        emit Vouch(msg.sender, _from, _to, hnrAmt);
    }

    function proposeArtifact(address _from, address builder, string memory location) public returns(address proposedAddr) { 

        Artifact newArtifact = new Artifact(builder, address(this), location); 
        proposedAddr = address(newArtifact);

        require(IArtifact(_from).balanceOf(msg.sender) >= VALIDATE_AMT, "Insufficient proposer balance");

        uint hnrAmt = IArtifact(_from).unvouch(msg.sender, proposedAddr, VALIDATE_AMT);
        _transfer(_from, proposedAddr, hnrAmt);
        IArtifact(proposedAddr).receiveDonation();
    }

    function validateArtifact(address _from, address addr) public returns(bool validated) { 
        if (IArtifact(addr).isValidated() && _balances[addr] > 0) {
            return true;
        }
        require(IArtifact(_from).balanceOf(msg.sender) >= VALIDATE_AMT, "Insufficient balance for validation");

        uint hnrAmt = IArtifact(_from).unvouch(msg.sender, addr, VALIDATE_AMT);
        _transfer(_from, addr, hnrAmt);
        IArtifact(addr).receiveDonation();
        return IArtifact(_from).validate();
    }

    function _mint(address account, uint256 amount) internal virtual {
        // require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        // emit Transfer(address(0), account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "HONOR: transfer from the zero address");
        require(recipient != address(0), "HONOR: transfer to the zero address");

        // require(artifacts[sender] 
        // require(_balances[recipient] > 0);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "HONOR: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

}
