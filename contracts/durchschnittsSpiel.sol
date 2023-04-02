pragma solidity ^0.8.0;

contract GuessTheNumberGame {
    address public owner;
    uint256 public numPlayers;
    uint256 public winningNumber;
    uint256 public closestGuess;
    address public winner;
    mapping(address => uint256) public playerGuesses;
    uint256 public saltSubmissionPeriod = 1 hours; // define salt submission period as 1 hour
    mapping(address => bytes32) public playerSalts; // map player addresses to salt values


    constructor() {
        owner = msg.sender;
        numPlayers = 0;
        winningNumber = 0;
        closestGuess = 1000;
        winner = address(0);
    }

    // Modifier that checks if the player has already submitted a guess
    modifier requireGuessNotSubmitted() {
        require(playerGuesses[msg.sender] == bytes32(0), "You have already entered a guess");
        _;
    }

    // Modifier that checks if the guess is within the allowed range
    modifier requireGuessInRange(uint256 guess) {
        require(guess >= 0 && guess <= 1000, "Guess must be between 0 and 1000");
        _;
    }


    // Modifier that checks if the sender is the owner
    modifier requireOwner(address owner) {
        require(msg.sender == owner, "Only owner can calculate the winner");
        _;
    }


    // Modifier that checks if there are at least one player
    modifier requireAtLeastOnePlayer(uint256 numPlayers) {
        require(numPlayers > 0, "There must be at least one player to calculate the winner");
        _;
    }

    // Modifier that checks if the winning number has not already been calculated
    modifier requireNotAlreadyCalculated(uint256 winningNumber) {
        require(winningNumber == 0, "The winning number has already been calculated");
        _;
    }


    // Modifier that checks if the salt submission period has expired
    modifier requireSaltSubmissionPeriodExpired(uint256 saltSubmissionDeadline) {
        require(block.timestamp >= saltSubmissionDeadline, "Salt submission period has not expired yet");
        _;
    }


    function enterNumber(uint256 _guess, bytes32 _salt) public requireGuessNotSubmitted requireGuessInRange {
        bytes32 hashedGuess = keccak256(abi.encodePacked(_guess, _salt));
        playerGuesses[msg.sender] = hashedGuess;
        numPlayers += 1;
    }

    function calculateWinner() public requireOwner requireAtLeastOnePlayer requireNotAlreadyCalculated requireSaltSubmissionPeriodExpired {

        uint256 total = 0;
        for (uint256 i = 0; i < numPlayers; i++) {
            address playerAddress = address(i);
            bytes32 hashedGuess = playerGuesses[playerAddress] ^ playerSalts[playerAddress];
            total += uint256(hashedGuess);
        }
        uint256 average = total / numPlayers;
        uint256 closest = 1000;
        address winnerAddress;
        for (uint256 j = 0; j < numPlayers; j++) {
            address playerAddress = address(j);
            bytes32 hashedGuess = playerGuesses[playerAddress] ^ playerSalts[playerAddress];
            uint256 distance = average > uint256(hashedGuess) ? average - uint256(hashedGuess) : uint256(hashedGuess) - average;
            if (distance < closest) {
                closest = distance;
                winnerAddress = playerAddress;
                closestGuess = uint256(hashedGuess);
            } else if (distance == closest) {
                winnerAddress = address(0);
            }
        }
        if (winnerAddress == address(0)) {
            winner = address(0);
        } else {
            winner = winnerAddress;
        }
        winningNumber = average * 2 / 3;
    }

    function collectSalts() public {
        require(msg.sender == owner, "Only owner can collect the salts");
        require(numPlayers > 0, "There must be at least one player to collect the salts");
        require(winningNumber == 0, "The winning number has already been calculated");

        for (uint256 i = 0; i < numPlayers; i++) {
            address playerAddress = address(i);
            require(playerSalts[playerAddress] == bytes32(0), "Salt has already been collected for this player");
            playerSalts[playerAddress] = salts[playerAddress];
        }

        // start timer for players to submit their salt values
        saltSubmissionDeadline = block.timestamp + saltSubmissionPeriod;
    }

    function selectWinner() public {
        require(msg.sender == owner, "Only owner can select the winner");
        require(winner != address(0), "There must be a winner to select");
        require(closestGuess == winningNumber, "The winning number has not been calculated yet");

        uint256 numWinners = 0;
        for (uint256 i = 0; i < numPlayers; i++) {
            if (playerGuesses[address(i)] == closestGuess) {
                numWinners++;
            }
        }
        if (numWinners == 1) {
            payable(winner).transfer(address(this).balance);
        } else {
            uint256 winnerIndex = uint256(blockhash(block.number - 1)) % numWinners;
            uint256 count = 0;
            for (uint256 j = 0; j < numPlayers; j++) {
                if (playerGuesses[address(j)] == closestGuess) {
                    if (count == winnerIndex) {
                        payable(address(j)).transfer(address(this).balance / numWinners);
                        break;
                    }
                    count++;
                }
            }
        }
    }

    receive() external payable {}
}
