// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract SinglePlayerRPS {

    constructor() {
        owner = payable(msg.sender);
        contractAddress = payable(address(this));
        MIN_BET = 1e16; // 1 finney
    }

    address payable owner;

    uint public MIN_BET;
    uint public initialBet;
    uint public contractBet;

    // Possible moves a player can make.
    enum Choices {
        Rock,
        Paper,
        Scissors,
        None
    }

    // Possible results of a game.
    enum Results {
        Player,
        Contract,
        Draw,
        None
    }

    // The players' addresses.
    address payable player;
    address contractAddress;
    
    // The player's move.
    Choices private playerMove = Choices.None;
    Choices private contractMove = Choices.None;

    /**************************************************************************/
    /*************************** REGISTRATION PHASE ***************************/
    /**************************************************************************/

    // Bet must be greater than the minimum bet and greater or equal to the initial bet.
    modifier betIsValid() {
        require(msg.value >= MIN_BET && msg.value > 0, "Bet size must be at least 1 finney");
        require(initialBet == 0 || msg.value >= initialBet, "Bet must be at least as big as the initial bet");
        _;
    }

    modifier playerNotRegistered() {
        require(msg.sender != player && msg.sender != contractAddress, "Player already registered");
        _;
    }

    // Register the player and the contract as a player with the same deposit amount as the player
    function registerGame() public payable betIsValid playerNotRegistered {
        if (player == address(0)) {
            player = payable(msg.sender);
            initialBet = msg.value;
            contractBet = msg.value;
        }
    }


    /**************************************************************************/
    /****************************** COMMIT PHASE ******************************/
    /**************************************************************************/

    // check if the move matched any value in the enum
    modifier moveIsValid(string memory move) {
        require(keccak256(abi.encodePacked(move)) == keccak256(abi.encodePacked("rock")) || keccak256(abi.encodePacked(move)) == keccak256(abi.encodePacked("paper")) || keccak256(abi.encodePacked(move)) == keccak256(abi.encodePacked("scissors")), "Move must be rock, paper, or scissors");
        _;
    }

    modifier playerRegistered() {
        require (msg.sender == player || msg.sender == contractAddress, "Player not registered");
        _;
    }

    // Save the player's move.
    // Returns true if the move was valid, false otherwise.
    function play (string memory move) public payable playerRegistered moveIsValid(move) returns (bool) {
        if (msg.sender == player || msg.sender == contractAddress) {
            if (keccak256(abi.encodePacked(move)) == keccak256(abi.encodePacked("rock"))) {
                playerMove = Choices.Rock;
            } else if (keccak256(abi.encodePacked(move)) == keccak256(abi.encodePacked("paper"))) {
                playerMove = Choices.Paper;
            } else if (keccak256(abi.encodePacked(move)) == keccak256(abi.encodePacked("scissors"))) {
                playerMove = Choices.Scissors;
            }

            // set the contract's move to a random value from the enum
            contractMove = Choices(uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 3);

            return true;
        } 
    return false;
    }

    /**************************************************************************/
    /****************************** RESULT PHASE ******************************/
    /**************************************************************************/

    modifier commitPhaseEnded() {
        require (playerMove != Choices.None && contractMove != Choices.None, "Commit phase has not ended");
        _;
    }

    // Calculate the result of the game and pay the winner.
    // Returns the outcome of the game.
    function finishGame() public commitPhaseEnded returns (Results) {
        Results result;

        if (playerMove == contractMove) {
            result = Results.Draw;
        } else if ((playerMove == Choices.Rock     && contractMove == Choices.Scissors) ||
                   (playerMove == Choices.Paper    && contractMove == Choices.Rock)     ||
                   (playerMove == Choices.Scissors && contractMove == Choices.Paper)    ||
                   (playerMove != Choices.None     && contractMove == Choices.None)) {
            result = Results.Player;
        } else {
            result = Results.Contract;
        }

        address payable addrPlayer = player;
        uint playerBet = initialBet;
        reset();  // Reset game before paying to avoid reentrancy attacks
        pay(addrPlayer, playerBet, result);

        return result;
    }

    // Pay the winner(s).
    function pay(address payable playerAddr, uint playerBet, Results result) private {
        if (result == Results.Player) {
            playerAddr.transfer(playerBet * 2);
        } else if (result == Results.Contract) {
            return;            
        } else if (result == Results.Draw) {
            playerAddr.transfer(playerBet);
        }
    }

    // Reset the game.
    function reset() private {
        initialBet = 0;
        player = payable(address(0x0));
        playerMove = Choices.None;
        contractMove = Choices.None;
    }


    /**************************************************************************/ 
    /******************************* UTILS ************************************/
    /**************************************************************************/

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    // modfier for setting the minimum bet
    // minimum bet must be greater than 1 finney
    // the value is taken from the setMinBet function
    modifier minBetIsValid(uint _minBet) {
        require(_minBet >= 1e16, "Minimum bet must be at least 1 finney");
        _;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function fundContract() public payable {
        require(msg.value > 0, "You must send some BNB");
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        owner.transfer(balance);
    }

    function setMinBet(uint _minBet) public payable onlyOwner minBetIsValid(_minBet) {
        MIN_BET = _minBet;
    }
}
