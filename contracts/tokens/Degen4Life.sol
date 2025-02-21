// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../tokenomics/tokenomics.sol";

contract Degen4Life is ERC20, Ownable, Pausable {
    // Tokenomics
    TokenomicsRules public immutable tokenomics;
    
    // Wallets
    address public communityWallet;
    address public teamWallet;
    address public dexLiquidityWallet;
    address public treasuryWallet;
    address public marketingWallet;
    address public cexLiquidityWallet;
    
    // State variables
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;
    mapping(address => bool) public isExcludedFromFees;
    
    // Events
    event WalletUpdated(string walletType, address newWallet);
    event FeeDistributed(
        uint256 communityAmount,
        uint256 teamAmount,
        uint256 dexLiquidityAmount,
        uint256 treasuryAmount,
        uint256 marketingAmount,
        uint256 cexLiquidityAmount,
        uint256 burnAmount
    );

    constructor(
        address _tokenomics,
        address _communityWallet,
        address _teamWallet,
        address _dexLiquidityWallet,
        address _treasuryWallet,
        address _marketingWallet,
        address _cexLiquidityWallet
    ) ERC20("Degen4Life", "D4L") Ownable(msg.sender) {
        tokenomics = TokenomicsRules(_tokenomics);
        
        communityWallet = _communityWallet;
        teamWallet = _teamWallet;
        dexLiquidityWallet = _dexLiquidityWallet;
        treasuryWallet = _treasuryWallet;
        marketingWallet = _marketingWallet;
        cexLiquidityWallet = _cexLiquidityWallet;
        
        // Exclude fee wallets from fees
        isExcludedFromFees[_communityWallet] = true;
        isExcludedFromFees[_teamWallet] = true;
        isExcludedFromFees[_dexLiquidityWallet] = true;
        isExcludedFromFees[_treasuryWallet] = true;
        isExcludedFromFees[_marketingWallet] = true;
        isExcludedFromFees[_cexLiquidityWallet] = true;
        
        // Mint initial supply
        _mint(msg.sender, MAX_SUPPLY);
    }
    
    // Override transfer function to implement tokenomics
    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        
        if (isExcludedFromFees[owner] || isExcludedFromFees[to]) {
            _transfer(owner, to, amount);
            return true;
        }
        
        // Calculate fees
        uint256 burnAmount = tokenomics.calculateBurn(amount);
        uint256 communityAmount = tokenomics.calculateCommunityWallet(amount);
        uint256 teamAmount = tokenomics.calculateTeamWallet(amount);
        uint256 dexLiquidityAmount = tokenomics.calculateDEXLiquidity(amount);
        uint256 treasuryAmount = tokenomics.calculateTreasuryInitiative(amount);
        uint256 marketingAmount = tokenomics.calculateMarketingWallet(amount);
        uint256 cexLiquidityAmount = tokenomics.calculateCEXLiquidity(amount);
        
        // Calculate net transfer amount
        uint256 totalFees = burnAmount + communityAmount + teamAmount + 
            dexLiquidityAmount + treasuryAmount + marketingAmount + cexLiquidityAmount;
        uint256 netAmount = amount - totalFees;
        
        // Execute transfers
        _burn(owner, burnAmount);
        _transfer(owner, communityWallet, communityAmount);
        _transfer(owner, teamWallet, teamAmount);
        _transfer(owner, dexLiquidityWallet, dexLiquidityAmount);
        _transfer(owner, treasuryWallet, treasuryAmount);
        _transfer(owner, marketingWallet, marketingAmount);
        _transfer(owner, cexLiquidityWallet, cexLiquidityAmount);
        _transfer(owner, to, netAmount);
        
        emit FeeDistributed(
            communityAmount,
            teamAmount,
            dexLiquidityAmount,
            treasuryAmount,
            marketingAmount,
            cexLiquidityAmount,
            burnAmount
        );
        
        return true;
    }
    
    // Admin functions
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
    }
    
    function updateCommunityWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        communityWallet = newWallet;
        isExcludedFromFees[newWallet] = true;
        emit WalletUpdated("Community", newWallet);
    }
    
    function updateTeamWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        teamWallet = newWallet;
        isExcludedFromFees[newWallet] = true;
        emit WalletUpdated("Team", newWallet);
    }
    
    function updateDexLiquidityWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        dexLiquidityWallet = newWallet;
        isExcludedFromFees[newWallet] = true;
        emit WalletUpdated("DEX Liquidity", newWallet);
    }
    
    function updateTreasuryWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        treasuryWallet = newWallet;
        isExcludedFromFees[newWallet] = true;
        emit WalletUpdated("Treasury", newWallet);
    }
    
    function updateMarketingWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        marketingWallet = newWallet;
        isExcludedFromFees[newWallet] = true;
        emit WalletUpdated("Marketing", newWallet);
    }
    
    function updateCexLiquidityWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        cexLiquidityWallet = newWallet;
        isExcludedFromFees[newWallet] = true;
        emit WalletUpdated("CEX Liquidity", newWallet);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
} 