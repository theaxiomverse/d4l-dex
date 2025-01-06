// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/tokens/ERC20.sol";

contract BonkTestToken is ERC20("Test Token", "TEST", 18) {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Only owner can mint");
        super._mint(to, amount);
    }

    function burn(uint256 amount) public {
        super._burn(msg.sender, amount);
    }
}

contract ERC20Test is Test {
    BonkTestToken public token;
    
    address public constant OWNER = address(0x1);
    address public constant USER1 = address(0x2);
    address public constant USER2 = address(0x3);
    address public constant SPENDER = address(0x4);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    
    function setUp() public {
        vm.startPrank(OWNER);
        token = new BonkTestToken();
        token.mint(OWNER, INITIAL_SUPPLY);
        vm.stopPrank();
        
        // Fund users with ETH for gas
        vm.deal(USER1, 100 ether);
        vm.deal(USER2, 100 ether);
        vm.deal(SPENDER, 100 ether);
    }
    
    function testInitialSetup() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(OWNER), INITIAL_SUPPLY);
    }
    
    function testTransfer() public {
        uint256 amount = 1000 ether;
        
        vm.startPrank(OWNER);
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(OWNER, USER1, amount);
        
        bool success = token.transfer(USER1, amount);
        assertTrue(success);
        
        assertEq(token.balanceOf(USER1), amount);
        assertEq(token.balanceOf(OWNER), INITIAL_SUPPLY - amount);
        
        vm.stopPrank();
    }
    
    function testTransferFrom() public {
        uint256 amount = 1000 ether;
        
        vm.prank(OWNER);
        token.approve(SPENDER, amount);
        
        vm.startPrank(SPENDER);
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(OWNER, USER1, amount);
        
        bool success = token.transferFrom(OWNER, USER1, amount);
        assertTrue(success);
        
        assertEq(token.balanceOf(USER1), amount);
        assertEq(token.balanceOf(OWNER), INITIAL_SUPPLY - amount);
        assertEq(token.allowance(OWNER, SPENDER), 0);
        
        vm.stopPrank();
    }
    
    function testApprove() public {
        uint256 amount = 1000 ether;
        
        vm.startPrank(OWNER);
        
        vm.expectEmit(true, true, false, true);
        emit Approval(OWNER, SPENDER, amount);
        
        bool success = token.approve(SPENDER, amount);
        assertTrue(success);
        
        assertEq(token.allowance(OWNER, SPENDER), amount);
        
        vm.stopPrank();
    }
    
    function testInfiniteApproval() public {
        vm.startPrank(OWNER);
        
        token.approve(SPENDER, type(uint256).max);
        assertEq(token.allowance(OWNER, SPENDER), type(uint256).max);
        
        vm.startPrank(SPENDER);
        token.transferFrom(OWNER, USER1, 1000 ether);
        
        // Allowance should remain unchanged for infinite approval
        assertEq(token.allowance(OWNER, SPENDER), type(uint256).max);
        
        vm.stopPrank();
    }
    
    function testFailTransferInsufficientBalance() public {
        vm.startPrank(USER1);
        token.transfer(USER2, 1 ether); // USER1 has no tokens
        vm.stopPrank();
    }
    
    function testFailTransferFromInsufficientAllowance() public {
        vm.startPrank(SPENDER);
        token.transferFrom(OWNER, USER1, 1 ether); // No allowance
        vm.stopPrank();
    }
    
    function testFailTransferToZeroAddress() public {
        vm.startPrank(OWNER);
        token.transfer(address(0), 1000 ether);
        vm.stopPrank();
    }
    
    function testFailTransferFromToZeroAddress() public {
        vm.prank(OWNER);
        token.approve(SPENDER, 1000 ether);
        
        vm.startPrank(SPENDER);
        token.transferFrom(OWNER, address(0), 1000 ether);
        vm.stopPrank();
    }
    
    function testMint() public {
        uint256 amount = 1000 ether;
        
        vm.startPrank(OWNER);
        
        uint256 initialSupply = token.totalSupply();
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), USER1, amount);
        
        token.mint(USER1, amount);
        
        assertEq(token.totalSupply(), initialSupply + amount);
        assertEq(token.balanceOf(USER1), amount);
        
        vm.stopPrank();
    }
    
    function testFailMintUnauthorized() public {
        vm.startPrank(USER1);
        token.mint(USER1, 1000 ether);
        vm.stopPrank();
    }
    
    function testBurn() public {
        uint256 amount = 1000 ether;
        
        vm.startPrank(OWNER);
        
        uint256 initialSupply = token.totalSupply();
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(OWNER, address(0), amount);
        
        token.burn(amount);
        
        assertEq(token.totalSupply(), initialSupply - amount);
        assertEq(token.balanceOf(OWNER), INITIAL_SUPPLY - amount);
        
        vm.stopPrank();
    }
    
    function testFailBurnInsufficientBalance() public {
        vm.startPrank(USER1);
        token.burn(1000 ether);
        vm.stopPrank();
    }
    
    function testPermit() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        
        vm.prank(OWNER);
        token.mint(owner, 1000 ether);
        
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        
        // Create permit signature
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        SPENDER,
                        1000 ether,
                        nonce,
                        deadline
                    )
                )
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        token.permit(owner, SPENDER, 1000 ether, deadline, v, r, s);
        
        assertEq(token.allowance(owner, SPENDER), 1000 ether);
        assertEq(token.nonces(owner), 1);
    }
    
    function testFailPermitExpired() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp - 1 hours;
        
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        SPENDER,
                        1000 ether,
                        nonce,
                        deadline
                    )
                )
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        token.permit(owner, SPENDER, 1000 ether, deadline, v, r, s);
    }
} 