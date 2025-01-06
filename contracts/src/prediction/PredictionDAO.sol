// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "../interfaces/IERC20.sol";

contract PredictionDAO {
    struct Proposal {
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        bool executed;
        address target;
        bytes data;
        mapping(address => bool) hasVoted;
    }

    IERC20 public governanceToken;
    uint256 public proposalCount;
    uint256 public votingPeriod = 3 days;
    uint256 public quorum;
    
    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);

    constructor(address _governanceToken, uint256 _quorum) {
        governanceToken = IERC20(_governanceToken);
        quorum = _quorum;
    }

    function createProposal(
        string calldata description,
        address target,
        bytes calldata data
    ) external returns (uint256) {
        require(governanceToken.balanceOf(msg.sender) >= quorum / 10, "Insufficient tokens to propose");

        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.description = description;
        proposal.endTime = block.timestamp + votingPeriod;
        proposal.target = target;
        proposal.data = data;

        emit ProposalCreated(proposalId, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 votes = governanceToken.balanceOf(msg.sender);
        require(votes > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        if (support) {
            proposal.yesVotes += votes;
        } else {
            proposal.noVotes += votes;
        }

        emit Voted(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(proposal.yesVotes + proposal.noVotes >= quorum, "Quorum not reached");
        require(proposal.yesVotes > proposal.noVotes, "Proposal failed");

        proposal.executed = true;

        (bool success, ) = proposal.target.call(proposal.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }
} 