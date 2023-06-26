// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "../interfaces/IGeras.sol";
// import "../interfaces/IERC20.sol";
import "../interfaces/IArtifact.sol";
import "../interfaces/IRewardFlow.sol";
import "./RewardFlow.sol";


// This contract represents Geras, the "spoils of honor".
// It allows for accounting of the staked asset rewards
// that are pledged to the attached HONOR instance.


// contract GerasFactory {
//     function createGeras(address root, address hnrAddr) public returns(Geras) {
//         return new Geras(root, hnrAddr);
//     }
// }

// contract Geras is IGeras {
//     mapping (address => uint) private _balances;
//     mapping (address => uint) private _stakedAsset;
//     // mapping (address => ArtifactData.data) artifacts;
//     address public honorAddr;
//     address public rootArtifact;
//     address public stakedAssetAddr = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
//     uint public totalVirtualStakedAsset;
//     uint public totalVirtualStakedReward;
//     uint private _totalSupply;

//     uint32 constant public STAKED_ASSET_CONVERSION = 1;


//     // event Vouch(address _account, address indexed _from, address indexed _to, uint256 _value);

//     constructor(address root, address hnrAddr) {
//         rootArtifact = root;
//         honorAddr = hnrAddr;
//     }

//     function _mint(address account, uint256 amount) internal virtual {
//         // require(account != address(0), "ERC20: mint to the zero address");

//         _totalSupply += amount;
//         _balances[account] += amount;
//         emit Transfer(address(0), account, amount);
//     }

//     function balanceOf(address addr) public view returns(uint) {
//         return _balances[addr]; 
//     }

//     function transfer(address sender, address recipient, uint256 amount) public virtual {
//         require(sender != address(0), "GERAS: transfer from the zero address");
//         require(recipient != address(0), "GERAS: transfer to the zero address");
//         require(IArtifact(IRewardFlow(recipient).getArtifact()).isValidated());

//         uint256 senderBalance = _balances[sender];
//         require(senderBalance >= amount, "GERAS: transfer amount exceeds balance");
//         _balances[sender] = senderBalance - amount;
//         _balances[recipient] += amount;

//         emit Transfer(sender, recipient, amount);
//     }

//     // function distributeGeras(address stakedAssetAddress) external returns (uint newVSR) {
//     //     newVSR =  IERC20(stakedAssetAddress).balanceOf(address(honorAddr)) - totalVirtualStakedAsset;
//     //     totalVirtualStakedAsset = totalVirtualStakedAsset + newVSR;
//     //     RewardFlow rf = IArtifact(rootArtifact).getRewardFlow();
//     //     _mint(address(rf), newVSR * STAKED_ASSET_CONVERSION);
//     //     rf.receiveVSR();
//     //     rf.payForward();

//     // }

// }
