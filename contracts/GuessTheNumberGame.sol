// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import './CloneFactory.sol';


contract Factory is CloneFactory {
    GuessTheNumberGame[] public children;
    address masterContract;

    constructor(address payable _masterContract){
        masterContract = _masterContract;
    }

    function createChild() external{
        address payable cloneAddress = payable(address(uint160(createClone(masterContract))));
        GuessTheNumberGame child = GuessTheNumberGame(cloneAddress);
        child.init();
        children.push(child);
    }

    function getChildren() external view returns(GuessTheNumberGame[] memory){
        return children;
    }
}

contract GuessTheNumberGame is Ownable {
    uint256 public numPlayers;
    address[] public playerAddresses;
    address[] public revealedAddresses;
    address [] public activeAddresses;
    address[] public winningAddresses;
    uint[] public activeRevealedGuesses;
    address[] public droppedOutPlayerAddresses;
    uint256 public winningGuess;
    mapping(address => bytes32) public playerGuesses;
    uint256 public submissionPeriod = 10;
    uint256 public revealPeriod = 10;
    mapping(address => bytes32) public playerSalts; // map player addresses to salt values
    mapping(address => uint256) public playerRevealedGuesses; // map player addresses to submitted guesses
    mapping(address => uint256) public guessesOfActivePlayers;
    uint256 public participationFee;
    uint256 public ownersPercentFee;
    bool public isWinningGuessCalculated;
    uint256 public minGuess = 0;
    uint256 public maxGuess = 1000;
    uint256 public minNumPlayers;

    uint256 public startBlock;


    function init() external {

        startBlock = block.number;
        numPlayers = 0;
        minNumPlayers = 3;
        participationFee = 10000000000000000; // 0.01 ethers
        ownersPercentFee = 10;
        isWinningGuessCalculated = false;
    }

    // Modifier that checks if the player has already submitted a guess
    modifier requireGuessNotSubmitted() {
        require(playerGuesses[msg.sender] == bytes32(0), "You have already entered a guess");
        _;
    }

    modifier requireGuessSubmitted() {
        require(playerGuesses[msg.sender] != bytes32(0), "You haven't entered a guess yet");
        _;
    }

    // Modifier that checks if the guess is within the allowed range
    modifier requireGuessInRange(uint256 guess) {
        require(guess >= minGuess && guess <= maxGuess, "Guess must be between 0 and 1000");
        _;
    }

    // Modifier that checks if the guess submission period has not expired yet
    modifier requireSubmissionIsStillOpen() {
        require(block.number <= startBlock + submissionPeriod, "Guess submission period has expired");
        _;
    }


    // Modifier that checks if the guess submission period has expired
    modifier requireSubmissionClosed() {
        require(block.number > startBlock + submissionPeriod, "Guess submission period hasn't expired yet");
        _;
    }


    // Modifier that checks if there the min number of players are present
    modifier requireMinNumPlayersAchieved() {
        require(numPlayers > minNumPlayers, "There are not enough players to calculate the winner");
        _;
    }

    // Modifier that checks if the winning number has not already been calculated
    modifier requireNotAlreadyCalculated() {
        require(!isWinningGuessCalculated, "The winning number has already been calculated");
        _;
    }


    // Modifier that checks if the salt submission period has expired
    modifier requireRevealPeriodExpired() {
        require(block.number >= startBlock + submissionPeriod + revealPeriod, "Reveal period has not expired yet");
        _;
    }

    // Modifier that checks if the salt submission period has not expired yet
    modifier requireRevealPeriodIsOpen() {
        require(block.number < startBlock + submissionPeriod + revealPeriod, "Salt submission period has expired");
        _;
    }

    // Modifier that checks if there at least one player
    modifier requirePotentialWinnerExists() {
        require(winningGuess != minGuess && winningGuess < maxGuess + 1, "Winning guess must be between 1 and 1000");
        _;
    }


    // Modifier that checks if the game has started
    modifier requireGameStarted() {
        require(startBlock != 0, "Game has not started yet!");
        _;
    }

    modifier requireAtLeastOnePlayerRevealedGuessAndSalt() {
        require(revealedAddresses.length > 0, "At least one player must reveal his guess and salt");
        _;
    }


    event VariableReset();
    event GameStarted(uint256 timestamp);
    event GuessSubmitted(address player);
    event AllSaltsSubmitted();
    event AllGuessesSubmitted();
    event PlayerDropsOut(address player);
    event WinningGuessCalculated(uint256 winningGuess);


    function resetVariables() public onlyOwner {
        numPlayers = 0;
        winningGuess = maxGuess + 1;
        isWinningGuessCalculated = false;

        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];
            delete playerGuesses[player];
            delete playerSalts[player];
            delete playerRevealedGuesses[player];
        }

        for (uint j = 0; j < activeAddresses.length; j++) {
            address activePlayer = activeAddresses[j];
            delete guessesOfActivePlayers[activePlayer];
        }

        // Clear all arrays
        delete playerAddresses;
        delete activeAddresses;
        delete activeRevealedGuesses;
        delete droppedOutPlayerAddresses;
        delete winningAddresses;
        emit VariableReset();
    }


    function startGame() public onlyOwner {
        resetVariables();
        startBlock = block.number;
        emit GameStarted(startBlock);
    }

    function enterGuess(bytes32 _hashedGuess) public payable requireGameStarted requireSubmissionIsStillOpen requireGuessNotSubmitted {

        require(msg.value >= participationFee, "Insufficient participation fee");
        require(msg.value == participationFee, string(abi.encodePacked("The fee is ", Strings.toString(participationFee), " wei")));
        payable(owner()).transfer(msg.value * ownersPercentFee / 100);

        address playerAddress = msg.sender;
        playerGuesses[playerAddress] = _hashedGuess;
        numPlayers += 1;
        playerAddresses.push(playerAddress);

        emit GuessSubmitted(playerAddress);
    }


    function revealSaltAndGuess(uint _guess, uint256 _salt) public requireGameStarted requireSubmissionClosed requireGuessSubmitted requireRevealPeriodIsOpen {
        playerRevealedGuesses[msg.sender] = _guess;

        bytes32 encodedSalt = keccak256(abi.encodePacked(_salt));
        playerSalts[msg.sender] = encodedSalt;

        revealedAddresses.push(msg.sender);

        if (areAllSaltsCollected()){
            emit AllSaltsSubmitted();
        }

        if (areAllGuessesCollected()){
            emit AllGuessesSubmitted();
        }
    }


    function areAllSaltsCollected() internal view returns (bool) {
        bool allSaltsCollected = true;

        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];

            if (playerGuesses[player] == bytes32(0)) {
                allSaltsCollected = false;
                break;
            }
        }
        return allSaltsCollected;
    }

    function areAllGuessesCollected() internal view returns (bool) {
        bool allGuessesCollected = true;

        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];
            // bytes32 guess = playerRevealedGuesses[player];

            if (playerRevealedGuesses[player] == 0) {
                allGuessesCollected = false;
                break;
            }
        }
        return allGuessesCollected;
    }

    //////////////////////////////////////////////////


    function calculateWinningGuess() public onlyOwner requireMinNumPlayersAchieved requireNotAlreadyCalculated requireRevealPeriodExpired requireAtLeastOnePlayerRevealedGuessAndSalt {

        uint256 total = 0;

        for (uint i = 0; i < revealedAddresses.length; i++) {
            address player = revealedAddresses[i];
            bytes32 guess = playerGuesses[player];
            bytes32 salt = playerSalts[player];
            uint256 revealedGuess = playerRevealedGuesses[player];

            bytes32 hashedRevealedGuess = keccak256(abi.encodePacked(revealedGuess, salt));

            if (guess != hashedRevealedGuess) {
                emit PlayerDropsOut(player);
                droppedOutPlayerAddresses.push(player);
            } else {
                guessesOfActivePlayers[player] = revealedGuess;
                activeAddresses.push(player);
                activeRevealedGuesses.push(revealedGuess);
                total += revealedGuess;
            }
        }

        uint256 numberOfActivePlayers = activeAddresses.length;
        uint256 target = (2 * total) / (3* numberOfActivePlayers);

        winningGuess = findClosest(activeRevealedGuesses, target);
        isWinningGuessCalculated = true;
        emit WinningGuessCalculated(winningGuess);
    }


    function findClosest(uint256[] memory values, uint256 target) internal pure returns (uint256) {
        uint256 closestValue = values[0];
        uint256 smallestDifference = absDiff(closestValue, target);

        for (uint256 i = 1; i < values.length; i++) {
            uint256 currentValue = values[i];
            uint256 currentDifference = absDiff(currentValue, target);
            if (currentDifference < smallestDifference) {
                smallestDifference = currentDifference;
                closestValue = currentValue;
            }
        }

        return closestValue;
    }

    function absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a - b;
        } else {
            return b - a;
        }
    }


    function selectWinner() public payable onlyOwner requirePotentialWinnerExists {

        for (uint256 i = 0; i < activeAddresses.length; i++) {
            address activeAddress = activeAddresses[i];
            if (guessesOfActivePlayers[activeAddress] == winningGuess)
                winningAddresses.push(activeAddress);
        }
        if (winningAddresses.length == 1) {
            payable(winningAddresses[0]).transfer(address(this).balance);
        } else {
            uint256 winnerIndex = uint256(blockhash(block.number - 1)) % winningAddresses.length;
            uint256 count = 0;
            for (uint256 j = 0; j < winningAddresses.length; j++) {
                if (guessesOfActivePlayers[winningAddresses[j]] == winningGuess) {
                    if (count == winnerIndex) {
                        payable(winningAddresses[j]).transfer(address(this).balance / activeAddresses.length);
                        break;
                    }
                    count++;
                }
            }
        }
    }

    receive() external payable {}
}
