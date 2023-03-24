# durchschnittsSpiel (averageGame) Smart Contract
The durchschnittsSpiel smart contract is a Solidity contract that allows players to enter a guess between 0 and 1000, calculates the average of all guesses, and selects a winner based on the guess closest to 2/3 of the average.

## Usage
The durchschnittsSpiel smart contract can be deployed to an Ethereum network using a tool such as Remix or Hardhat. Once deployed, players can interact with the contract by calling the enterNumber function to enter a guess, the calculateWinner function to calculate the winner, and the selectWinner function to select the winner and distribute the prize.

## Functions
The durchschnittsSpiel smart contract includes the following functions:

- enterNumber(uint256 _guess): Allows players to enter a guess between 0 and 1000. Players can only enter one guess.

- calculateWinner(): Calculates the winner based on the guess closest to 2/3 of the average of all guesses.

- selectWinner(): Selects the winner and distributes the prize.

## Tests
The durchschnittsSpiel smart contract includes a set of tests written in Solidity using the Hardhat testing framework. These tests can be run using the Hardhat command line interface.

To run the tests, first install Hardhat:

```npm install --save-dev hardhat```

Then, navigate to the directory containing the durchschnittsSpiel smart contract and tests, and run the following command to run the tests:

```npx hardhat test```

## The test suite includes the following tests:

**should allow players to enter a guess**: checks that players can enter a guess by calling the enterNumber function.

**should not allow players to enter more than one guess**: checks that players cannot enter more than one guess by calling the enterNumber function twice with the same player.

**should calculate the winner**: checks that the winner and winning number are calculated correctly by calling the calculateWinner function.

**should select the winner**: checks that the winner receives the correct amount of funds by calling the selectWinner function.

## License
The durchschnittsSpiel smart contract and tests are licensed under the MIT License. See the LICENSE file for more information.