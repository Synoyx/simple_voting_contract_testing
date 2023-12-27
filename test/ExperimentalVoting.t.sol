// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "../src/Voting.sol";

/*
 * @author Julien P.
 * @dev See comment of method "_setVotingInGivenWorkflowStatus" for why this contracts herits from Voting
 */
contract ExperimentalVotingTest is Test, Voting {
    address voter1 = makeAddr("Voter 1");

    function setUp() public {
        vm.startPrank(owner());
    }

    /*
    * @dev
    *   As this contract herit from Voting, I can here easily change the value of workflowStatus variable.
    *   This may be really usefull to be able to change almost all variables (except private, const & immutable) directly 
    *   instead of using exposed methods, for testing purpose.
    *
    
    */
    function _setVotingInGivenWorkflowStatus(WorkflowStatus ws) internal {
        workflowStatus = ws;
    }

    /*
    * @dev
    *   Here, due to the fact that this contract herits from Voting, I can realize some asserts that I couldn't otherwise,
    *   like asserting directly on internal variables.
    */
    function testExperimental_fuzz_addProposal(string[] memory newProposals) public {
        uint expectedProposalsAdded = newProposals.length;

        this.addVoter(voter1);
        _setVotingInGivenWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted);

        vm.startPrank(voter1);
        for(uint i; i < newProposals.length; i++) {
            if (bytes(newProposals[i]).length == 0) { // Ignoring empty proposals, as the test case isn't designed to test that
                expectedProposalsAdded--;
                continue;
            } 
            this.addProposal(newProposals[i]);
        }

        assertEq(proposalsArray.length, expectedProposalsAdded);
    }



    /*
    * @dev
    *   During my testings, I needed to pass a function as a parameter, to avoid boiler plate code.
    *   It appears that it isn't common in solidity, so I found interesting to put this here (and I used it in VotingTest)
    */
    function testExperimental_functionAsParameter() public {
        // We can store the function as a variable, or pass it direcly as a parameter of a method
        function() internal functionThatFail = demoFunctionAsParameter;

        expectARevert(functionThatFail);
    }

    function expectARevert(function() internal f) internal {
        vm.expectRevert("Error message ...");
        f();
    }

    function demoFunctionAsParameter() internal pure {
        revert("Error message ...");
    }



    /*
     * @dev 
     *  For some reasons, you could want to test if the error message contains, starts or ends by some strings.
     *  expectRevert() doesn't allow you to do that, but there is a workaround to do that with try/catch, as shown below.
     *
     *  Here for the demo, I made a case where you would want to check if the error is a Ownable error without 
     *  giving the address as parameter. 
     *  As the name of the custom error is encoded on the first bytes, you need to "cut" the error message to keep only the beginning, 
     *  and ignoring the parameters that are on the following bytes
     *
     *  In the Voting.t.sol file, I used another method with "abi.encodeWithSelector", that allows me to generate the 'full' custom
     *  error with the custom error selector & the parameter, allowing me to use vm.expectRevert
     */
    function _checkOnlyOwnerRevertExperimental(function() external f) internal {
        try f() {
            assertEq(true, false); // Using a failed assert here to fail the test is the Ownable custom error doesn't appears
        } catch (bytes memory errorMessage) {
            assertEq(
                Ownable.OwnableUnauthorizedAccount.selector,
                bytes4(errorMessage)
            );
        }
    }

    /*
    * @dev Used case of "_checkOnlyOwnerRevertExperimental" demo
    */
    function testExperimental_startProposalTimeWithoutBeingOwner() public {
        vm.stopPrank();
        vm.prank(voter1);
        _checkOnlyOwnerRevertExperimental(this.startProposalsRegistering);
    }
}