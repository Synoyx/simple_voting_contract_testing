// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../src/Voting.sol";

/*
 * @author Julien P.
 */
contract ContractTest is Test {
    Voting voting;
    address voter1 = makeAddr("voter1");
    address voter2 = makeAddr("voter2");
    address voter3 = makeAddr("voter3");
    address owner = address(this);

    function setUp() public {
        voting = new Voting();
    }

    // *********** Getters *********** //

    function test_getOneProposalWithoutBeingVoter() public {
        vm.expectRevert("You're not a voter");
        voting.getOneProposal(1);
    }

    function test_getOneProposalWithInvalidValue() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationEnded
        );
        vm.prank(voter1);
        vm.expectRevert();
        voting.getOneProposal(40);
    }

    function test_getVoterWithoutBeingVoter() public {
        vm.expectRevert("You're not a voter");
        voting.getVoter(voter1);
    }

    // *********** Add voter *********** //

    function test_addVoter() public {
        voting.addVoter(owner);
        assertEq(voting.getVoter(owner).isRegistered, true);
    }

    function test_fuzz_addVoter(address fuzzedAddress) public {
        voting.addVoter(fuzzedAddress);

        // We use prank here because only voters can call 'getvoter()'
        vm.prank(fuzzedAddress);
        assertEq(voting.getVoter(fuzzedAddress).isRegistered, true);
    }

    function test_getVoterWithInvalidValue() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationEnded
        );
        vm.prank(voter1);
        assertEq(voting.getVoter(address(0)).isRegistered, false);
    }

    function test_addAlreadyRegisteredVoter() public {
        voting.addVoter(voter1);

        vm.expectRevert("Already registered");
        voting.addVoter(voter1);
    }

    function test_addVoterInWrongStatus() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationStarted
        );

        vm.expectRevert("Voters registration is not open yet");
        voting.addVoter(voter1);
    }

    /*
     * @dev See comment on method "checkOnlyOwnerRevert()" for why I used
     * a try/catch
     */
    function test_addVoterWithoutBeingOwner() public {
        vm.prank(voter1);

        try voting.addVoter(voter2) {
            assertEq(true, false);
        } catch (bytes memory errorMessage) {
            assertEq(
                Ownable.OwnableUnauthorizedAccount.selector,
                bytes4(errorMessage)
            );
        }
    }

    function test_addVoterEvent() public {
        vm.expectEmit();
        emit Voting.VoterRegistered(voter1);
        voting.addVoter(voter1);
    }

    // *********** Add proposal *********** //

    function test_addProposal() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationStarted
        );

        vm.startPrank(voter1);
        voting.addProposal("Proposal 2");

        assertEq(
            bytes("Proposal 2"),
            bytes(voting.getOneProposal(1).description)
        );
        vm.stopPrank();
    }

    function test_fuzz_addProposal(string calldata proposal) public {
        vm.assume(bytes(proposal).length > 0);

        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationStarted
        );

        vm.startPrank(voter1);
        voting.addProposal(proposal);

        assertEq(bytes(proposal), bytes(voting.getOneProposal(1).description));
        vm.stopPrank();
    }

    function test_addEmptyProposal() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationStarted
        );

        vm.prank(voter1);
        vm.expectRevert("Vous ne pouvez pas ne rien proposer");
        voting.addProposal("");
    }

    function test_addProposalInWrongWorkflowStatus() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationEnded
        );

        vm.prank(voter1);
        vm.expectRevert("Proposals are not allowed yet");
        voting.addProposal("Proposal 1");
    }

    function test_addProposalWithoutBeingVoter() public {
        vm.expectRevert("You're not a voter");
        voting.addProposal("Proposal 1");
    }

    function test_addProposalEvent() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationStarted
        );

        vm.prank(voter1);
        vm.expectEmit();
        emit Voting.ProposalRegistered(1);
        voting.addProposal("Proposal 1");
    }

    // *********** Add vote *********** //

    function test_setVote() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.VotingSessionStarted);

        vm.startPrank(voter1);
        voting.setVote(1);

        assertEq(voting.getVoter(voter1).hasVoted, true);
        assertEq(voting.getVoter(voter1).votedProposalId, 1);
        vm.stopPrank();
    }

    function test_setVoteWithInvalidId() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.VotingSessionStarted);

        vm.startPrank(voter1);
        vm.expectRevert("Proposal not found");
        voting.setVote(42424242);
    }

    function test_setVoteInWrongWorkflowStatus() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.VotingSessionEnded);

        vm.prank(voter1);
        vm.expectRevert("Voting session havent started yet");
        voting.setVote(0);
    }

    function test_setVoteTwice() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.VotingSessionStarted);

        vm.startPrank(voter1);
        voting.setVote(0);

        vm.expectRevert("You have already voted");
        voting.setVote(0);

        vm.stopPrank();
    }

    function test_setVoteEvent() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.VotingSessionStarted);

        vm.prank(voter1);
        vm.expectEmit();
        emit Voting.Voted(voter1, 0);
        voting.setVote(0);
    }

    function test_setVoteWithoutBeingVoter() public {
        vm.expectRevert("You're not a voter");
        voting.setVote(0);
    }

    // *********** Change workflow status *********** //

    function test_startProposalTimeWithoutBeingOwner() public {
        vm.prank(voter1);

        _checkOnlyOwnerRevert(voting.startProposalsRegistering);
    }

    function test_startProposalTimeInWrongWorkflowStatus() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationEnded
        );

        vm.expectRevert("Registering proposals cant be started now");
        voting.startProposalsRegistering();
    }

    function test_startProposalTimeEvent() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.RegisteringVoters);

        vm.expectEmit();
        emit Voting.WorkflowStatusChange(
            Voting.WorkflowStatus.RegisteringVoters,
            Voting.WorkflowStatus.ProposalsRegistrationStarted
        );
        voting.startProposalsRegistering();
    }

    function test_endProposalTimeWithoutBeingOwner() public {
        vm.prank(voter1);

        _checkOnlyOwnerRevert(voting.endProposalsRegistering);
    }

    function test_endProposalTimeInWrongWorkflowStatus() public {
        vm.expectRevert("Registering proposals havent started yet");
        voting.endProposalsRegistering();
    }

    function test_endProposalTimeEvent() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationStarted
        );

        vm.expectEmit();
        emit Voting.WorkflowStatusChange(
            Voting.WorkflowStatus.ProposalsRegistrationStarted,
            Voting.WorkflowStatus.ProposalsRegistrationEnded
        );
        voting.endProposalsRegistering();
    }

    function test_startVotingSessionWithoutBeingOwner() public {
        vm.prank(voter1);

        _checkOnlyOwnerRevert(voting.startVotingSession);
    }

    function test_startVotingSessionInWrongWorkflowStatus() public {
        vm.expectRevert("Registering proposals phase is not finished");
        voting.startVotingSession();
    }

    function test_startVotingSessionEvent() public {
        _setVotingInGivenStatus(
            Voting.WorkflowStatus.ProposalsRegistrationEnded
        );

        vm.expectEmit();
        emit Voting.WorkflowStatusChange(
            Voting.WorkflowStatus.ProposalsRegistrationEnded,
            Voting.WorkflowStatus.VotingSessionStarted
        );
        voting.startVotingSession();
    }

    function test_endVotingSessionWithoutBeingOwner() public {
        vm.prank(voter1);

        _checkOnlyOwnerRevert(voting.endVotingSession);
    }

    function test_endVotingSessionInWrongWorkflowStatus() public {
        vm.expectRevert("Voting session havent started yet");
        voting.endVotingSession();
    }

    function test_endVotingSessionEvent() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.VotingSessionStarted);

        vm.expectEmit();
        emit Voting.WorkflowStatusChange(
            Voting.WorkflowStatus.VotingSessionStarted,
            Voting.WorkflowStatus.VotingSessionEnded
        );
        voting.endVotingSession();
    }

    // *********** Tally *********** //

    function test_tallyVoteWithSingleProposal() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.VotesTallied);

        assertEq(voting.winningProposalID(), 1);
    }

    function test_tallyVoteWithMultipleProposals() public {
        voting.addVoter(voter2);
        voting.addVoter(voter3);
        _setVotingToStartProposal();
        vm.prank(voter1);
        voting.addProposal("Proposal2");
        _setVotingFromStartProposalToEndProposal();
        voting.startVotingSession();
        vm.prank(voter2);
        voting.setVote(2);
        vm.prank(voter3);
        voting.setVote(1);
        voting.endVotingSession();

        voting.tallyVotes();

        assertEq(voting.winningProposalID(), 1);
    }

    function test_tallyVoteWithTieVote() public {
        voting.addVoter(voter2);
        _setVotingToStartProposal();
        vm.prank(voter1);
        voting.addProposal("Proposal2");
        _setVotingFromStartProposalToEndProposal();
        voting.startVotingSession();
        vm.prank(voter2);
        voting.setVote(2);
        voting.endVotingSession();

        voting.tallyVotes();

        assertEq(voting.winningProposalID(), 2);
    }

    function test_tallyVotesWithoutBeingOwner() public {
        vm.prank(voter1);

        _checkOnlyOwnerRevert(voting.tallyVotes);
    }

    function test_tallyVotesInWrongWorkflowStatus() public {
        vm.expectRevert("Current status is not voting session ended");
        voting.tallyVotes();
    }

    function test_tallyVotesEvent() public {
        _setVotingInGivenStatus(Voting.WorkflowStatus.VotingSessionEnded);

        vm.expectEmit();
        emit Voting.WorkflowStatusChange(
            Voting.WorkflowStatus.VotingSessionEnded,
            Voting.WorkflowStatus.VotesTallied
        );
        voting.tallyVotes();
    }

    function test_tallyVoteWithoutVotes() public {
        _setVotingToStartProposal();
        _setVotingFromStartProposalToEndProposal();
        voting.startVotingSession();
        voting.endVotingSession();

        voting.tallyVotes();

        assertEq(voting.winningProposalID(), 0);
    }

    // *********** Helpers *********** //

    /*
     * @dev I used a try catch here, because Ownable use a custom error.
     * The problem with vm.expectRevert is that it compares the error as full byte array
     * to the given value in argument, and the selector of a custom error only gives the first 4 bytes.
     * As I didn't want to use the method with bytes(keccak256("MethodSignature")) because it's
     * pretty dirty, the try catch method is the solution.
     * I deliberatly used a failing assert in try part, as the test must fail if addVoter() doesn't revert.
     */
    function _checkOnlyOwnerRevert(function() external f) internal {
        try f() {
            assertEq(true, false);
        } catch (bytes memory errorMessage) {
            assertEq(
                Ownable.OwnableUnauthorizedAccount.selector,
                bytes4(errorMessage)
            );
        }
    }

    /*
     * @dev Helper method to put Voting in right state for testing purpose.
     */
    function _setVotingInGivenStatus(Voting.WorkflowStatus ws) internal {
        if (ws == Voting.WorkflowStatus.ProposalsRegistrationStarted) {
            _setVotingToStartProposal();
        } else if (ws == Voting.WorkflowStatus.ProposalsRegistrationEnded) {
            _setVotingToStartProposal();
            _setVotingFromStartProposalToEndProposal();
        } else if (ws == Voting.WorkflowStatus.VotingSessionStarted) {
            _setVotingToStartProposal();
            _setVotingFromStartProposalToEndProposal();
            voting.startVotingSession();
        } else if (ws == Voting.WorkflowStatus.VotingSessionEnded) {
            _setVotingToStartProposal();
            _setVotingFromStartProposalToEndProposal();
            voting.startVotingSession();
            _setVotingFromStartVotingToEndVoting();
        } else if (ws == Voting.WorkflowStatus.VotesTallied) {
            _setVotingToStartProposal();
            _setVotingFromStartProposalToEndProposal();
            voting.startVotingSession();
            _setVotingFromStartVotingToEndVoting();
            voting.tallyVotes();
        }
    }

    function _setVotingToStartProposal() internal {
        voting.addVoter(voter1);
        voting.startProposalsRegistering();
    }

    function _setVotingFromStartProposalToEndProposal() internal {
        vm.prank(voter1);
        voting.addProposal("Proposal 1");
        voting.endProposalsRegistering();
    }

    function _setVotingFromStartVotingToEndVoting() internal {
        vm.prank(voter1);
        voting.setVote(1);
        voting.endVotingSession();
    }
}
