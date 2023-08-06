const Honor = artifacts.require("Honor");
const Artifact = artifacts.require("Artifact");
const Artifactory = artifacts.require("Artifactory");
const RewardFlowFactory = artifacts.require("RewardFlowFactory");
const RewardFlow = artifacts.require("RewardFlow");
const Geras = artifacts.require("Geras");
const { time } = require("@openzeppelin/test-helpers");

advanceTime = (time) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [time],
      id: new Date().getTime()
    }, (err, result) => {
      if (err) { return reject(err) }
      return resolve(result)
    })
  })
}

contract('RewardFlow', (accounts, deployer) => {
  it('should put 10000 Honor in the first account', async () => {    
    const ArtiFactoryInstance = await Artifactory.deployed();
    const HonorInstance = await Honor.new(ArtiFactoryInstance.address);
    // const ArtifactInstance = await Artifact.deployed();
    const artyAddr = await HonorInstance.getRootArtifact.call();
    const balance = await HonorInstance.balanceOf.call(artyAddr);
    // const balance = await HonorInstance.balanceOf.call(accounts[1]);

    assert.equal(balance.valueOf(), 10000, "10000 wasn't in the first account");
  });
  // it('should call a function that depends on a linked library', async () => {
  //   const HonorInstance = await Honor.deployed();
  //   const HonorBalance = (await HonorInstance.balanceOf.call(accounts[0])).toNumber();
  //   // const HonorEthBalance = (await HonorInstance.getBalanceInEth.call(accounts[0])).toNumber();
  //   assert.equal(HonorEthBalance, 2 * HonorBalance, 'Library function returned unexpected function, linkage may be broken');
  // });
  it('should distribute Geras correctly', async () => {
    const ArtiFactoryInstance = await Artifactory.deployed();
    const HonorInstance = await Honor.new(ArtiFactoryInstance.address);
    // const HonorInstance = await Honor.deployed();
    const gerasAddr = await HonorInstance.getGeras.call();
    let duration = time.duration.seconds(360000);

    // const ArtifactInstance = await deployer.deploy(Artifact, accounts[1], HonorInstance.address, 'new artifact');
    // const ArtifactInstance = await Artifact.deployed(accounts[1], HonorInstance.address, 'new artifact');

    // Setup 2 accounts.
    const accountOne = accounts[0];
    const accountTwo = accounts[1];
    const accountThree = accounts[2];

    // Get initial balances of first and second account.
    // const accountOneStartingBalance = (await HonorInstance.getBalance.call(accountOne)).toNumber();
    // const accountTwoStartingBalance = (await HonorInstance.getBalance.call(accountTwo)).toNumber();

    const rootAddr = await HonorInstance.getRootArtifact.call();
    const rootBalance = await HonorInstance.balanceOf.call(rootAddr);

    // Make transaction from first account to second.
    const amount = 10;
    const amountHonor = 100;

    const accountOneStartingBalance = (await HonorInstance.balanceOf.call(rootAddr)).toNumber();

    // await HonorInstance.vouch(rootAddr, rootAddr, 1);

    const newAddr = await HonorInstance.proposeArtifact.call(rootAddr, accountThree, 'new artifact');
    await HonorInstance.proposeArtifact(rootAddr, accountThree, 'new artifact');

    const accountOneStartingBalance1 = (await HonorInstance.balanceOf.call(rootAddr)).toNumber();
    console.log(accountOneStartingBalance1);
    // await HonorInstance.validateArtifact(rootAddr, newAddr);

    const accountOneStartingBalance2 = (await HonorInstance.balanceOf.call(rootAddr)).toNumber();
    const accountTwoStartingBalance = (await HonorInstance.balanceOf.call(newAddr)).toNumber();

    await HonorInstance.vouch(rootAddr, newAddr, 1);

    // Get balances of first and second account after the transactions.
    const accountOneEndingBalance = (await HonorInstance.balanceOf.call(rootAddr)).toNumber();
    const accountTwoEndingBalance = (await HonorInstance.balanceOf.call(newAddr)).toNumber();

    // const expectedHonorOutput = accountOneStartingBalance2 - (accountOneStartingBalance2 ** 0.5 - amount)**2;
    const expectedHonorOutput = 197;

    const internalHonor = (await HonorInstance.internalHonorBalanceOfArtifact.call(newAddr)).toNumber();
    assert.equal(accountTwoEndingBalance, internalHonor, "Amount isn't what artifact thinks");

    assert.equal(accountOneEndingBalance, accountOneStartingBalance2 - expectedHonorOutput, "Amount wasn't correctly taken from the sender");
    assert.equal(accountTwoEndingBalance, accountTwoStartingBalance + expectedHonorOutput, "Amount wasn't correctly sent to the receiver");


    const geras = (await HonorInstance.getGeras.call());
    const GerasInstance = await Geras.at(geras);
    const RewardFlowFactoryInstance = await RewardFlowFactory.deployed();
    // const RewardFlowInstance = await RewardFlowFactoryInstance.createRewardFlow.call(rootAddr, geras);
    // const RewardFlowInstanceNew = await RewardFlowFactoryInstance.createRewardFlow.call(newAddr, geras);

    // module.exports = function(deployer) {
    //   const RewardFlowInstance = await deployer.deploy(RewardFlow, rootAddr, geras);
    // }

    const RewardFlowInstance = await RewardFlow.new(rootAddr, geras);
    const RewardFlowInstanceNew = await RewardFlow.new(newAddr, geras);

    // beforeEach(async function () {
    //     const RewardFlowInstance = await RewardFlowFactoryInstance.createRewardFlow.call(rootAddr, geras);
    // });
    // console.log(geras);

    const artifactTwoStartingBalanceGeras = (await GerasInstance.balanceOf.call(RewardFlowInstanceNew.address)).toNumber();
    const alloc = (await RewardFlowInstance.submitAllocation(RewardFlowInstanceNew.address, 512));

    (await GerasInstance.stakeAsset(rootAddr, 1000000000000000));
    const stakedAmt = (await GerasInstance.getStakedAsset.call(rootAddr)).toNumber();
    // console.log(stakedAmt);

    await time.increase(duration);
    await GerasInstance.distributeGeras(RewardFlowInstance.address);
    const artifactOneStartingBalanceGeras = (await GerasInstance.balanceOf.call(RewardFlowInstance.address)).toNumber();
    await RewardFlowInstance.payForward();
    // await GerasInstance.distributeReward(RewardFlowInstanceNew.address);

    let rewardAmt = 1000000000000000 * 32 / 1024 * duration / 31536000;

    const artifactOneEndingBalanceGeras = (await GerasInstance.balanceOf.call(RewardFlowInstance.address)).toNumber();
    const artifactTwoEndingBalanceGeras = (await GerasInstance.balanceOf.call(RewardFlowInstanceNew.address)).toNumber();
    console.log(artifactOneStartingBalanceGeras);
    console.log(artifactOneEndingBalanceGeras);
    console.log(artifactTwoEndingBalanceGeras);
    console.log(rewardAmt);
    // assert(artifactOneStartingBalanceGeras == 356736150748, 'starting root geras Incorrect');
    // assert(artifactOneEndingBalanceGeras == 313054173106, 'ending root geras Incorrect');
    // assert(artifactTwoEndingBalanceGeras == 43681977642, 'new artifact geras Incorrect');
    // await RewardFlowInstance.payForward();
    // const artifactOneFinalBalanceGeras = (await GerasInstance.balanceOf.call(RewardFlowInstance.address)).toNumber();
    // console.log(artifactOneFinalBalanceGeras);
    // assert(artifactOneFinalBalanceGeras == 274721009053, 'final root geras Incorrect');


    var bytecode = RewardFlowInstance.constructor._json.bytecode;
    var deployed = RewardFlowInstance.constructor._json.deployedBytecode;
    var sizeOfB  = bytecode.length / 2;
    var sizeOfD  = deployed.length / 2;
    console.log("size of RewardFlow bytecode in bytes = ", sizeOfB);
    console.log("size of RewardFlow deployed in bytes = ", sizeOfD);
    console.log("initialisation and constructor code in bytes = ", sizeOfB - sizeOfD);


    bytecode = HonorInstance.constructor._json.bytecode;
    deployed = HonorInstance.constructor._json.deployedBytecode;
    sizeOfB  = bytecode.length / 2;
    sizeOfD  = deployed.length / 2;
    console.log("size of Honor bytecode in bytes = ", sizeOfB);
    console.log("size of Honor deployed in bytes = ", sizeOfD);

  });
  it('should credit builder correctly', async () => {

    let duration = time.duration.seconds(360000);

    const builderTwo = accounts[2];    
    const ArtiFactoryInstance = await Artifactory.deployed();
    const HonorInstance = await Honor.new(ArtiFactoryInstance.address);
    const rootAddr = await HonorInstance.getRootArtifact.call();
    const rootBalance = await HonorInstance.balanceOf.call(rootAddr);
    const newAddr = await HonorInstance.proposeArtifact.call(rootAddr, builderTwo, 'new artifact');
    await HonorInstance.proposeArtifact(rootAddr, builderTwo, 'new artifact');
    
    // await HonorInstance.validateArtifact(rootAddr, newAddr);

    // await HonorInstance.proposeArtifact(rootAddr, builderTwo, 'new artifact');
    await HonorInstance.vouch(rootAddr, newAddr, 10);
    const internalHonor = (await HonorInstance.internalHonorBalanceOfArtifact.call(newAddr)).toNumber();

    const builderA = (await HonorInstance.getArtifactBuilder.call(newAddr));

    const builderStartingBalance = (await HonorInstance.balanceOfArtifact.call(newAddr, builderTwo)).toNumber();
    // advanceTime(36000);
    // console.log((await HonorInstance.getArtifactAccumulatedHonorHours.call(newAddr)).toNumber());
    await time.increase(duration);
    await HonorInstance.vouch(rootAddr, newAddr, 1);
    // console.log((await HonorInstance.getArtifactAccumulatedHonorHours.call(newAddr)).toNumber());

    const builderEndingBalance = (await HonorInstance.balanceOfArtifact.call(newAddr, builderTwo)).toNumber();

    const expectedBuilderChange = 20;
    assert.equal(builderEndingBalance, builderStartingBalance + expectedBuilderChange, "Incorrect change for builder");

  });
  // it("get the size of the contract", function() {
  //   return RewardFlow.deployed().then(function(instance) {
  //     var bytecode = instance.constructor._json.bytecode;
  //     var deployed = instance.constructor._json.deployedBytecode;
  //     var sizeOfB  = bytecode.length / 2;
  //     var sizeOfD  = deployed.length / 2;
  //     console.log("size of RewardFlow bytecode in bytes = ", sizeOfB);
  //     console.log("size of RewardFlow deployed in bytes = ", sizeOfD);
  //     console.log("initialisation and constructor code in bytes = ", sizeOfB - sizeOfD);
  //   });  
  // });
});
