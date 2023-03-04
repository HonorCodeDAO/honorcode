const Honor = artifacts.require("Honor");
const Artifact = artifacts.require("Artifact");
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

contract('Honor', (accounts, deployer) => {
  it('should put 10000 Honor in the first account', async () => {
    const HonorInstance = await Honor.deployed();
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
  it('should vouch correctly', async () => {
    const HonorInstance = await Honor.deployed();
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


    const newAddr = await HonorInstance.proposeArtifact.call(rootAddr, accountThree, 'new artifact');
    await HonorInstance.proposeArtifact(rootAddr, accountThree, 'new artifact');

    const accountOneStartingBalance1 = (await HonorInstance.balanceOf.call(rootAddr)).toNumber();
    console.log(accountOneStartingBalance1);
    await HonorInstance.validateArtifact(rootAddr, newAddr);

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
  });
  it('should credit builder correctly', async () => {

    let duration = time.duration.seconds(360000);

    const builderTwo = accounts[2];
    const HonorInstance = await Honor.deployed();
    const rootAddr = await HonorInstance.getRootArtifact.call();
    const rootBalance = await HonorInstance.balanceOf.call(rootAddr);
    const newAddr = await HonorInstance.proposeArtifact.call(rootAddr, builderTwo, 'new artifact');
    await HonorInstance.proposeArtifact(rootAddr, builderTwo, 'new artifact');
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

});
