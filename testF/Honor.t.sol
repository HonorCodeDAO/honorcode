pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Honor} from "../contracts/Honor.sol";
import {Artifact} from "../contracts/Artifact.sol";
import {HonorFactory} from "../contracts/HonorFactory.sol";
import {Artifactory} from "../contracts/Artifactory.sol";
import {SafeMath} from "../contracts/SafeMath.sol";

contract HonorTest is Test {
    Honor public hnr;
    Artifactory public afact;
    Artifact public root;

    function setUp() public {
        afact = new Artifactory();
        // hnr = new Honor(address(afact), 'TEST_HONOR');
        HonorFactory hfact = new HonorFactory();
        hnr = Honor(hfact.createHonor(address(afact), 'TEST_HONOR'));

        root = Artifact(hnr.rootArtifact());

    }

    function testAddInitial() public {
        address builder = root.builder();

        assertEq(hnr.name(), 'TEST_HONOR', 'name incorrect');
        assertEq(hnr.owner(), builder, 'Owner != root');
        assertEq(hnr.balanceOf(address(root)), 10000 ether, 'Mint amt incorrect');
        assertEq(hnr.balanceOfArtifact(address(root), builder), SafeMath.floorSqrt(10000 ether) * (2 ** 30), 'root claim incorrect');
    }


    function testVouch(uint amount) public {
        vm.assume(amount < 100 ether);
        vm.assume(amount > 0.00001 ether);
        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA', false);

        hnr.validateArtifact(address(root), newA);
        assertEq(hnr.balanceOf(address(root)), 9998 ether, 'proposal Honor incorrect');

        uint rootVouch = root.balanceOf(builder);
        assertEq(rootVouch, root.totalSupply());
        uint rootBal = hnr.balanceOf(address(root));

        uint unvouchAmt = root.vouchAmtPerHonor(amount);
        uint revouchAmt = hnr.vouch(address(root), newA, amount, true);
        uint expectedHnrOut = rootBal - (rootBal * (rootVouch - unvouchAmt) ** 2) / (root.totalSupply() ** 2);

        assertEq(hnr.balanceOf(address(newA)), amount + 2 ether, 
            'expected HONOR in new address incorrect');
        assertEq(hnr.balanceOf(address(root)), 9998 ether - amount, 
            'expected HONOR in root incorrect');

        assertEq(root.totalSupply(), rootVouch - unvouchAmt, 
            'expected root Vouch incorrect');
    }

    function testBuilderChange(uint amount, uint32 duration) public {

        vm.assume(duration > 1000);
        vm.assume(duration < 1000000);

        vm.assume(amount < 100 ether);
        vm.assume(amount > 0.00001 ether);
        address builder = root.builder();
        vm.prank(builder);
        address newA = hnr.proposeArtifact(address(root), address(808), 'newA', true);

        vm.warp(block.timestamp + duration);
        uint accHnrHours = duration * hnr.balanceOf(address(newA)) / 7776000;
        uint expectedBuilderV = SafeMath.floorCbrt(((accHnrHours>> 30) << 30)) * 2**40;
        uint newvouchAmt = hnr.vouch(address(root), newA, 0.0001 ether, true);


        emit log_uint(hnr.balanceOfArtifact(address(root), builder));
        emit log_uint(hnr.balanceOfArtifact(address(newA),  address(808)));

        emit log_uint(Artifact(newA).balanceOf(builder));
        assertEq(hnr.balanceOfArtifact(address(newA), address(808)), expectedBuilderV);

    }

}

