pragma solidity ^0.8.0;

contract GuessTheNumberGame {
    address public owner;
    uint256 public numPlayers;
    address[] playerAddresses;
    address [] activeAddresses;
    uint[] activeGuesses;
    address[] droppedOutPlayerAddresses;
    uint256 public winningGuess;
    address public winner;
    mapping(address => uint256) public playerGuesses;
    uint256 public submissionPeriod = 1 days;
    uint256 public revealPeriod = 1 hours; // define salt submission period as 1 hour
    mapping(address => bytes32) public playerSalts; // map player addresses to salt values
    mapping(address => uint256) public playerRevealedGuesses; // map player addresses to submitted guesses
    mapping(address => uint256) public guessesOfActivePlayers;

    uint256 startTimestamp;


    constructor() {
        owner = msg.sender;
        numPlayers = 0;
        winner = address(0);
        winningGuess = 1001; // > 1000 which is the maximum accepted guess
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
        require(guess >= 0 && guess <= 1000, "Guess must be between 0 and 1000");
        _;
    }

    // Modifier that checks if the guess submission perios has not expired yet
    modifier requireSubmissionIsStillOpen(uint256 guess) {
        require(block.timestamp < submissionPeriod + startTimestamp, "Guess submission has expired");
        _;
    }

    // Modifier that checks if the guess submission perios has not expired yet
    modifier requireSubmissionClosed(uint256 guess) {
        require(block.timestamp >= submissionPeriod + startTimestamp, "Guess submission has expired yet");
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
    modifier requireRevealPeriodExpired() {
        require(block.timestamp >= block.timestamp + submissionPeriod + revealPeriod, "Reveal period has not expired yet");
        _;
    }

    modifier requireRevealPeriodIsOpen() {
        require(block.timestamp < block.timestamp + submissionPeriod + revealPeriod, "Salt submission period has expired");
        _;
    }

    // Modifier that checks if there at least one player
    modifier requirePotentialWinnerExists(uint256 saltSubmissionDeadline) {
        require(winner != address(0), "There must be a winner to select");
        _;
    }

    // Modifier that checks if there at least one player
    modifier requireWinningNumberIsNotCalculated(uint256 saltSubmissionDeadline) {
        require(closestGuess == winningNumber, "The winning number has not been calculated yet");
        _;
    }

    modifier requireGameStarted() {
        require(startTimestamp != 0, "Game has not started yet!");
        _;
    }

    event GameStarted(uint256 timestamp);
    event GuessSubmitted(address player);
    event AllSaltsSubmitted();
    event AllGuessesSubmitted();
    event PlayerDropsOut(address player);
    event WinningGuessCalculated(uint256 winningGuess);


    function startGame() public requireOwner {
        startTimestamp = block.timestamp;
        // TODO: empty out all mappings!
        emit GameStarted(startTimestamp);
    }


    function enterGuess(uint256 _guess, bytes32 _salt) public requireGameStarted requireSubmissionIsStillOpen requireGuessNotSubmitted requireGuessInRange {
        bytes32 hashedGuess = keccak256(abi.encodePacked(_guess, _salt));
        playerGuesses[msg.sender] = hashedGuess;
        numPlayers += 1;
        playerAddresses.push(msg.sender);

        emit GuessSubmitted(msg.sender);
    }

    function revealSaltAndGuess(uint _guess, bytes32 _salt) public requireGameStarted requireSubmissionClosed requireGuessSubmitted requireRevealPeriodIsOpen {
        playerGuesses[msg.sender] = _guess;
        playerSalts[msg.sender] = _salt;

        if (areAllSaltsCollected){
            emit AllSaltsSubmitted();
        }

        if (areAllGuessesCollected()){
            emit AllGuessesSubmitted();
        }
    }



    function areAllSaltsCollected() internal returns (bool) {
        bool allSaltsCollected = true;

        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];
            byte32 salt = playerSalts[player];

            if (playerGuesses[player] == 0x000000000000000000000000000000000000000) {
                allSaltsCollected = false;
                break;
            }
        }
        return allSaltsCollected;
    }

    function areAllGuessesCollected() internal returns (bool) {
        bool allGuessesCollected = true;

        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];
            byte32 guess = playerRevealedGuesses[player];

            if (playerRevealedGuesses[player] == 0) {
                allGuessesCollected = false;
                break;
            }
        }
        return allGuessesCollected;
    }

    //////////////////////////////////////////////////


    function calculateWinningGuess() public requireOwner requireAtLeastOnePlayer requireNotAlreadyCalculated requireRevealPeriodExpired {

        uint256 total = 0;

        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];
            byte32 guess = playerGuesses[player];
            byte32 salt = playerSalts[player];
            uint256 revealedGuess = playerRevealedGuesses[player];

            bytes32 hashedRevealedGuess = keccak256(abi.encodePacked(guess, salt));

            if (guess != hashedRevealedGuess) {
                emit PlayerDropsOut(player);
                droppedOutPlayerAddresses.push(player);
            } else {
                guessesOfActivePlayers[player] = guess;
                activeAddresses.push(player);
                activeGuesses.push(guess);
                total += guess;
            }
        }


        uint256 numberOfActivePlayers = activeAddresses.length;
        uint256 target = 2 * total / 3* numberOfActivePlayers;

        winningGuess = findClosest(activeGuesses, target);
        emit WinningGuessCalculated();
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


    function selectWinner() requireOwner requirePotentialWinnerExists requireWinningNumberIsNotCalculated public {

        uint[] winningAddresses;

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
                if (guessesOfActivePlayers[winningAddresses[i]] == winningGuess) {
                    if (count == winnerIndex) {
                        payable(winningAddresses[i]).transfer(address(this).balance / activeAddresses.length);
                        break;
                    }
                    count++;
                }
            }
        }
    }

    receive() external payable {}
}
