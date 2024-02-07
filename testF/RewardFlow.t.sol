pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Honor} from "../contracts/Honor.sol";
import {Artifact} from "../contracts/Artifact.sol";
import {HonorFactory} from "../contracts/HonorFactory.sol";
import {Artifactory} from "../contracts/Artifactory.sol";
import {RewardFlow, RewardFlowFactory} from "../contracts/RewardFlow.sol";
import {Geras} from "../contracts/Geras.sol";
import {MockCoin} from "../contracts/MockCoin.sol";
import {SafeMath} from "../contracts/SafeMath.sol";

contract RewardFlowTest is Test {
    Honor public hnr;
    Artifactory public afact;
    Artifact public root;
    Geras public geras;
    RewardFlow public rootRF;
    RewardFlowFactory public rfact;
    MockCoin public mockERC;
    address owner;

    function setUp() public {
        afact = new Artifactory();
        mockERC = new MockCoin();
        // hnr = new Honor(address(afact), 'TEST_HONOR');

        HonorFactory hfact = new HonorFactory();
        hnr = Honor(hfact.createHonor(address(afact), 'TEST_HONOR'));

        root = Artifact(hnr.rootArtifact());
        geras = new Geras(address(hnr), address(mockERC));
        hnr.setGeras(address(geras));
        owner = hnr.owner();
        rfact = new RewardFlowFactory();
        hnr.setRewardFlowFactory(address(rfact));
        geras.setRewardFlowFactory(address(rfact));
        rootRF = RewardFlow(geras.createRewardFlow(address(root)));
        // rootRF = RewardFlow(rfact.createRewardFlow(address(hnr), address(root), address(geras)));

    }

    function testAddInitial() public {
        address builder = root.builder();

        assertEq(hnr.name(), 'TEST_HONOR');
        assertEq(hnr.owner(), builder);
        assertEq(hnr.balanceOf(address(root)), 10000 ether);
        assertEq(hnr.balanceOfArtifact(address(root), builder), SafeMath.floorSqrt(10000 ether) * (2 ** 30));
    }


    function testGerasDistributionRF(uint amount, uint mockAmt, uint32 duration) public {
        vm.assume(mockAmt < 100 ether);
        amount = bound(amount, 0.00001 ether, 100 ether);
        mockAmt = bound(mockAmt, 0.00001 ether, 100 ether);
        duration = uint32(bound(duration, 1000, 1000000));

        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA', true);

        assertEq(hnr.balanceOf(address(root)), 9999 ether, 'proposal Honor incorrect');

        uint rootVouch = root.balanceOf(builder);

        mockERC.transfer(address(geras), mockAmt);
        geras.stakeAsset(address(root));

        uint amtStaked = geras.totalSupply();
        uint lastUp = geras.lastUpdated();

        uint vouchAmt = hnr.vouch(address(root), newA, amount);

        // This may not equal mockAmt due to the rebase mechanism...
        assertEq(amtStaked, mockERC.balanceOf(address(geras)), 'expected VSA incorrect');

        address newRF = (rfact.createRewardFlow(address(hnr), newA, address(geras)));

        rootRF.submitAllocation(newRF, 128, owner);
        vm.warp(block.timestamp + duration - 1);
        geras.distributeGeras(address(rootRF));

        // assertEq(uint32(block.timestamp) - lastUp, duration, 'duration not exact');

        // assertEq(geras.getStakedAsset(builder), geras.totalSupply(), 'total staked incorrect');
        assertEq(amtStaked, geras.totalSupply(), 'total amt staked incorrect');

        uint expStartingGeras = (amtStaked * 32 / 1024) *(duration-1) / 31536000;

        assertEq(geras.vsaBalanceOf(address(rootRF)), expStartingGeras, 
            'expected starting Geras in root incorrect');

        rootRF.payForward();
        // This should actually be the same since root does not have a default allocation.
        uint availableGeras = rootRF.availableReward();
        vm.warp(block.timestamp + duration);

        rootRF.payForward();
        vouchAmt = hnr.vouch(address(root), newA, amount / 1000);

        uint builderRootVouch = root.balanceOf(builder);
        uint accbuilderRootVouch = root.accRewardClaim(builder);
        uint accTotalRootVouch = root.accRewardClaim(address(root));

        assertEq(accbuilderRootVouch, accTotalRootVouch, 'acc vouch in root incorrect');

        assertEq(geras.vsaBalanceOf(newRF), availableGeras * accbuilderRootVouch / (8*accTotalRootVouch) * 128/255, 
            'expected Geras in new address incorrect');

        assertEq(geras.vsaBalanceOf(address(rootRF)), expStartingGeras- availableGeras * accbuilderRootVouch / (8*accTotalRootVouch) * 128/255 , 
            'expected Geras in root address incorrect');
    }


    function testGerasDistribution(uint amount, uint mockAmt, uint32 duration) public {
        vm.assume(mockAmt < 100 ether);
        amount = bound(amount, 0.00001 ether, 100 ether);
        mockAmt = bound(mockAmt, 0.00001 ether, 100 ether);
        duration = uint32(bound(duration, 1000, 1000000));

        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA', true);

        assertEq(hnr.balanceOf(address(root)), 9999 ether, 'proposal Honor incorrect');

        uint rootVouch = root.balanceOf(builder);

        mockERC.transfer(address(geras), mockAmt);
        geras.stakeAsset(address(root));

        uint amtStaked = geras.totalSupply();
        uint lastUp = geras.lastUpdated();

        uint vouchAmt = hnr.vouch(address(root), newA, amount);

        // This may not equal mockAmt due to the rebase mechanism...
        assertEq(amtStaked, mockERC.balanceOf(address(geras)), 'expected VSA incorrect');

        address newRF = geras.createRewardFlow(newA);

        // vm.prank(owner);
        geras.submitAllocation(address(root), newA, 128);

        // rootRF.submitAllocation(newRF, 128, address(0));
        vm.warp(block.timestamp + duration - 1);
        geras.distributeGeras(geras.getArtifactToRewardFlow(address(root)));

        // vm.stopPrank();
        // assertEq(uint32(block.timestamp) - lastUp, duration, 'duration not exact');
        // assertEq(geras.getStakedAsset(builder), geras.totalSupply(), 'total staked incorrect');
        assertEq(amtStaked, geras.totalSupply(), 'total amt staked incorrect');

        uint expStartingGeras = (amtStaked * 32 / 1024) *(duration-1) / 31536000;

        assertEq(geras.vsaBalanceOf(address(rootRF)), expStartingGeras, 
            'expected starting Geras in root incorrect');

        vm.startPrank(owner);
        geras.payForward(address(root));
        vm.stopPrank();

        // This should actually be the same since root does not have a default allocation.
        uint availableGeras = rootRF.availableReward();
        vm.warp(block.timestamp + duration);

        // vm.startPrank(owner);
        geras.payForward(address(root));
        // vm.stopPrank();

        vouchAmt = hnr.vouch(address(root), newA, amount / 1000);

        uint builderRootVouch = root.balanceOf(builder);
        uint accbuilderRootVouch = root.accRewardClaim(builder);
        uint accTotalRootVouch = root.accRewardClaim(address(root));

        assertEq(accbuilderRootVouch, accTotalRootVouch, 'acc vouch in root incorrect');

        assertEq(geras.vsaBalanceOf(newRF), availableGeras * accbuilderRootVouch / (8*accTotalRootVouch) * 128/255, 
            'expected Geras in new address incorrect');

        assertEq(geras.vsaBalanceOf(address(rootRF)), expStartingGeras- availableGeras * accbuilderRootVouch / (8*accTotalRootVouch) * 128/255 , 
            'expected Geras in root address incorrect');
    }

    function testHonorStaking(uint amount, uint mockAmt, uint32 duration) public {

        amount = bound(amount, 0.00001 ether, 100 ether);
        mockAmt = bound(mockAmt, 0.001 ether, 100 ether);
        duration = uint32(bound(duration, 1000, 1000000));

        mockERC.transfer(address(geras), mockAmt);
        geras.stakeAsset(address(root));

        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA', true);

        // Will be minted at an annual rate.
        uint farmedHonor = (SafeMath.floorSqrt(geras.totalSupply()) << 35);
        farmedHonor = duration * farmedHonor / 31536000;

        vm.warp(block.timestamp + duration);
        uint accHnrHours = duration * hnr.balanceOf(address(newA)) / 7776000;
        uint expectedBuilderV = SafeMath.floorCbrt(accHnrHours) * 2**40;
        uint newvouchAmt = hnr.vouch(address(root), newA, 0.0001 ether);
        uint preMintHnr = hnr.balanceOf(address(root));

        hnr.mintToStakers();
        uint mintPool = hnr.stakingMintPool();
        assertEq(mintPool, farmedHonor, 'farmed honor incorrect');
        hnr.mintToStaker();

        emit log_uint(hnr.balanceOfArtifact(address(root), builder));
        emit log_uint(hnr.balanceOfArtifact(address(newA),  address(808)));
        emit log_uint(Artifact(newA).balanceOf(builder));
        // emit log_uint(geras.mintHonorClaim.call(builder));

        assertEq(hnr.balanceOfArtifact(address(newA), address(808)), expectedBuilderV);

        uint rootHonor = hnr.balanceOf(address(root));

        assertEq(rootHonor, preMintHnr + farmedHonor, 
            'staked hnr reward incorrect');

        assertEq(hnr.totalSupply(), rootHonor + hnr.balanceOf(address(newA)), 
            'total hnr supply incorrect');

        geras.unstakeAsset(address(root), mockAmt);
        assertEq(geras.totalSupply(), 0, 'leftover VSR');
        assertEq(mockERC.balanceOf(builder), 10000 ether, 'missing ERC');

    }


    function testGerasRotation(uint amount, uint mockAmt, uint32 duration) public {
        vm.assume(mockAmt < 100 ether);
        amount = bound(amount, 0.00001 ether, 49 ether);
        mockAmt = bound(mockAmt, 0.00001 ether, 100 ether);
        duration = uint32(bound(duration, 1000, 1000000));

        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(10711315), 'newA', true);
        vm.prank(builder);
        address newB = hnr.proposeArtifact(address(root), address(808), 'newB', true);

        assertEq(hnr.balanceOf(address(root)), 9998 ether, 'proposal Honor incorrect');

        uint rootVouch = root.balanceOf(builder);

        mockERC.transfer(address(geras), mockAmt);
        geras.stakeAsset(address(root));

        uint amtStaked = geras.totalSupply();
        uint lastUp = geras.lastUpdated();

        uint vouchAmt = hnr.vouch(address(root), newA, amount);
        hnr.vouch(address(root), newB, amount);

        // This may not equal mockAmt due to the rebase mechanism...
        assertEq(amtStaked, mockERC.balanceOf(address(geras)), 'expected VSA incorrect');

        address newRF = (rfact.createRewardFlow(address(hnr), newA, address(geras)));
        address newRFB = (rfact.createRewardFlow(address(hnr), newB, address(geras)));


        rootRF.submitAllocation(newRF, 128, owner);
        RewardFlow(newRF).submitAllocation(newRFB, 128, owner);
        uint startingTime = block.timestamp;
        vm.warp(block.timestamp + duration - 1);
        geras.distributeGeras(address(rootRF));

        // assertEq(uint32(block.timestamp) - lastUp, duration, 'duration not exact');

        // assertEq(geras.getStakedAsset(builder), geras.totalSupply(), 'total staked incorrect');
        assertEq(amtStaked, geras.totalSupply(), 'total amt staked incorrect');

        uint expStartingGeras = (amtStaked  * 32 / 1024) * (duration-1) / 31536000;

        assertEq(geras.vsaBalanceOf(address(rootRF)), expStartingGeras, 
            'expected starting Geras in root incorrect');

        vm.warp(block.timestamp + duration);

        rootRF.payForward();
        // This should actually be the same since root does not have a default allocation.
        uint availableGeras = rootRF.availableReward();

        rootRF.payForward();
        vm.prank(builder);
        vouchAmt = hnr.vouch(address(root), newA, amount / 1000);

        uint builderRootVouch = root.balanceOf(builder);
        uint accbuilderRootVouch = root.accRewardClaim(builder);
        uint accTotalRootVouch = root.accRewardClaim(address(root));

        assertEq(accbuilderRootVouch, accTotalRootVouch, 'acc vouch in root incorrect');

        // assertEq(geras.vsaBalanceOf(newRF), availableGeras/ 8 * 128/255 * builderRootVouch / root.totalSupply(), 
        //     'expected Geras in new address incorrect');
        assertEq(geras.vsaBalanceOf(newRF), availableGeras/ 8 * 128/255 * accbuilderRootVouch / accTotalRootVouch, 
            'expected Geras in new address incorrect');

        assertEq(geras.vsaBalanceOf(address(rootRF)), expStartingGeras- availableGeras / 8* 128/255 * builderRootVouch / root.totalSupply(), 
            'expected Geras in root address incorrect');

        vm.warp(block.timestamp + duration - 1);

        if (RewardFlow(newRF).nextAllocator() == newRF) {
            RewardFlow(newRF).payForward();
        }
        RewardFlow(newRF).receiveVSR();
        uint newExpectedGerasA = geras.vsaBalanceOf(newRF);
        uint availableGerasA = RewardFlow(newRF).availableReward();
        vm.warp(block.timestamp + duration);
        RewardFlow(newRF).payForward();

        // assertEq(availableGerasA, RewardFlow(newRF).availableReward(), 'availableRewardA');
        
        vm.prank(builder);
        hnr.vouch(address(root), newB, amount / 1000);
        uint builderVouchA = Artifact(newA).balanceOf(builder);
        // assertEq(builderVouchA, Artifact(newA).totalSupply(), 'new artifact builder vouch');
        uint accbuilderVouchA = Artifact(newA).accRewardClaim(builder);
        uint accTotalVouchA = Artifact(newA).accRewardClaim(newA);
        uint accbuilderAVouchA = Artifact(newA).accRewardClaim(address(10711315));

        // assertEq(accbuilderVouchA + accbuilderAVouchA, accTotalVouchA, 
        //     'acc vouch in newA incorrect');

        assertEq(geras.vsaBalanceOf(newRFB), availableGerasA *  accbuilderVouchA / (8* accTotalVouchA) *128 / 255 , 
            'expected Geras in third address incorrect');

        assertEq(geras.vsaBalanceOf(newRF), newExpectedGerasA- availableGerasA *  accbuilderVouchA / (8*accTotalVouchA) *128 /255, 
            'expected Geras in middle address incorrect');

    }
}

