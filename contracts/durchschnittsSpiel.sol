pragma solidity ^0.8.0;

contract GuessTheNumberGame {
    address public owner;
    uint256 public numPlayers;
    uint256 public winningNumber;
    uint256 public closestGuess;
    address public winner;
    mapping(address => uint256) public playerGuesses;

    constructor() {
        owner = msg.sender;
        numPlayers = 0;
        winningNumber = 0;
        closestGuess = 1000;
        winner = address(0);
    }

    function enterNumber(uint256 _guess, bytes32 _salt) public {
        require(_guess >= 0 && _guess <= 1000, "Guess must be between 0 and 1000");
        require(playerGuesses[msg.sender] == bytes32(0), "You have already entered a guess");
        bytes32 hashedGuess = keccak256(abi.encodePacked(_guess, _salt));
        playerGuesses[msg.sender] = hashedGuess;
        numPlayers += 1;
    }

    function calculateWinner() public {
        require(msg.sender == owner, "Only owner can calculate the winner");
        require(numPlayers > 0, "There must be at least one player to calculate the winner");

        uint256 total = 0;
        for (uint256 i = 0; i < numPlayers; i++) {
            total += playerGuesses[address(i)];
        }
        uint256 average = total / numPlayers;
        uint256 closest = 1000;
        address winnerAddress;
        for (uint256 j = 0; j < numPlayers; j++) {
            uint256 distance = average > playerGuesses[address(j)] ? average - playerGuesses[address(j)] : playerGuesses[address(j)] - average;
            if (distance < closest) {
                closest = distance;
                winnerAddress = address(j);
                closestGuess = playerGuesses[address(j)];
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
