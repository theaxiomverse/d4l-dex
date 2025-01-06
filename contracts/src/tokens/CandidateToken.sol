// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "solmate/tokens/ERC1155.sol";
import "solmate/auth/Owned.sol";

/**
 * @title CandidateToken
 * @notice ERC1155 token representing candidates in prediction markets
 * @dev Each token ID represents a unique candidate
 */
contract CandidateToken is ERC1155, Owned {
    // Candidate metadata
    struct Candidate {
        string name;
        string description;
        string imageURI;
        uint256 marketId;
        bool exists;
        uint256 totalBetsCount;
        uint256 uniqueBettorsCount;
        uint256 currentPrice;
        uint256 totalSupply;
        uint256 odds;             // Current odds (in basis points, e.g., 5000 = 50%)
    }
    
    // Market metadata
    struct Market {
        string name;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool resolved;
        uint256 winningCandidateId;
        uint256[] candidateIds;
        uint256 totalVolume;      // Total volume of bets in the market
    }
    
    // Mappings
    mapping(uint256 => Candidate) public candidates;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => bool)) public hasBet;
    mapping(uint256 => PricePoint[]) public priceHistory;
    mapping(uint256 => mapping(uint256 => uint256)) public marketCandidateVolumes;  // marketId => candidateId => volume
    
    // Historical data
    struct PricePoint {
        uint256 timestamp;
        uint256 price;
        uint256 totalSupply;
    }
    
    // Events
    event MarketCreated(
        uint256 indexed marketId,
        string name,
        string description,
        uint256[] candidateIds
    );
    
    event CandidateCreated(
        uint256 indexed candidateId,
        uint256 indexed marketId,
        string name,
        string description,
        string imageURI
    );
    
    event CandidateMetadataUpdated(
        uint256 indexed candidateId,
        string name,
        string description,
        string imageURI
    );
    
    event BetPlaced(
        uint256 indexed candidateId,
        address indexed bettor,
        uint256 amount,
        uint256 newPrice,
        uint256 timestamp
    );
    
    event MarketResolved(
        uint256 indexed marketId,
        uint256 indexed winningCandidateId
    );
    
    event OddsUpdated(
        uint256 indexed marketId,
        uint256 indexed candidateId,
        uint256 newOdds
    );
    
    constructor() Owned(msg.sender) {}
    
    /**
     * @notice Create a new prediction market with candidates
     */
    function createMarket(
        string memory marketName,
        string memory marketDescription,
        uint256 duration,
        string[] memory candidateNames,
        string[] memory candidateDescriptions,
        string[] memory candidateImageURIs
    ) external returns (uint256 marketId) {
        require(
            candidateNames.length == candidateDescriptions.length &&
            candidateNames.length == candidateImageURIs.length,
            "Array lengths must match"
        );
        require(candidateNames.length >= 2, "Need at least 2 candidates");
        
        // Generate market ID
        marketId = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            marketName
        )));
        
        // Create candidates
        uint256[] memory candidateIds = new uint256[](candidateNames.length);
        for (uint256 i = 0; i < candidateNames.length; i++) {
            uint256 candidateId = uint256(keccak256(abi.encodePacked(
                marketId,
                i,
                candidateNames[i]
            )));
            
            candidates[candidateId] = Candidate({
                name: candidateNames[i],
                description: candidateDescriptions[i],
                imageURI: candidateImageURIs[i],
                marketId: marketId,
                exists: true,
                totalBetsCount: 0,
                uniqueBettorsCount: 0,
                currentPrice: 0,
                totalSupply: 0,
                odds: 0
            });
            
            candidateIds[i] = candidateId;
            
            // Initialize price history
            priceHistory[candidateId].push(PricePoint({
                timestamp: block.timestamp,
                price: 0,
                totalSupply: 0
            }));
            
            emit CandidateCreated(
                candidateId,
                marketId,
                candidateNames[i],
                candidateDescriptions[i],
                candidateImageURIs[i]
            );
        }
        
        // Create market
        markets[marketId] = Market({
            name: marketName,
            description: marketDescription,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            resolved: false,
            winningCandidateId: 0,
            candidateIds: candidateIds,
            totalVolume: 0
        });
        
        // Set initial equal odds
        _updateOdds(marketId);
        
        emit MarketCreated(marketId, marketName, marketDescription, candidateIds);
    }
    
    /**
     * @notice Record a bet for a candidate
     */
    function recordBet(
        uint256 candidateId,
        address bettor,
        uint256 amount,
        uint256 price
    ) external onlyOwner {
        require(candidates[candidateId].exists, "Candidate does not exist");
        Candidate storage candidate = candidates[candidateId];
        Market storage market = markets[candidate.marketId];
        require(!market.resolved, "Market resolved");
        
        candidate.totalBetsCount++;
        candidate.currentPrice = price;
        candidate.totalSupply += amount;
        
        // Update market volumes and odds
        marketCandidateVolumes[candidate.marketId][candidateId] += amount;
        _updateOdds(candidate.marketId);
        
        if (!hasBet[candidateId][bettor]) {
            hasBet[candidateId][bettor] = true;
            candidate.uniqueBettorsCount++;
        }
        
        // Record price point
        priceHistory[candidateId].push(PricePoint({
            timestamp: block.timestamp,
            price: price,
            totalSupply: candidate.totalSupply
        }));
        
        // Mint tokens to bettor
        _mint(bettor, candidateId, amount, "");
        
        emit BetPlaced(candidateId, bettor, amount, price, block.timestamp);
    }
    
    /**
     * @notice Resolve a market by setting the winning candidate
     */
    function resolveMarket(uint256 marketId, uint256 winningCandidateId) external onlyOwner {
        Market storage market = markets[marketId];
        require(!market.resolved, "Market already resolved");
        require(block.timestamp >= market.endTime, "Market not ended");
        
        bool validCandidate = false;
        for (uint256 i = 0; i < market.candidateIds.length; i++) {
            if (market.candidateIds[i] == winningCandidateId) {
                validCandidate = true;
                break;
            }
        }
        require(validCandidate, "Invalid winning candidate");
        
        market.resolved = true;
        market.winningCandidateId = winningCandidateId;
        
        emit MarketResolved(marketId, winningCandidateId);
    }
    
    /**
     * @notice Get price history for a candidate within a time range
     */
    function getPriceHistory(
        uint256 candidateId,
        uint256 startTime,
        uint256 endTime
    ) external view returns (
        uint256[] memory timestamps,
        uint256[] memory prices,
        uint256[] memory supplies
    ) {
        PricePoint[] storage history = priceHistory[candidateId];
        uint256 count = 0;
        
        // Count valid entries
        for (uint256 i = 0; i < history.length; i++) {
            if (history[i].timestamp >= startTime && 
                history[i].timestamp <= endTime) {
                count++;
            }
        }
        
        // Initialize arrays
        timestamps = new uint256[](count);
        prices = new uint256[](count);
        supplies = new uint256[](count);
        
        // Fill arrays
        uint256 index = 0;
        for (uint256 i = 0; i < history.length; i++) {
            if (history[i].timestamp >= startTime && 
                history[i].timestamp <= endTime) {
                timestamps[index] = history[i].timestamp;
                prices[index] = history[i].price;
                supplies[index] = history[i].totalSupply;
                index++;
            }
        }
        
        return (timestamps, prices, supplies);
    }
    
    /**
     * @notice Get candidate statistics
     */
    function getCandidateStats(uint256 candidateId) external view returns (
        uint256 _totalBets,
        uint256 _uniqueBettors,
        uint256 _currentPrice,
        uint256 _totalSupply,
        uint256 _pricePoints
    ) {
        require(candidates[candidateId].exists, "Candidate does not exist");
        
        Candidate storage candidate = candidates[candidateId];
        return (
            candidate.totalBetsCount,
            candidate.uniqueBettorsCount,
            candidate.currentPrice,
            candidate.totalSupply,
            priceHistory[candidateId].length
        );
    }
    
    /**
     * @notice Get market candidates
     */
    function getMarketCandidates(uint256 marketId) external view returns (
        uint256[] memory candidateIds,
        string[] memory names,
        string[] memory descriptions,
        string[] memory imageURIs,
        uint256[] memory currentPrices,
        uint256[] memory totalSupplies
    ) {
        Market storage market = markets[marketId];
        candidateIds = market.candidateIds;
        
        names = new string[](candidateIds.length);
        descriptions = new string[](candidateIds.length);
        imageURIs = new string[](candidateIds.length);
        currentPrices = new uint256[](candidateIds.length);
        totalSupplies = new uint256[](candidateIds.length);
        
        for (uint256 i = 0; i < candidateIds.length; i++) {
            Candidate storage candidate = candidates[candidateIds[i]];
            names[i] = candidate.name;
            descriptions[i] = candidate.description;
            imageURIs[i] = candidate.imageURI;
            currentPrices[i] = candidate.currentPrice;
            totalSupplies[i] = candidate.totalSupply;
        }
    }
    
    /**
     * @notice URI for a token ID
     */
    function uri(uint256 id) public view override returns (string memory) {
        require(candidates[id].exists, "URI query for nonexistent token");
        return candidates[id].imageURI;
    }
    
    /**
     * @notice Calculate and update odds for a market
     * @param marketId ID of the market
     */
    function _updateOdds(uint256 marketId) internal {
        Market storage market = markets[marketId];
        uint256[] memory candidateIds = market.candidateIds;
        
        // Calculate total volume first
        uint256 totalVolume = 0;
        for (uint256 i = 0; i < candidateIds.length; i++) {
            totalVolume += marketCandidateVolumes[marketId][candidateIds[i]];
        }
        market.totalVolume = totalVolume;
        
        // If no volume yet, set equal odds
        if (totalVolume == 0) {
            uint256 equalOdds = 10000 / candidateIds.length; // Equal distribution in basis points
            for (uint256 i = 0; i < candidateIds.length; i++) {
                candidates[candidateIds[i]].odds = equalOdds;
                emit OddsUpdated(marketId, candidateIds[i], equalOdds);
            }
            return;
        }
        
        // Calculate odds based on volumes
        for (uint256 i = 0; i < candidateIds.length; i++) {
            uint256 candidateId = candidateIds[i];
            uint256 candidateVolume = marketCandidateVolumes[marketId][candidateId];
            // Calculate odds in basis points (1/100th of a percent)
            uint256 odds = (candidateVolume * 10000) / totalVolume;
            candidates[candidateId].odds = odds;
            emit OddsUpdated(marketId, candidateId, odds);
        }
    }
    
    /**
     * @notice Get market odds
     * @param marketId ID of the market
     * @return candidateIds Array of candidate IDs
     * @return odds Array of odds in basis points
     */
    function getMarketOdds(uint256 marketId) external view returns (
        uint256[] memory candidateIds,
        uint256[] memory odds
    ) {
        Market storage market = markets[marketId];
        candidateIds = market.candidateIds;
        odds = new uint256[](candidateIds.length);
        
        for (uint256 i = 0; i < candidateIds.length; i++) {
            odds[i] = candidates[candidateIds[i]].odds;
        }
    }
    
    /**
     * @notice Get detailed market statistics
     * @param marketId ID of the market
     */
    function getMarketStats(uint256 marketId) external view returns (
        uint256 totalVolume,
        uint256[] memory candidateIds,
        uint256[] memory volumes,
        uint256[] memory odds
    ) {
        Market storage market = markets[marketId];
        candidateIds = market.candidateIds;
        volumes = new uint256[](candidateIds.length);
        odds = new uint256[](candidateIds.length);
        
        for (uint256 i = 0; i < candidateIds.length; i++) {
            uint256 candidateId = candidateIds[i];
            volumes[i] = marketCandidateVolumes[marketId][candidateId];
            odds[i] = candidates[candidateId].odds;
        }
        
        totalVolume = market.totalVolume;
    }
} 