const Honor = artifacts.require("Honor");
const Artifact = artifacts.require("Artifact");
const MockCoin = artifacts.require("MockCoin");
const Artifactory = artifacts.require("Artifactory");
const { time } = require("@openzeppelin/test-helpers");

/* global BigInt */

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

contract('Honor', (accounts, deployer) => {
  it('should put 10000 Honor in the first account', async () => {

    const ArtiFactoryInstance = await Artifactory.deployed();
    const mockERC = await MockCoin.deployed();
    const HonorInstance = await Honor.new(ArtiFactoryInstance.address, mockERC.address);

    // const ArtifactInstance = await Artifact.deployed();
    const artyAddr = await HonorInstance.rootArtifact.call();
    const balance = await HonorInstance.balanceOf.call(artyAddr);
    // const balance = await HonorInstance.balanceOf.call(accounts[1]);

    assert.equal(balance.valueOf(), 10000e18, "10000 wasn't in the first account");

    bytecode = HonorInstance.constructor._json.bytecode;
    deployed = HonorInstance.constructor._json.deployedBytecode;
    sizeOfB  = bytecode.length / 2;
    sizeOfD  = deployed.length / 2;
    console.log("size of Honor bytecode in bytes = ", sizeOfB);
    console.log("size of Honor deployed in bytes = ", sizeOfD);

    const rootAddr = await HonorInstance.rootArtifact.call()
    // console.log("msg sender", msg.sender);
    console.log("root", rootAddr);

    // const accountThree = accounts[2];
    // const newAddr = await HonorInstance.proposeArtifact(rootAddr, accountThree, 'new artifact');
    // console.log("new", newAddr);
    const ArtifactInstance = await Artifact.at(rootAddr);

    bytecode = ArtifactInstance.constructor._json.bytecode;
    deployed = ArtifactInstance.constructor._json.deployedBytecode;
    sizeOfB  = bytecode.length / 2;
    sizeOfD  = deployed.length / 2;
    console.log("size of Artifact bytecode in bytes = ", sizeOfB);
    console.log("size of Artifact deployed in bytes = ", sizeOfD);
    // console.log("root holding", (await ArtifactInstance.balanceOf.call(rootAddr)).toNumber());


  });
  // it('should call a function that depends on a linked library', async () => {
  //   const HonorInstance = await Honor.deployed();
  //   const HonorBalance = (await HonorInstance.balanceOf.call(accounts[0])).toNumber();
  //   // const HonorEthBalance = (await HonorInstance.getBalanceInEth.call(accounts[0])).toNumber();
  //   assert.equal(HonorEthBalance, 2 * HonorBalance, 'Library function returned unexpected function, linkage may be broken');
  // });
  it('should vouch correctly', async () => {

    const ArtiFactoryInstance = await Artifactory.deployed();
    const mockERC = await MockCoin.deployed();
    const HonorInstance = await Honor.new(ArtiFactoryInstance.address, mockERC.address);
    // const ArtifactInstance = await deployer.deploy(Artifact, accounts[1], HonorInstance.address, 'new artifact');
    // const ArtifactInstance = await Artifact.deployed(accounts[1], HonorInstance.address, 'new artifact');

    // Setup 2 accounts.
    const accountOne = accounts[0];
    const accountTwo = accounts[1];
    const accountThree = accounts[2];

    // Get initial balances of first and second account.
    // const accountOneStartingBalance = (await HonorInstance.getBalance.call(accountOne)).toNumber();
    // const accountTwoStartingBalance = (await HonorInstance.getBalance.call(accountTwo)).toNumber();

    const rootAddr = await HonorInstance.rootArtifact.call();
    const rootBalance = await HonorInstance.balanceOf.call(rootAddr);

    // const amount = 10;
    // const amountHonor = 100;

    // const accountOneStartingBalance = (await HonorInstance.balanceOf.call(rootAddr)).toNumber();
    const accountOneStartingBalance = (await HonorInstance.balanceOf.call(rootAddr));//.toString();
    // console.log(accountOneStartingBalance);

    // const newAddr = await HonorInstance.proposeArtifact.call(rootAddr, accountThree, 'new artifact');

    // const accountOneStartingBalance1 = (await HonorInstance.balanceOf.call(rootAddr));//.toNumber();
    // console.log(accountOneStartingBalance1);

    const ArtifactInstance = await Artifact.at(rootAddr);
    console.log('root honor ', (await HonorInstance.internalHonorBalanceOfArtifact.call(rootAddr)).toString());
    console.log('root vouch ', (await ArtifactInstance.totalSupply.call()).toString());

    const newAddr = await HonorInstance.proposeArtifact.call(rootAddr, accountThree, 'new artifact');
    const receipt = await HonorInstance.proposeArtifact(rootAddr, accountThree, 'new artifact');

    const gasUsed = receipt.receipt.gasUsed;
    console.log('Gas to proposeArtifact', gasUsed);

    // await HonorInstance.validateArtifact(rootAddr, newAddr);

    const accountOneStartingBalance2 = (await HonorInstance.balanceOf.call(rootAddr));//.toNumber();
    const accountTwoStartingBalance = (await HonorInstance.balanceOf.call(newAddr));//.toNumber();
    assert(accountTwoStartingBalance > 0, 'No HONOR in new address');

    const vouchreceipt = await HonorInstance.vouch(rootAddr, newAddr, 1);
    console.log('Gas to vouchArtifact', vouchreceipt.receipt.gasUsed);

    // Get balances of first and second account after the transactions.
    const accountOneEndingBalance = (await HonorInstance.balanceOf.call(rootAddr));//.toNumber();
    const accountTwoEndingBalance = (await HonorInstance.balanceOf.call(newAddr));//.toNumber();

    // const expectedHonorOutput = accountOneStartingBalance2 - (accountOneStartingBalance2 ** 0.5 - amount)**2;
    const expectedHonorOutput = 197;
    const expectedHonorOutput2 = 185;

    const internalHonor = (await HonorInstance.internalHonorBalanceOfArtifact.call(newAddr));//.toNumber();
    // console.log('internalHonor', internalHonor.toString());
    // console.log('accountOneStartingBalance2', accountOneStartingBalance2.toString());
    // console.log('accountOneEndingBalance', accountOneEndingBalance.toString());
    // console.log('accountTwoStartingBalance', accountTwoStartingBalance.toString());
    // console.log('accountTwoEndingBalance', accountTwoEndingBalance.toString());
    assert.equal(accountTwoEndingBalance.toString(), internalHonor.toString(), "Amount isn't what artifact thinks");

    assert.equal(accountOneEndingBalance.valueOf(), accountOneStartingBalance2.valueOf() - expectedHonorOutput.valueOf(), "Amount wasn't correctly taken from the sender");
    // assert.equal(accountTwoEndingBalance.valueOf(), accountTwoStartingBalance.valueOf() + expectedHonorOutput2, "Amount wasn't correctly sent to the receiver");
  });
  it('should credit builder correctly', async () => {

    let duration = time.duration.seconds(360000);

    const builderTwo = accounts[2];
    const ArtiFactoryInstance = await Artifactory.deployed();
    const mockERC = await MockCoin.deployed();
    const HonorInstance = await Honor.new(ArtiFactoryInstance.address, mockERC.address);

    const rootAddr = await HonorInstance.rootArtifact.call();
    const rootBalance = await HonorInstance.balanceOf.call(rootAddr);


    const rootVouchBal = (await HonorInstance.balanceOfArtifact.call(rootAddr, accounts[0]));
    console.log('root starting vouch balance', rootVouchBal.toString());
    console.log('root starting honor balance', rootBalance.toString());

    // const newAddr = await HonorInstance.proposeArtifact.call(rootAddr, builderTwo, 'new artifact');
    const newAddr = await HonorInstance.proposeArtifact.call(rootAddr, builderTwo, 'new artifact');
    await HonorInstance.proposeArtifact(rootAddr, builderTwo, 'new artifact');

    // await HonorInstance.validateArtifact(rootAddr, newAddr);

    await HonorInstance.vouch(rootAddr, newAddr, '1000000000000000000');
    // const internalHonor = (await HonorInstance.internalHonorBalanceOfArtifact.call(newAddr));//.toNumber();

    const builderA = (await HonorInstance.getArtifactBuilder.call(newAddr));

    const builderStartingBalance = (await HonorInstance.balanceOfArtifact.call(newAddr, builderTwo)).toNumber();
    // advanceTime(36000);
    // console.log((await HonorInstance.getArtifactAccumulatedHonorHours.call(newAddr)).toNumber());
    await time.increase(duration);
    await HonorInstance.vouch(rootAddr, newAddr, 1000000);
    // console.log((await HonorInstance.getArtifactAccumulatedHonorHours.call(newAddr)).toNumber());

    const builderEndingBalance = (await HonorInstance.balanceOfArtifact.call(newAddr, builderTwo));

    const expectedBuilderChange =  2255213797289492480;
    console.log('builderEndingBalance', builderEndingBalance.toString());

    const newInstance = await Artifact.at(newAddr);
    const vouchBalance = await newInstance.totalSupply.call();
    console.log('vouchBalance', vouchBalance.toString());

    assert.equal(builderEndingBalance, builderStartingBalance.valueOf() + expectedBuilderChange.valueOf(), "Incorrect change for builder");

  });

});
