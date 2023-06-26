const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GuessTheNumberGame", function () {
    let game;
    let owner;

    beforeEach(async () => {
        const GuessTheNumberGame = await ethers.getContractFactory("GuessTheNumberGame");
        game = await GuessTheNumberGame.deploy();
        await game.deployed();

        [owner] = await ethers.getSigners();
    });

    it("should deploy and initialize the game", async function () {
        expect(await game.numPlayers()).to.equal(0);
        expect(await game.isWinningGuessCalculated()).to.equal(false);
    });

    it("should reset variables", async function () {
        await expect(game.connect(owner).resetVariables()).to.not.be.reverted;
    });

    it("should start the game", async function () {
        await expect(game.connect(owner).startGame()).to.not.be.reverted;
    });

    it("should enter a guess", async function () {
        const guess = 111;
        const salt = 111;

        // hash the salt first
        const hashedSalt = ethers.utils.keccak256(ethers.utils.solidityPack(['uint256'], [salt]));
        // concatenate and hash the guess and hashed salt
        const combined = ethers.utils.solidityPack(['uint256', 'bytes32'], [guess, hashedSalt]);
        const hashedGuess = ethers.utils.keccak256(combined);

        await expect(game.connect(owner).enterGuess(hashedGuess)).to.be.reverted;
        await expect(game.connect(owner).enterGuess(hashedGuess, {value: ethers.utils.parseEther("0.001")})).to.not.be.reverted;
    });

    it("should fail if the same player is trying to enter another guess", async function () {
        const guess1 = 111, salt1 = 111;
        const guess2 = 112, salt2 = 112;

        // Hashing and entering the first guess
        let hashedSalt = ethers.utils.keccak256(ethers.utils.solidityPack(['uint256'], [salt1]));
        let combined = ethers.utils.solidityPack(['uint256', 'bytes32'], [guess1, hashedSalt]);
        let hashedGuess = ethers.utils.keccak256(combined);

        await game.connect(owner).enterGuess(hashedGuess, {value: ethers.utils.parseEther("0.001")});

        // Hashing and entering the second guess
        hashedSalt = ethers.utils.keccak256(ethers.utils.solidityPack(['uint256'], [salt2]));
        combined = ethers.utils.solidityPack(['uint256', 'bytes32'], [guess2, hashedSalt]);
        hashedGuess = ethers.utils.keccak256(combined);

        // This transaction should fail
        await expect(game.connect(owner).enterGuess(hashedGuess, {value: ethers.utils.parseEther("0.001")})).to.be.reverted;
    });


    it("should reveal salt and guess", async function () {
        const guess = 111;
        const salt = 111;

        // hash the salt first
        const hashedSalt = ethers.utils.keccak256(ethers.utils.solidityPack(['uint256'], [salt]));
        // concatenate and hash the guess and hashed salt
        const combined = ethers.utils.solidityPack(['uint256', 'bytes32'], [guess, hashedSalt]);
        const hashedGuess = ethers.utils.keccak256(combined);

        await game.connect(owner).enterGuess(hashedGuess, {value: ethers.utils.parseEther("0.001")});
        // mine 5 new blocks
        for (let i = 0; i < 5; i++) {
            await ethers.provider.send("evm_mine");
        }
        await expect(game.connect(owner).revealSaltAndGuess(guess, salt)).to.not.be.reverted;
    });

});


