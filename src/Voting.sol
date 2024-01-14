// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title A simple vote system, managed by an administrator, allowing registered users to make proposals and vote.
/// @author Julien P.
contract Voting is Ownable {
    
    /*************************************
    *              Structs               *
    **************************************/
    
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum  WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
    
    /*************************************
    *             Variables              *
    **************************************/

    WorkflowStatus public workflowStatus;
    Proposal[] proposalsArray;
    mapping (address => Voter) voters;
    uint public winningProposalID;

    /*************************************
    *              Events                *
    **************************************/

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    /*************************************
    *             Constructor            *
    **************************************/

    /// @notice Starts the Ownable pattern
    constructor() Ownable(msg.sender) {    }
    
    /*************************************
    *             Modifiers              *
    **************************************/

    /// @notice Checks if the given address belongs to the whitelist
    modifier onlyVoters() {
        require(voters[msg.sender].isRegistered, "You're not a voter");
        _;
    }
    
    /*************************************
    *             Functions              *
    **************************************/

    /** @notice 
        Get a voter by his address
        Trigger an error if this address isn't registered
    */
    /// @return Voter  The voter corresponding to the given address
    function getVoter(address _addr) external onlyVoters view returns (Voter memory) {
        return voters[_addr];
    }

    /** @notice 
        Get a proposal from the given id
        Return empty value if proposal doesn't exists
    */
    /// @return Proposal  The proposal corresponding to the given id
    function getOneProposal(uint _id) external onlyVoters view returns (Proposal memory) {
        return proposalsArray[_id];
    }

 

    /** @notice
        Adds a voter to the list
        Will trigger an error if the address has already been added to the whitelist
        Only the contract's owner can call this metho
    */
    /// @param _addr The address to add to the whitelist
    function addVoter(address _addr) external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, 'Voters registration is not open yet');
        require(voters[_addr].isRegistered != true, 'Already registered');
    
        voters[_addr].isRegistered = true;
        emit VoterRegistered(_addr);
    }
 

    /** @notice 
        Allows whitelisted users to make proposal, when the proposal registration is open, and if the given proposal isn't empty
        Only whitelisted voters can make a proposal
    */
    /// @param _desc The voter's proposal description
    function addProposal(string calldata _desc) external onlyVoters {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, 'Proposals are not allowed yet');
        require(keccak256(abi.encode(_desc)) != keccak256(abi.encode("")), 'Vous ne pouvez pas ne rien proposer'); // facultatif
        // voir que desc est different des autres

        Proposal memory proposal;
        proposal.description = _desc;
        proposalsArray.push(proposal);
        // proposalsArray.push(Proposal(_desc,0));
        emit ProposalRegistered(proposalsArray.length-1);
    }

    /** @notice 
        Allows whitelisted users to vote, when voting time is active, and if he has'nt already voted
        Proposal ids goes from 1 to 2^256.
        Only whitelisted voters can make a vote
    */
    /// @param _id The voter's proposal id vote
    function setVote( uint _id) external onlyVoters {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, 'Voting session havent started yet');
        require(voters[msg.sender].hasVoted != true, 'You have already voted');
        require(_id < proposalsArray.length, 'Proposal not found'); // pas obligé, et pas besoin du >0 car uint

        voters[msg.sender].votedProposalId = _id;
        voters[msg.sender].hasVoted = true;
        proposalsArray[_id].voteCount++;

        emit Voted(msg.sender, _id);
    }


    /** @notice 
        Checks if the workflow status is in the right state, then start the proposal time.
        Only the contract's owner can call this method
    */
    function startProposalsRegistering() external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, 'Registering proposals cant be started now');
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        
        Proposal memory proposal;
        proposal.description = "GENESIS";
        proposalsArray.push(proposal);
        
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /** @notice
        Checks if proposals registration are started, then stop it
        Only the contract's owner can call this method
    */
    function endProposalsRegistering() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, 'Registering proposals havent started yet');
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /** @notice 
        Checks if the workflow status is in the right state, then start the vote time
        Only the contract's owner can call this method
    */
    function startVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, 'Registering proposals phase is not finished');
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /** @notice 
        Checks if the vote time is started, then stop it
        Only the contract's owner can call this method
    */
    function endVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, 'Voting session havent started yet');
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }


    /** @notice 
        Checks if the workflow status is OK, compute the winning proposal from voters, and change the workflow status
        If there hasn't been any vote, or a tie vote, the last one on the list will be considered as the winning one
        Only the contract's owner can call this method
    */
    function tallyVotes() external onlyOwner {
       require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Current status is not voting session ended");
       uint _winningProposalId;
      for (uint256 p = 0; p < proposalsArray.length; p++) {
           if (proposalsArray[p].voteCount > proposalsArray[_winningProposalId].voteCount) {
               _winningProposalId = p;
          }
       }
       winningProposalID = _winningProposalId;
       
       workflowStatus = WorkflowStatus.VotesTallied;
       emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }
}
