// Import the Hardhat testing module.
import { ethers } from "hardhat";
import { expect } from "chai";

// Start describing the test suite for the GuessTheNumberGame contract.
describe("GuessTheNumberGame", function() {
    // Define the contract and some test variables.
    let guessTheNumberGame;
    let owner;
    let player1;
    let player2;

    beforeEach(async function() {
        // Deploy the contract and get some test accounts.
        const GuessTheNumberGame = await ethers.getContractFactory("GuessTheNumberGame");
        [owner, player1, player2] = await ethers.getSigners();
        guessTheNumberGame = await GuessTheNumberGame.deploy();
        await guessTheNumberGame.deployed();
    });

    it("should allow players to enter a guess", async function() {
        // Call the enterNumber function with a valid guess.
        await guessTheNumberGame.connect(player1).enterNumber(500);

        // Check that the player's guess was recorded.
        expect(await guessTheNumberGame.playerGuesses(player1.address)).to.equal(500);
    });

    it("should not allow players to enter more than one guess", async function() {
        // Call the enterNumber function twice with the same player.
        await guessTheNumberGame.connect(player1).enterNumber(500);
        await expect(guessTheNumberGame.connect(player1).enterNumber(600)).to.be.revertedWith("You have already entered a guess");
    });

    it("should calculate the winner", async function() {
        // Call the enterNumber function with some valid guesses.
        await guessTheNumberGame.connect(player1).enterNumber(400);
        await guessTheNumberGame.connect(player2).enterNumber(600);

        // Call the calculateWinner function.
        await guessTheNumberGame.calculateWinner();

        // Check that the winner and winning number were recorded.
        expect(await guessTheNumberGame.winner()).to.equal(player1.address);
        expect(await guessTheNumberGame.winningNumber()).to.equal(266);
    });

    it("should select the winner", async function() {
        // Call the enterNumber function with some valid guesses.
        await guessTheNumberGame.connect(player1).enterNumber(400);
        await guessTheNumberGame.connect(player2).enterNumber(600);

        // Call the calculateWinner and selectWinner functions.
        await guessTheNumberGame.calculateWinner();
        await guessTheNumberGame.selectWinner();

        // Check that the winner received the correct amount of funds.
        expect(await ethers.provider.getBalance(player1.address)).to.equal(ethers.utils.parseEther("1.0"));
    });
});
