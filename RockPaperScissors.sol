pragma solidity ^0.8.0;

import "./Meowcoin.sol";

contract Game {
    address public player1;
    address public player2;
    uint public prize;
    IERC20 chip;
    uint wager;
    uint turnCount;
    bool tie;
    
    
    RockPaperScissors parentContract;
    
    constructor(
        RockPaperScissors _parentContract,
        IERC20 _chip,
        address _player1, 
        address _player2,
        uint _prize,
        uint _wager)
        {
        player1 = _player1;
        player2 = _player2;
        chip = _chip;
        prize = _prize;
        wager = _wager;
        parentContract = _parentContract;
    }
    
    modifier referee {
        require(msg.sender == player1 || msg.sender == player2, "You are not in this match.");
        require(moves[msg.sender].turn == 0, "You already moved.");
        moves[msg.sender].turn++;
        turnCount++;
        _;
    }
    
    //Tracks player's choice, and whether they have moved.
    //Bool winner traks who is eligivle to withdraw the prize.
    struct Move {
        uint turn;
        uint choice;
        bool winner;
    }
    
    mapping(address => Move) public moves;
    
    function rock() public referee {
        moves[msg.sender].choice = 0;
    }
    
    function paper() public referee {
        moves[msg.sender].choice = 1;
    }
    
    function scissors() public referee {
        moves[msg.sender].choice = 2;
    }
    
    //Determines the winner, changes the winning player's bool "winner" to true in Struct Move.
    function getWinner() public returns(bool) {
        require(turnCount == 2, "No winner yet.");
        if(moves[player1].choice == 0 && moves[player2].choice == 2){
            return moves[player1].winner = true;
        } else if(moves[player1].choice == 2 && moves[player2].choice == 1){
            return moves[player1].winner = true;
        } else if(moves[player1].choice == 1 && moves[player2].choice == 0){
            return moves[player1].winner = true;
        } else if(moves[player2].choice == 0 && moves[player1].choice == 2){
            return moves[player2].winner = true;
        } else if(moves[player2].choice == 2 && moves[player1].choice == 1){
            return moves[player2].winner = true;
        } else if(moves[player2].choice == 1 && moves[player1].choice == 0){
            return moves[player2].winner = true;
        } else{
            //Returns tie if the players have the same move.
            return tie = true;
        }
        
    }
    
    //transfers the winnings "prize" to the winner.
    function chipTransfer() external payable {
        require(moves[msg.sender].winner == true, "You lost.");
        chip.transferFrom(address(this), msg.sender, prize);
    }
    
    //If the result is a draw, players get their wagers back.
    function getFundsBack() public payable{
        require(tie == true, "There was a winner.");
        uint amount = chip.balanceOf(address(this));
        chip.transfer(player1, amount / 2);
        chip.transfer(player2, amount / 2);
    }
    
    
}


contract RockPaperScissors {
    
    IERC20 public chip;
    
    //alerts players when a challenge is called.
    event Challenge(address _challenger, address _challengee, uint _wager);
    
    
    constructor(){
        chip = new Meowcoin();
    }
    
    struct Player {
        bool ready;
        bool challenged;
        uint wager;
    }
    

    
    mapping(address => Player) public players;
    
    
    address [] gameQueue;
  
    
    event GameStarted(address _challenger, address _challengee, address _game);
    
    //Basic buying and selling functions for ERC20.
    function buyChips() public payable {
        uint casinoBalance = chip.balanceOf(address(this));
        require(msg.value > 0, "You need more Ether.");
        require(msg.value <= casinoBalance, "The contract doesn't have enough chips.");
        chip.transfer(msg.sender, msg.value);
    }
    
    function cashOut(uint _amount) external payable {
        require(chip.balanceOf(msg.sender) >= _amount);
        chip.transferFrom(msg.sender, address(this), _amount);
        payable(msg.sender).transfer(_amount);
        
    }
    
    
    //Adds player addresses to a public game queue, where they can be challenged by others.
    //the game queue acts as proof of "Meowcoin" ownership, and readiness to play.
    function readyUp() public {
        require(chip.balanceOf(msg.sender) > 0, "Not enough chips.");
        require(players[msg.sender].ready == false, "You are in the game queue.");
        players[msg.sender].ready = true;
        gameQueue.push(msg.sender);
    }
    
    function getGameQueue() public view returns(address [] memory) {
        return gameQueue;
    }
    
    function challenge(address _player, uint _wager) public payable {
        require(_player != msg.sender);
        require(players[_player].ready == true, "Player is not ready.");
        require(players[msg.sender].ready == true, "You are not ready.");
        require(chip.balanceOf(msg.sender) >= _wager, "Please buy more chips.");
        require(chip.balanceOf(_player) >= _wager, "Player doesn't have enough.");
        players[msg.sender].wager += _wager;
        players[_player].challenged = true;
        emit Challenge(msg.sender, _player, _wager);
    }
    
    //Players accept challenge based on address and wager. Acceptance creates the contact "game",
    //and sends the players' chips to that address after both players have agreed.  Game's address
    //is emitted as GameStarted.
    
    function acceptChallenge(address _player, uint _wager) public payable {
        require(players[msg.sender].challenged == true, "You are the challenger.");
        require(players[_player].wager == _wager, "Your bet must match the challenger.");
        Game game = new Game(this, chip, msg.sender, _player, _wager * 2, _wager); 
        emit GameStarted(msg.sender, _player, address(game));
        chip.transferFrom(_player, address(game), _wager);
        chip.transferFrom(msg.sender, address(game), _wager);
        players[msg.sender].challenged = false;
        players[_player].wager = 0;
    }
    
    
    receive() external payable {}
}
