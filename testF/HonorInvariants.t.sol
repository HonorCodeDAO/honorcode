pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Honor} from "../contracts/Honor.sol";
import {HonorFactory} from "../contracts/HonorFactory.sol";
import {HonorHandler} from "./handlers/HonorHandler.sol";
import {RewardFlowHandler} from "./handlers/RewardFlowHandler.sol";
import {Geras} from "../contracts/Geras.sol";
import {Artifact} from "../contracts/Artifact.sol";
import {Artifactory} from "../contracts/Artifactory.sol";
import {MockCoin} from "../contracts/MockCoin.sol";
import {RewardFlow, RewardFlowFactory} from "../contracts/RewardFlow.sol";
import {IRewardFlow} from "../interfaces/IRewardFlow.sol";
import {IArtifact} from "../interfaces/IArtifact.sol";


contract InvariantHonorTest is Test {
    /// forge-config: default.invariant.depth = 25
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.fail_on_revert = true

    Honor public hnr;
    Artifactory public afact;
    Artifact public root;
    Geras public geras;
    RewardFlow public rootRF;
    RewardFlowFactory public rfact;
    MockCoin public mockERC;
    RewardFlowHandler public rfH;
    HonorHandler public hnrH;
    address public staker;

    function setUp() public {
        afact = new Artifactory();
        staker = address(555);
        vm.startPrank(staker);
        mockERC = new MockCoin();
        vm.stopPrank();

        // hnr = new Honor(address(afact), 'TEST_HONOR');

        HonorFactory hfact = new HonorFactory();
        hnr = Honor(hfact.createHonor(address(afact), 'TEST_HONOR'));

        root = Artifact(hnr.rootArtifact());
        geras = new Geras(address(hnr), address(mockERC));
        hnr.setGeras(address(geras));

        vm.startPrank(staker);
        mockERC.transfer(address(geras), 100 ether);
        geras.stakeAsset(address(root));
        vm.stopPrank();

        address newA = hnr.proposeArtifact(address(root), address(3), 'A', true);
        address newB = hnr.proposeArtifact(address(root), address(7), 'B', true);

        rfact = new RewardFlowFactory();
        hnr.setRewardFlowFactory(address(rfact));
        geras.setRewardFlowFactory(address(rfact));
        rootRF = RewardFlow(rfact.createRewardFlow(address(hnr), address(root), address(geras)));

        address rootRFA = address(RewardFlow(rfact.createRewardFlow(address(hnr), newA, address(geras))));
        address rootRFB = address(RewardFlow(rfact.createRewardFlow(address(hnr), newB, address(geras))));

        address[3] memory artifacts = [address(root), newA, newB];
        address[3] memory flows = [address(rootRF), rootRFA, rootRFB];

        vm.warp(block.timestamp + 1000);
        geras.distributeGeras(address(rootRF));

        uint stakeRate = geras.stakedToVsaRate();

        uint totalClaimsERC = geras.totalVSASupply() + geras.totalSupply();
        hnrH = new HonorHandler(hnr, artifacts);
        targetContract(address(hnrH));
        rfH = new RewardFlowHandler(flows, address(geras), hnr.owner());
        targetContract(address(rfH));

    }

    function invariant_GerasBalance() public {
        uint gBalance;
        uint rfBalance;
        for (uint i; i < 3; i++) {
            gBalance += geras.vsaBalanceOf(rfH.rfs(i));
            IRewardFlow(rfH.rfs(i)).receiveVSR();
            rfBalance += IRewardFlow(rfH.rfs(i)).totalGeras();
            assertEq(geras.vsaBalanceOf(rfH.rfs(i)), 
                IRewardFlow(rfH.rfs(i)).totalGeras(), new string(i));
        }
        assertEq(gBalance, geras.totalVSASupply(), 'RF geras imbalance');
        assertEq(rfBalance, geras.totalVSASupply(), 'RF totalgeras imbalance');

        if (geras.getLastUpdated(address(geras)) != block.timestamp) {
            geras.distributeGeras(rfH.rfs(0));
        }

        uint stakeRate = geras.stakedToVsaRate();
        assertGe((mockERC.balanceOf(address(geras)) * stakeRate) >> 60, mockERC.balanceOf(address(geras)), 'stake rate');
        assertEq(geras.totalVSASupply(), // / stakeRate , 
            (((mockERC.balanceOf(address(geras)) * stakeRate) >> 60)) - mockERC.balanceOf(address(geras)), 'vsa supply');

        uint totalClaimsERC = geras.totalVSASupply() + geras.totalSupply();

        assertEq((mockERC.balanceOf(address(geras)) * stakeRate) >> 60, 
            totalClaimsERC, 'staking claims imbalance');
    }

    function invariant_HonorBalance() public {
        uint hnrBalance;
        uint aBalance;
        uint aSupply;
        for (uint i; i < hnrH.artifactCount(); i++) {
            hnrBalance += hnr.balanceOf(hnrH.knownArtifacts(i));
            aBalance += IArtifact(hnrH.knownArtifacts(i)).honorWithin();
            aSupply += IArtifact(hnrH.knownArtifacts(i)).totalSupply();
        }
        assertEq(hnrBalance, hnr.totalSupply(), 'honor imbalance');
        assertEq(aBalance, hnr.totalSupply(), 'Artifact honorWithin imbalance');
        assertGe(10, hnrH.artifactCount(), 'artifact count exceeds 10');
        assertGe(aSupply, 100 ether, 'artifact vouch supply below threshold');
    }




}