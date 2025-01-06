// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/oracle/PriceOracle.sol";
import "../src/mocks/MockAttacker.sol";

contract PriceOracleTest is Test {
    PriceOracle public priceOracle;
    MockAttacker public attacker;
    
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    
    function setUp() public {
        // Deploy with this contract as owner
        priceOracle = new PriceOracle(address(this), Authority(address(0)));
        attacker = new MockAttacker();
        
        // Grant roles
        priceOracle.grantRole(UPDATER_ROLE, address(this));
    }
    
    function testUpdatePrice() public {
        uint256 marketId = 1;
        uint256 price = 1000e18;
        
        priceOracle.updatePrice(marketId, price);
        assertEq(priceOracle.getPrice(marketId), price);
    }
    
    function testInvalidPrice() public {
        uint256 marketId = 1;
        uint256 price = 0;
        
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.InvalidPrice.selector, price));
        priceOracle.updatePrice(marketId, price);
    }
    
    function testPriceStale() public {
        uint256 marketId = 1;
        uint256 price = 1000e18;
        
        priceOracle.updatePrice(marketId, price);
        
        // Move time forward past validity period
        vm.warp(block.timestamp + 6 minutes);
        
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.PriceStale.selector, marketId));
        priceOracle.getPrice(marketId);
    }
    
    function testUnauthorizedUpdate() public {
        uint256 marketId = 1;
        uint256 price = 1000e18;
        
        vm.prank(address(0x1));
        vm.expectRevert();
        priceOracle.updatePrice(marketId, price);
    }
    
    function testBlacklistedUpdate() public {
        uint256 marketId = 1;
        uint256 price = 1000e18;
        address blacklisted = address(0x1);
        
        // Blacklist an address
        priceOracle.addToBlacklist(blacklisted);
        
        // Try to update price from blacklisted address
        vm.prank(blacklisted);
        vm.expectRevert();
        priceOracle.updatePrice(marketId, price);
    }
    
    function testEmergencyStop() public {
        uint256 marketId = 1;
        uint256 price = 1000e18;
        
        // Stop the contract
        priceOracle.emergencyStop();
        
        // Try to update price during emergency stop
        vm.expectRevert();
        priceOracle.updatePrice(marketId, price);
        
        // Resume operations
        priceOracle.resumeOperation();
        
        // Should work now
        priceOracle.updatePrice(marketId, price);
        assertEq(priceOracle.getPrice(marketId), price);
    }
} 