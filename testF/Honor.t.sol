pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Honor} from "../contracts/Honor.sol";
import {Artifact} from "../contracts/Artifact.sol";
// import {HonorFactory} from "../contracts/HonorFactory.sol";
import {Artifactory} from "../contracts/Artifactory.sol";
import {MockCoin} from "../contracts/MockCoin.sol";
import {SafeMath} from "../contracts/SafeMath.sol";

contract HonorTest is Test {
    Honor public hnr;
    Artifactory public afact;
    Artifact public root;

    function setUp() public {
        // HonorFactory hfact = new HonorFactory();
        afact = new Artifactory();
        MockCoin mockERC = new MockCoin();
        // hnr = Honor(hfact.createHonor(address(afact), address(mockERC), 
        //     'TEST_HONOR'));
        hnr = new Honor(address(afact), address(mockERC), 'TEST_HONOR');

        root = Artifact(hnr.rootArtifact());

    }

    function testAddInitial() public {
        address builder = root.builder();

        assertEq(hnr.name(), 'TEST_HONOR');
        assertEq(hnr.owner(), builder);
        assertEq(hnr.balanceOf(address(root)), 10000 ether);
        assertEq(hnr.balanceOfArtifact(address(root), builder), SafeMath.floorSqrt(10000 ether) * (2 ** 30));
    }


    function testVouch(uint amount) public {
        vm.assume(amount < 100 ether);
        vm.assume(amount > 0.00001 ether);
        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA');

        assertEq(hnr.balanceOf(address(root)), 9999 ether, 'proposal Honor incorrect');

        uint rootVouch = root.balanceOf(builder);
        assertEq(rootVouch, root.totalSupply());
        uint rootBal = hnr.balanceOf(address(root));
        uint expectedHnrOut = rootBal - (rootBal * (rootVouch - amount) ** 2) / (root.totalSupply() ** 2);
        uint vouchAmt = hnr.vouch(address(root), newA, amount);

        assertEq(hnr.balanceOf(address(newA)), expectedHnrOut + 1 ether, 
            'expected HONOR in new address incorrect');
        assertEq(hnr.balanceOf(address(root)), 9999 ether - expectedHnrOut, 
            'expected HONOR in root incorrect');

    }

    function testBuilderChange(uint amount, uint32 duration) public {

        vm.assume(duration > 1000);
        vm.assume(duration < 1000000);


        vm.assume(amount < 100 ether);
        vm.assume(amount > 0.00001 ether);
        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA');


        vm.warp(block.timestamp + duration);
        uint accHnrHours = duration * hnr.balanceOf(address(newA)) / 7776000;
        uint expectedBuilderV = SafeMath.floorCbrt(accHnrHours) * 2**40;
        uint newvouchAmt = hnr.vouch(address(root), newA, 0.0001 ether);


        emit log_uint(hnr.balanceOfArtifact(address(root), builder));
        emit log_uint(hnr.balanceOfArtifact(address(newA),  address(808)));

        emit log_uint(Artifact(newA).balanceOf(builder));
        assertEq(hnr.balanceOfArtifact(address(newA), address(808)), expectedBuilderV);

    }



    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}

