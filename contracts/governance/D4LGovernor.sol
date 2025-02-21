// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "../interfaces/IContractRegistry.sol";

abstract contract D4LGovernor is 
    GovernorUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable 
{
    // Constants
    uint256 public constant VOTING_DELAY = 1 days;                 // 1 day delay before voting starts
    uint256 public constant VOTING_PERIOD = 5 days;                // 5 days voting period
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 * 1e18;   // 100k tokens to propose
    uint256 public constant QUORUM_PERCENTAGE = 4;                 // 4% quorum

    // State variables
    IContractRegistry public registry;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token,
        address _timelock,
        address _registry
    ) external initializer {
        __Governor_init("Degen4Life DAO");
        __GovernorVotes_init(IVotes(_token));
        __GovernorVotesQuorumFraction_init(QUORUM_PERCENTAGE);
        __GovernorTimelockControl_init(TimelockControllerUpgradeable(_timelock));
        
        registry = IContractRegistry(_registry);
    }

    function votingDelay() public pure override returns (uint256) {
        return VOTING_DELAY;
    }

    function votingPeriod() public pure override returns (uint256) {
        return VOTING_PERIOD;
    }

    function proposalThreshold() public pure override returns (uint256) {
        return PROPOSAL_THRESHOLD;
    }

    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory params
    ) internal virtual override {
        return super._countVote(proposalId, account, support, weight, params);
    }

    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        return super._quorumReached(proposalId);
    }

    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        return super._voteSucceeded(proposalId);
    }

    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return super.hasVoted(proposalId, account);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
} 