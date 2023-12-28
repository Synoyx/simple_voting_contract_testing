const { expect } = require("chai");
const hre = require("hardhat");
const { PANIC_CODES } = require("@nomicfoundation/hardhat-chai-matchers/panic");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Voting contract", function () {
  const DEFAULT_PROPOSAL = "Proposal 1";
  const DEFAULT_PROPOSAL_ID = 1;
  let owner, voter1, voter2, voter3;
  let voting;

  beforeEach(async function () {
    voting = await ethers.deployContract("Voting");
    [owner, voter1, voter2, voter3] = await ethers.getSigners();
  });

  // *********** Get one proposal *********** //

  it("Get one proposal", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationEnded);

    expect((await voting.connect(voter1).getOneProposal(DEFAULT_PROPOSAL_ID)).description).to.equal(DEFAULT_PROPOSAL);
  });

  it("Get one proposal with invalid value", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationEnded);

    await expect(voting.connect(voter1).getOneProposal(424242)).to.be.revertedWithPanic(PANIC_CODES.ARRAY_ACCESS_OUT_OF_BOUNDS);
  });

  it("Get one proposal without being voter", function () {
    expect(voting.getOneProposal()).to.be.rejectedWith("You're not a voter");
  });

  it("Should add a voter", async function () {
    await voting.addVoter(voter1);

    expect((await voting.connect(voter1).getVoter(voter1)).isRegistered).to.equal(true);
  });

  // *********** Get one voter *********** //

  it("Get voter", async function () {
    await voting.addVoter(voter1);
    await voting.addVoter(voter3);

    expect((await voting.connect(voter1).getVoter(voter1)).isRegistered).to.equal(true);
    expect((await voting.connect(voter1).getVoter(voter2)).isRegistered).to.equal(false);
    expect((await voting.connect(voter1).getVoter(voter3)).isRegistered).to.equal(true);
  });

  it("Get voter without being voter", async function () {
    await expect(voting.getVoter(voter1)).to.be.revertedWith("You're not a voter");
  });

  // *********** Add voter *********** //

  it("Add voter", async function () {
    await voting.addVoter(owner);
    expect((await voting.getVoter(owner)).isRegistered).to.equal(true);
  });

  it("Add already registered voter", async function () {
    await voting.addVoter(voter1);

    await expect(voting.addVoter(voter1)).to.be.revertedWith("Already registered");
  });

  it("Add voter in wrong status", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationStarted);

    await expect(voting.addVoter(voter2)).to.be.revertedWith("Voters registration is not open yet");
  });

  it("Add voter without being owner", async function () {
    await expect(voting.connect(voter1).addVoter(voter2))
      .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
      .withArgs(voter1);
  });

  it("Add voter event", async function () {
    await expect(voting.addVoter(voter1)).to.emit(voting, "VoterRegistered").withArgs(voter1);
  });

  // *********** Add proposal *********** //

  it("Add proposal", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationStarted);

    await voting.connect(voter1).addProposal("New proposal");
    expect((await voting.connect(voter1).getOneProposal(1)).description).to.equal("New proposal");
  });

  it("Add empty proposal", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationStarted);

    await expect(voting.connect(voter1).addProposal("")).to.be.revertedWith("Vous ne pouvez pas ne rien proposer");
  });

  it("Add proposal in wrong workflow status", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationEnded);

    await expect(voting.connect(voter1).addProposal("New proposal")).to.be.revertedWith("Proposals are not allowed yet");
  });

  it("Add proposal without being voter", async function () {
    await expect(voting.addProposal("New proposal")).to.be.revertedWith("You're not a voter");
  });

  it("Add proposal event", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationStarted);

    await expect(voting.connect(voter1).addProposal("New proposal")).to.emit(voting, "ProposalRegistered").withArgs(1);
  });

  // *********** Add vote *********** //

  it("Set vote", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionStarted);

    await voting.connect(voter1).setVote(DEFAULT_PROPOSAL_ID);

    expect((await voting.connect(voter1).getVoter(voter1)).hasVoted).to.equal(true);
    expect((await voting.connect(voter1).getVoter(voter1)).votedProposalId).to.equal(DEFAULT_PROPOSAL_ID);
  });

  it("Set vote with invalid id", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionStarted);

    await expect(voting.connect(voter1).setVote(42424242)).to.be.revertedWith("Proposal not found");
  });

  it("Set vote in wrong workflow status", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionEnded);

    await expect(voting.connect(voter1).setVote(DEFAULT_PROPOSAL_ID)).to.be.revertedWith("Voting session havent started yet");
  });

  it("Set vote twice", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionStarted);

    await voting.connect(voter1).setVote(DEFAULT_PROPOSAL_ID);

    await expect(voting.connect(voter1).setVote(DEFAULT_PROPOSAL_ID)).to.be.revertedWith("You have already voted");
  });

  it("Set vote without being voter", async function () {
    await expect(voting.setVote(DEFAULT_PROPOSAL_ID)).to.be.revertedWith("You're not a voter");
  });

  it("Set vote event", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionStarted);

    await expect(voting.connect(voter1).setVote(DEFAULT_PROPOSAL_ID)).to.emit(voting, "Voted").withArgs(voter1, DEFAULT_PROPOSAL_ID);
  });

  // *********** Change workflow status *********** //
  // *********** Start proposal time *********** //

  it("Start proposal time", async function () {
    await voting.startProposalsRegistering();

    expect(await voting.workflowStatus()).to.equal(WorkflowStatus.ProposalsRegistrationStarted);
  });

  it("Start proposal time in wrong workflow status", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationEnded);

    await expect(voting.startProposalsRegistering()).to.be.revertedWith("Registering proposals cant be started now");
  });

  it("Start proposal time without being owner", async function () {
    await expect(voting.connect(voter1).startProposalsRegistering())
      .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
      .withArgs(voter1);
  });

  it("Start proposal time event", async function () {
    await expect(voting.startProposalsRegistering())
      .to.emit(voting, "WorkflowStatusChange")
      .withArgs(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
  });

  // *********** End proposal time *********** //
  it("End proposal time", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationStarted);

    await voting.endProposalsRegistering();
    expect(await voting.workflowStatus()).to.equal(WorkflowStatus.ProposalsRegistrationEnded);
  });

  it("End proposal time in wrong workflow status", async function () {
    await expect(voting.endProposalsRegistering()).to.be.revertedWith("Registering proposals havent started yet");
  });

  it("End proposal time without being owner", async function () {
    await expect(voting.connect(voter1).endProposalsRegistering())
      .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
      .withArgs(voter1);
  });

  it("End proposal time event", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationStarted);

    await expect(voting.endProposalsRegistering())
      .to.emit(voting, "WorkflowStatusChange")
      .withArgs(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
  });

  // *********** Start voting session *********** //
  it("Start voting session", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationEnded);

    await voting.startVotingSession();
    expect(await voting.workflowStatus()).to.equal(WorkflowStatus.VotingSessionStarted);
  });

  it("Start voting session with wrong workflow status", async function () {
    await expect(voting.startVotingSession()).to.be.revertedWith("Registering proposals phase is not finished");
  });

  it("Start voting session without being owner", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationEnded);

    await expect(voting.connect(voter1).startVotingSession())
      .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
      .withArgs(voter1);
  });

  it("Start voting session event", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.ProposalsRegistrationEnded);

    await expect(voting.startVotingSession())
      .to.emit(voting, "WorkflowStatusChange")
      .withArgs(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
  });

  // *********** End voting session *********** //

  it("End voting session", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionStarted);
    await voting.endVotingSession();

    expect(await voting.workflowStatus()).to.equal(WorkflowStatus.VotingSessionEnded);
  });

  it("End voting session in wrong workflow status", async function () {
    await expect(voting.endVotingSession()).to.be.revertedWith("Voting session havent started yet");
  });

  it("End voting session without being owner", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionStarted);

    await expect(voting.connect(voter1).endVotingSession())
      .to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount")
      .withArgs(voter1);
  });

  it("End voting session event", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionStarted);

    await expect(voting.endVotingSession())
      .to.emit(voting, "WorkflowStatusChange")
      .withArgs(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
  });

  // *********** Tally *********** //
  it("Tally vote with single proposal", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotesTallied);

    expect(await voting.winningProposalID()).to.equal(DEFAULT_PROPOSAL_ID);
  });

  it("Tally vote with multiple proposals", async function () {
    await voting.addVoter(voter2);
    await voting.addVoter(voter3);
    await _setVotingToStartProposal();
    await voting.connect(voter1).addProposal("Proposal2");
    await _setVotingFromStartProposalToEndProposal(); // It adds a default proposal which will here get the id 2
    await voting.startVotingSession();
    await voting.connect(voter2).setVote(2);
    await voting.connect(voter3).setVote(1);
    await _setVotingFromStartVotingToEndVoting(); // Adds a default vote on proposal 1

    await voting.tallyVotes();

    expect(await voting.winningProposalID()).to.equal(1);
  });

  it("Tally vote with tie vote", async function () {
    await voting.addVoter(voter2);
    await _setVotingToStartProposal();
    await voting.connect(voter1).addProposal("Proposal2");
    await _setVotingFromStartProposalToEndProposal(); // It adds a default proposal which will here get the id 2
    await voting.startVotingSession();
    await voting.connect(voter2).setVote(2);
    await _setVotingFromStartVotingToEndVoting(); // Adds a default vote on proposal 1

    await voting.tallyVotes();

    expect(await voting.winningProposalID()).to.equal(1);
  });

  it("Tally votes without votes", async function () {
    await _setVotingToStartProposal();
    await _setVotingFromStartProposalToEndProposal();
    await voting.startVotingSession();
    await voting.endVotingSession();

    await voting.tallyVotes();

    expect(await voting.winningProposalID()).to.equal(0);
  });

  it("Tally votes without being owner", async function () {
    await expect(voting.connect(voter1).tallyVotes()).to.be.revertedWithCustomError(voting, "OwnableUnauthorizedAccount").withArgs(voter1);
  });

  it("Tally votes in wrong workflow status", async function () {
    await expect(voting.tallyVotes()).to.be.revertedWith("Current status is not voting session ended");
  });

  it("Tally votes event", async function () {
    await _setVotingInGivenStatus(WorkflowStatus.VotingSessionEnded);

    await expect(voting.tallyVotes())
      .to.emit(voting, "WorkflowStatusChange")
      .withArgs(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
  });

  const WorkflowStatus = {
    RegisteringVoters: 0,
    ProposalsRegistrationStarted: 1,
    ProposalsRegistrationEnded: 2,
    VotingSessionStarted: 3,
    VotingSessionEnded: 4,
    VotesTallied: 5,
  };

  async function _setVotingInGivenStatus(ws) {
    if (ws >= WorkflowStatus.ProposalsRegistrationStarted) {
      await _setVotingToStartProposal();
    }
    if (ws >= WorkflowStatus.ProposalsRegistrationEnded) {
      await _setVotingFromStartProposalToEndProposal();
    }
    if (ws >= WorkflowStatus.VotingSessionStarted) {
      await voting.startVotingSession();
    }
    if (ws >= WorkflowStatus.VotingSessionEnded) {
      await _setVotingFromStartVotingToEndVoting();
    }
    if (ws >= WorkflowStatus.VotesTallied) {
      await voting.tallyVotes();
    }
  }

  async function _setVotingToStartProposal() {
    await voting.addVoter(voter1);
    await voting.startProposalsRegistering();
  }

  async function _setVotingFromStartProposalToEndProposal() {
    await voting.connect(voter1).addProposal(DEFAULT_PROPOSAL);
    await voting.endProposalsRegistering();
  }

  async function _setVotingFromStartVotingToEndVoting() {
    await voting.connect(voter1).setVote(DEFAULT_PROPOSAL_ID);
    await voting.endVotingSession();
  }
});
