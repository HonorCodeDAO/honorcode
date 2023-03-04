// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// These files are dynamically created at test time
import "truffle/Assert.sol";
// import "truffle/DeployedAddresses.sol";
import "../contracts/Honor.sol";
import "../contracts/Artifact.sol";

contract TestHonor {

  // function testInitialBalanceUsingDeployedContract() public {
  //   Honor meta = Honor(DeployedAddresses.Honor());

  //   uint expected = 10000;

  //   Assert.equal(meta.getBalance(meta.rootArtifact), expected, "Owner should have 10000 Honor initially");
  // }

  function testInitialBalanceWithNewHonor() public {

    uint expected = 10000;
    Honor meta = new Honor();

    Assert.equal(meta.balanceOf(meta.rootArtifact()), expected, "Owner should have 10000 Honor initially");
  }

}
