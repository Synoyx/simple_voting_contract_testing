![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white) ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)

# simple_voting_contract_testing

Second project for Alyra's course : testing of the simple_voting_contract.

I decided to create a separate project, as the testing project must use Alyra's code as base for testing.
The repo contains 2 files :

- test/Voting.t.sol : the file to be reviewed, containing all the unit tests for the exercise
- test/ExperimentalVoting.t.sol : file containing some interestings things that I found when I worked on the exercise.
  Just here to share some infos, it is not part of the exercise that is performed.
  I ignored the tests of this file with a line in foundry.toml

### Voting.t.sol

The unit test context is pretty simple :

- On each test, I 'reset' the voting instance, with setUp() method.
- I use 4 addresses during my tests :
  - The owner, which is in this case the ContractTest's address. I let it by default, because Voting smart contract doesn't contain any method that can't be called by another contract, like call() for example
  - Voters 1, 2 and 3, that I use for my different test. Voter 1 always is the default voter used for every test, mostly in my helpers methods (see below)
- As I can't modify the workflow status directly, and to avoid boiler plate code, I made a helper function \_setVotingInGivenStatus(Voting.WorkflowStatus ws), that allows me to set up the context for my tests with only 1 line of code. The only downside is that this helper put default values (1 vote, 1 proposal, 1 vote). That makes some unit tests (tally test) need to set the voting status 'manually'
- For testing onlyOwner() modifier, I made an helper to avoid copy-pasting the same code everywhere. This also allowed me to test functions as arguments in Solidity

As I can easily change the workflow status for each test individually, I tested each method one by one, on every aspect, with the same order :

- Testing the normal case
- Fuzz testing the normal case (if possible)
- Testing normal case with invalid values (for methods with arguments)
- Testing each revert branch
- Testing each modifier
- Testing emitted events

## Test coverage

As shown on image below, tests cover 100% of lines / statements / branches / funcs.
You can test this with the command `forge coverage`

![Test coverage image](https://image.noelshack.com/fichiers/2023/52/2/1703588566-capture-d-ecran-2023-12-26-a-12-00-56.png)

## Unit test results

There is a total of 47 unit tests, to cover the whole code base.
In the current state, all the 47 unit tests are valid.
You can test this with the command `forge test`

![Unit test results](https://image.noelshack.com/fichiers/2023/52/2/1703604659-capture-d-ecran-2023-12-26-a-16-30-48.png)
