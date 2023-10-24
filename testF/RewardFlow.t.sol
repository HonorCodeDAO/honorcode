pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Honor} from "../contracts/Honor.sol";
import {Artifact} from "../contracts/Artifact.sol";
// import {HonorFactory} from "../contracts/HonorFactory.sol";
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

    function setUp() public {
        // HonorFactory hfact = new HonorFactory();
        afact = new Artifactory();
        mockERC = new MockCoin();
        // hnr = Honor(hfact.createHonor(address(afact), address(mockERC), 
        //     'TEST_HONOR'));
        hnr = new Honor(address(afact), address(mockERC), 'TEST_HONOR');

        root = Artifact(hnr.rootArtifact());
        geras = new Geras(address(hnr));
        hnr.setGeras(address(geras));

        rfact = new RewardFlowFactory(address(hnr));
        rootRF = RewardFlow(rfact.createRewardFlow(address(root), address(geras)));

    }

    function testAddInitial() public {
        address builder = root.builder();

        assertEq(hnr.name(), 'TEST_HONOR');
        assertEq(hnr.owner(), builder);
        assertEq(hnr.balanceOf(address(root)), 10000 ether);
        assertEq(hnr.balanceOfArtifact(address(root), builder), SafeMath.floorSqrt(10000 ether) * (2 ** 30));
    }


    function testGerasDistribution(uint amount, uint mockAmt, uint32 duration) public {

        amount = bound(amount, 0.00001 ether, 100 ether);
        mockAmt = bound(mockAmt, 0.00001 ether, 100 ether);
        duration = uint32(bound(duration, 1000, 1000000));

        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA');

        assertEq(hnr.balanceOf(address(root)), 9999 ether, 'proposal Honor incorrect');

        uint rootVouch = root.balanceOf(builder);

        mockERC.transfer(address(geras), mockAmt);
        geras.stakeAsset(address(root));

        uint amtStaked = geras.totalVirtualStakedAsset();
        uint lastUp = geras.lastUpdated();

        uint vouchAmt = hnr.vouch(address(root), newA, amount);

        // This may not equal mockAmt due to the rebase mechanism...
        assertEq(amtStaked, mockERC.balanceOf(address(geras)), 'expected VSA incorrect');

        address newRF = (rfact.createRewardFlow(newA, address(geras)));

        rootRF.submitAllocation(newRF, 128);
        vm.warp(block.timestamp + duration);
        geras.distributeGeras(address(rootRF));

        assertEq(uint32(block.timestamp) - lastUp, duration, 'duration not exact');

        // assertEq(geras.getStakedAsset(builder), geras.totalVirtualStakedAsset(), 'total staked incorrect');
        assertEq(amtStaked, geras.totalVirtualStakedAsset(), 'total amt staked incorrect');

        uint expStartingGeras = amtStaked * duration * 32 / 1024 / 31536000 ;

        assertEq(geras.balanceOf(address(rootRF)), expStartingGeras, 
            'expected starting Geras in root incorrect');

        rootRF.payForward();
        // This should actually be the same since root does not have a default allocation.
        uint availableGeras = rootRF.availableReward();

        rootRF.payForward();
        vouchAmt = hnr.vouch(address(root), newA, amount / 1000);

        uint builderRootVouch = root.balanceOf(builder);
        uint accbuilderRootVouch = root.accRewardClaim(builder);
        uint accTotalRootVouch = root.accRewardClaim(address(root));

        assertEq(accbuilderRootVouch, accTotalRootVouch, 'acc vouch in root incorrect');

        assertEq(geras.balanceOf(newRF), availableGeras/ 8 * 128/255 * builderRootVouch / root.totalSupply(), 
            'expected Geras in new address incorrect');

        assertEq(geras.balanceOf(address(rootRF)), expStartingGeras- availableGeras / 8* 128/255 * builderRootVouch / root.totalSupply(), 
            'expected Geras in root address incorrect');
    }

    function testHonorStaking(uint amount, uint mockAmt, uint32 duration) public {

        amount = bound(amount, 0.00001 ether, 100 ether);
        mockAmt = bound(mockAmt, 0.01 ether, 100 ether);
        duration = uint32(bound(duration, 1000, 1000000));

        mockERC.transfer(address(geras), mockAmt);
        geras.stakeAsset(address(root));

        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA');

        // Will be minted at an annual rate.
        uint farmedHonor = (SafeMath.floorSqrt(geras.totalVirtualStakedAsset()) << 35);
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
    }


}

