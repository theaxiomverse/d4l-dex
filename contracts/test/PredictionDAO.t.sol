// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/prediction/PredictionDAO.sol";
import "../src/mocks/MockERC20.sol";

contract PredictionDAOTest is Test {
    PredictionDAO public dao;
    MockERC20 public token;
    
    address public constant OWNER = address(0x1);
    address public constant USER1 = address(0x2);
    address public constant USER2 = address(0x3);
    address public constant TARGET = address(0x4);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 public constant QUORUM = 100_000 ether;
    
    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    
    function setUp() public {
        token = new MockERC20("Governance Token", "GOV", 18);
        dao = new PredictionDAO(address(token), QUORUM);
        
        // Mint tokens to users
        token.mint(USER1, INITIAL_SUPPLY);
        token.mint(USER2, INITIAL_SUPPLY / 2);
    }
    
    function testInitialSetup() public {
        assertEq(address(dao.governanceToken()), address(token));
        assertEq(dao.quorum(), QUORUM);
        assertEq(dao.proposalCount(), 0);
        assertEq(dao.votingPeriod(), 3 days);
    }
    
    function testCreateProposal() public {
        vm.startPrank(USER1);
        
        string memory description = "Test Proposal";
        bytes memory data = abi.encodeWithSignature("test()");
        
        vm.expectEmit(true, false, false, true);
        emit ProposalCreated(0, description);
        
        uint256 proposalId = dao.createProposal(description, TARGET, data);
        assertEq(proposalId, 0);
        
        (string memory storedDescription, uint256 yesVotes, uint256 noVotes, uint256 endTime, bool executed, address target, bytes memory storedData) = dao.proposals(proposalId);
        assertEq(storedDescription, description);
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(endTime, block.timestamp + dao.votingPeriod());
        assertEq(executed, false);
        assertEq(target, TARGET);
        assertEq(keccak256(storedData), keccak256(data));
        
        vm.stopPrank();
    }
    
    function testFailCreateProposalInsufficientTokens() public {
        address poorUser = address(0x5);
        token.mint(poorUser, QUORUM / 100); // Less than required
        
        vm.prank(poorUser);
        dao.createProposal("Test", TARGET, "");
    }
    
    function testVoting() public {
        // Create proposal
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", TARGET, "");
        
        // USER1 votes yes
        vm.prank(USER1);
        vm.expectEmit(true, true, false, true);
        emit Voted(proposalId, USER1, true);
        dao.vote(proposalId, true);
        
        // USER2 votes no
        vm.prank(USER2);
        vm.expectEmit(true, true, false, true);
        emit Voted(proposalId, USER2, false);
        dao.vote(proposalId, false);
        
        // Check vote counts
        (,uint256 yesVotes, uint256 noVotes,,,,) = dao.proposals(proposalId);
        assertEq(yesVotes, INITIAL_SUPPLY);
        assertEq(noVotes, INITIAL_SUPPLY / 2);
    }
    
    function testFailVoteAfterEnd() public {
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", TARGET, "");
        
        vm.warp(block.timestamp + 4 days); // Past voting period
        
        vm.prank(USER1);
        dao.vote(proposalId, true);
    }
    
    function testFailDoubleVote() public {
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", TARGET, "");
        
        vm.startPrank(USER1);
        dao.vote(proposalId, true);
        dao.vote(proposalId, true); // Should fail
        vm.stopPrank();
    }
    
    function testFailVoteWithoutTokens() public {
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", TARGET, "");
        
        address noTokens = address(0x5);
        vm.prank(noTokens);
        dao.vote(proposalId, true);
    }
    
    function testExecuteProposal() public {
        // Create a mock contract to receive the call
        MockTarget target = new MockTarget();
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 123);
        
        // Create and vote on proposal
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", address(target), data);
        
        vm.prank(USER1);
        dao.vote(proposalId, true);
        
        // Wait for voting period to end
        vm.warp(block.timestamp + 4 days);
        
        // Execute proposal
        vm.expectEmit(true, false, false, false);
        emit ProposalExecuted(proposalId);
        dao.executeProposal(proposalId);
        
        // Verify the call was executed
        assertEq(target.value(), 123);
    }
    
    function testFailExecuteBeforeVotingEnds() public {
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", TARGET, "");
        
        dao.executeProposal(proposalId);
    }
    
    function testFailExecuteWithoutQuorum() public {
        // Create proposal
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", TARGET, "");
        
        // Clear USER2's initial balance and give them less than quorum
        uint256 user2Balance = token.balanceOf(USER2);
        vm.startPrank(USER2);
        token.transfer(OWNER, user2Balance); // Transfer all tokens to OWNER instead of burning
        vm.stopPrank();
        
        // Give USER2 exactly half of quorum
        vm.prank(OWNER);
        token.transfer(USER2, QUORUM / 2);
        
        // Vote with less than quorum
        vm.prank(USER2);
        dao.vote(proposalId, true);
        
        // Try to execute
        vm.warp(block.timestamp + 4 days);
        dao.executeProposal(proposalId);
    }
    
    function testFailExecuteFailedProposal() public {
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", TARGET, "");
        
        vm.prank(USER1);
        dao.vote(proposalId, false); // Vote no
        
        vm.warp(block.timestamp + 4 days);
        dao.executeProposal(proposalId);
    }
    
    function testFailExecuteTwice() public {
        MockTarget target = new MockTarget();
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 123);
        
        vm.prank(USER1);
        uint256 proposalId = dao.createProposal("Test", address(target), data);
        
        vm.prank(USER1);
        dao.vote(proposalId, true);
        
        vm.warp(block.timestamp + 4 days);
        
        dao.executeProposal(proposalId);
        dao.executeProposal(proposalId); // Should fail
    }
}

// Helper contract for testing proposal execution
contract MockTarget {
    uint256 public value;
    
    function setValue(uint256 _value) external {
        value = _value;
    }
} 