// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "../interfaces/IPredictionMarketERC20.sol";
import "../interfaces/IOracle.sol";

contract EnhancedPredictionMarketToken is IPredictionMarketERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public marketCreationFee;
    uint256 public bettingFee;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) private frozenAccounts;

    IOracle public oracle; // Oracle for outcome verification

    event MarketCreated(uint256 marketId, string question, string[] outcomes);
    event BetPlaced(uint256 marketId, address indexed bettor, uint256 outcomeIndex, uint256 amount);
    event MarketResolved(uint256 marketId, uint256 winningOutcomeIndex);
    event WinningsWithdrawn(uint256 marketId, address indexed winner, uint256 amount);
    event MarketCreationFeeUpdated(uint256 newFee);
    event BettingFeeUpdated(uint256 newFee);

    struct Market {
        string question;
        address creator;
        bool isResolved;
        uint256 totalBets;
        uint256 winningOutcomeIndex;
        string[] outcomes;
        uint256[] outcomeBets;
    }

    Market[] public markets;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply, address _oracle) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _initialSupply * (10 ** uint256(decimals));
        balanceOf[msg.sender] = totalSupply;
        oracle = IOracle(_oracle);
        marketCreationFee = 0.01 ether; // Example fee
        bettingFee = 0.001 ether; // Example fee
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(!frozenAccounts[msg.sender], "Account is frozen");
        require(!frozenAccounts[to], "Recipient account is frozen");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(!frozenAccounts[from], "Sender account is frozen");
        require(!frozenAccounts[to], "Recipient account is frozen");
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function freezeAccount(address account, bool freeze) external override {
        frozenAccounts[account] = freeze;
    }

    function isAccountFrozen(address account) external view override returns (bool) {
        return frozenAccounts[account];
    }

    function createMarket(string calldata question, string[] calldata outcomes) external override returns (uint256 marketId) {
        uint256 numOutcomes = outcomes.length;
        require(numOutcomes > 1, "At least two outcomes required");
        require(balanceOf[msg.sender] >= marketCreationFee, "Insufficient balance for market creation fee");

        unchecked {
            balanceOf[msg.sender] -= marketCreationFee;
        }

        markets.push(Market({
            question: question,
            outcomes: outcomes,
            totalBets: 0,
            outcomeBets: new uint256[](numOutcomes),
            isResolved: false,
            winningOutcomeIndex: 0,
            creator: msg.sender
        }));

        emit MarketCreated(markets.length - 1, question, outcomes);
        return markets.length - 1;
    }

    function placeBet(uint256 marketId, uint256 outcomeIndex, uint256 amount) external override returns (bool) {
        Market storage market = markets[marketId];
        require(!market.isResolved, "Market is already resolved");
        require(outcomeIndex < market.outcomes.length, "Invalid outcome index");
        
        uint256 totalCost = amount + bettingFee;
        require(balanceOf[msg.sender] >= totalCost, "Insufficient balance to place bet");

        unchecked {
            balanceOf[msg.sender] -= totalCost;
            market.outcomeBets[outcomeIndex] += amount;
            market.totalBets += amount;
        }

        emit BetPlaced(marketId, msg.sender, outcomeIndex, amount);
        return true;
    }

    function resolveMarket(uint256 marketId) external override returns (bool) {
        require(marketId < markets.length, "Invalid market ID");
        Market storage market = markets[marketId];
        require(!market.isResolved, "Market is already resolved");

        // Get the winning outcome from the oracle
        uint256 winningOutcomeIndex = oracle.getOutcome(marketId);
        require(winningOutcomeIndex < market.outcomes.length, "Invalid winning outcome index");
        
        market.isResolved = true;
        market.winningOutcomeIndex = winningOutcomeIndex;

        emit MarketResolved(marketId, winningOutcomeIndex);
        return true;
    }

    function withdrawWinnings(uint256 marketId) external override returns (bool) {
        Market storage market = markets[marketId];
        require(market.isResolved, "Market is not resolved");

        uint256 winningOutcomeBets = market.outcomeBets[market.winningOutcomeIndex];
        if (winningOutcomeBets > 0) {
            uint256 winnings;
            unchecked {
                winnings = (market.totalBets * market.outcomeBets[market.winningOutcomeIndex]) / winningOutcomeBets;
            }
            
            if (winnings > 0) {
                balanceOf[msg.sender] += winnings;
                emit WinningsWithdrawn(marketId, msg.sender, winnings);
            }
        }

        return true;
    }

    // Admin functions to update fees
    function updateMarketCreationFee(uint256 newFee) external {
        marketCreationFee = newFee;
        emit MarketCreationFeeUpdated(newFee);
    }

    function updateBettingFee(uint256 newFee) external {
        bettingFee = newFee;
        emit BettingFeeUpdated(newFee);
    }

    // Rename markets view function to getMarket
    function getMarket(uint256 marketId) external view returns (
        string memory question,
        string[] memory outcomes,
        uint256 totalBets,
        uint256[] memory outcomeBets,
        bool isResolved,
        uint256 winningOutcomeIndex,
        address creator
    ) {
        Market storage market = markets[marketId];
        return (
            market.question,
            market.outcomes,
            market.totalBets,
            market.outcomeBets,
            market.isResolved,
            market.winningOutcomeIndex,
            market.creator
        );
    }
} 