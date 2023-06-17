const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GuessTheNumberGame", function () {
    let game;
    let owner;
    let player1;
    let player2;

    beforeEach(async () => {
        const Game = await ethers.getContractFactory("GuessTheNumberGame");
        game = await Game.deploy();
        await game.deployed();

        [owner, player1, player2] = await ethers.getSigners();

        await game.connect(owner).startGame();
    });

    it("should allow players to enter a guess within the allowed range", async function () {
        const guess = 500;
        const salt = 123456;

        await game.connect(player1).enterGuess(guess, salt, {
            value: ethers.utils.parseEther("1"),
        });

        const playerGuess = await game.playerGuesses(player1.address);
        expect(playerGuess).to.equal(
            ethers.utils.solidityKeccak256(["uint256", "bytes32"], [guess, ethers.utils.solidityKeccak256(["uint256"], [salt])])
        );
    });

    it("should not allow players to enter a guess if they have already submitted one", async function () {
        const guess = 500;
        const salt = 123456;

        await game.connect(player1).enterGuess(guess, salt, {
            value: ethers.utils.parseEther("1"),
        });

        await expect(
            game.connect(player1).enterGuess(guess, salt, {
                value: ethers.utils.parseEther("1"),
            })
        ).to.be.revertedWith("You have already entered a guess");
    });

    it("should not allow players to enter a guess if it is outside the allowed range", async function () {
        const guess = 2000;
        const salt = 123456;

        await expect(
            game.connect(player1).enterGuess(guess, salt, {
                value: ethers.utils.parseEther("1"),
            })
        ).to.be.revertedWith("Guess must be between 0 and 1000");
    });

    it("should not allow players to enter a guess if the submission period has expired", async function () {
        const guess = 500;
        const salt = 123456;

        await ethers.provider.send("evm_increaseTime", [3600]); // Advance time by 1 hour

        await expect(
            game.connect(player1).enterGuess(guess, salt, {
                value: ethers.utils.parseEther("1"),
            })
        ).to.be.revertedWith("Guess submission has expired");
    });

    it("should calculate the winning guess correctly", async function () {
        const guess1 = 500;
        const salt1 = 123456;

        const guess2 = 600;
        const salt2 = 654321;

        await game.connect(player1).enterGuess(guess1, salt1, {
            value: ethers.utils.parseEther("1"),
        });

        await game.connect(player2).enterGuess(guess2, salt2, {
            value: ethers.utils.parseEther("1"),
        });

    });
    it("should not allow non-owner to start the game", async function () {
        await expect(game.connect(player1).startGame()).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should not allow non-players to reveal their salt and guess", async function () {
        const guess = 500;
        const salt = 123456;
        await expect(game.connect(player1).revealSaltAndGuess(guess, salt)).to.be.revertedWith("You haven't entered a guess yet");
    });

    it("should allow players to reveal their salt and guess after they have entered one", async function () {
        const guess = 500;
        const salt = 123456;

        await game.connect(player1).enterGuess(guess, salt, {
            value: ethers.utils.parseEther("0.01"),
        });

        await ethers.provider.send("evm_increaseTime", [3600]); // Advance time by 1 hour

        await game.connect(player1).revealSaltAndGuess(guess, salt);

        const playerRevealedGuess = await game.playerRevealedGuesses(player1.address);
        expect(playerRevealedGuess).to.equal(guess);
    });

    it("should correctly calculate the winning guess", async function () {
        const guess1 = 500;
        const salt1 = 123456;

        const guess2 = 600;
        const salt2 = 654321;

        await game.connect(player1).enterGuess(guess1, salt1, {
            value: ethers.utils.parseEther("0.01"),
        });

        await game.connect(player2).enterGuess(guess2, salt2, {
            value: ethers.utils.parseEther("0.01"),
        });

        await ethers.provider.send("evm_increaseTime", [3600]); // Advance time by 1 hour

        await game.connect(player1).revealSaltAndGuess(guess1, salt1);
        await game.connect(player2).revealSaltAndGuess(guess2, salt2);

        await ethers.provider.send("evm_increaseTime", [3600]); // Advance time by another hour

        await game.connect(owner).calculateWinningGuess();

        expect(await game.winningGuess()).to.equal((2*(guess1+guess2))/(3*2));
    });
})