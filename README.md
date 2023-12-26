![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white) ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)

# simple_voting_contract_testing

Second project for alyra course : testing of the simple_voting_contract.

I decided to create a separated project, as the testing projet must use Alyra's code as base for testing.

### Voting.t.sol

The unit test context is pretty simple :

- On each test, I 'reset' the voting instance, with setUp() method.
- I use 4 adresses during my tests :
  - The owner, which is in this case the ContractTest's address. I let it by default, because Voting smart contract doesn't contain any method that can't be called by another contract, like call() for example
  - Voters 1, 2 and 3, that I use for my different test. Voter 1 always is the default voter used for every test, mostly in my helpers methods (see below)
- As I can't modify the workflow status directly, and to avoid boiler plate code, I made an helper function \_setVotingInGivenStatus(Voting.WorkflowStatus ws), that allows me to set up the context for my tests with only 1 line of code. The only downside is that this helpers put defaults values (1 vote, 1 proposal, 1 vote). That make some unit tests (tally test) need set the voting status 'manually'
- For testing onlyOwner() modifier

As I can easily change the workflow status for each test individually, I tested each method one by one, on every aspect, with the same order :

- Testing normal case
- Fuzz testing normal case (if possible)
- Testing normal case with invalid values (for methods with arguments)
- Testing each revert branches
- Testing each modifier
- Testing emitted event

## Test coverage

As shown on image below, tests cover 100% of lines / statements / branches / funcs.
You can test this with the command `forge coverage`

![Test coverage image](https://image.noelshack.com/fichiers/2023/52/2/1703588566-capture-d-ecran-2023-12-26-a-12-00-56.png)

## Unit test results

There is a total of 47 unit test, to cover the whole code base.
In the current state, all the 47 unit tests are valid.
You can test this with the commande `forge test`

![Unit test results](https://image.noelshack.com/fichiers/2023/52/2/1703604659-capture-d-ecran-2023-12-26-a-16-30-48.png)
