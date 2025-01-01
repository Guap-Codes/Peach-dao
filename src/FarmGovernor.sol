// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import "./TimeLock.sol";
import "./PeachToken.sol";

/**
 * @title FarmGovernor
 * @dev Custom implementation of a governance contract using OpenZeppelin's framework with added functionalities.
 */
contract FarmGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    AccessControl,
    Pausable
{
    // Add these constant variables
    uint256 private constant INITIAL_VOTING_DELAY = 1; // 1 block
    uint256 private constant INITIAL_VOTING_PERIOD = 50400; // 1 week
    uint256 private constant INITIAL_PROPOSAL_THRESHOLD = 0;
    uint256 private constant INITIAL_QUORUM_FRACTION = 4; // 4%
    uint256 private constant TOTAL_REWARD_POOL = 1000 * 1e18; // Total reward pool

    PeachToken public immutable rewardToken;
    TimeLock private immutable _timelock;
    address public seedAddress;
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant REWARD_ROLE = keccak256("REWARD_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant TIMELOCK_ADMIN_ROLE =
        keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    uint256 private _customVotingPeriod;
    uint256 private _quorumNumerator;

    // Add these new state variables
    mapping(uint256 => mapping(address => bool)) private _proposalVoters;
    mapping(uint256 => address[]) private _proposalVotersList;

    struct Proposal {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    mapping(uint256 => Proposal) private _proposals;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string description
    );

    event ParticipantRewarded(
        uint256 indexed proposalId,
        address indexed participant,
        uint256 amount
    );

    // Add these event declarations at the contract level
    event VotingPeriodUpdated(uint256 newVotingPeriod);
    event QuorumFractionUpdated(uint256 newQuorumFraction);
    event SeedAddressUpdated(address indexed newSeedAddress);

    /**
     * @dev Initializes the contract with the specified token and timelock controller.
     * Sets initial values for voting delay, voting period, and quorum fraction.
     * @param _token The governance token that will be used for voting.
     * @param _timelockController The timelock controller.
     * @param _rewardToken The token used for rewarding participants.
     */
    constructor(
        IVotes _token,
        TimeLock _timelockController,
        PeachToken _rewardToken
    )
        Governor("FarmGovernor")
        GovernorSettings(
            INITIAL_VOTING_DELAY,
            INITIAL_VOTING_PERIOD,
            INITIAL_PROPOSAL_THRESHOLD
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(INITIAL_QUORUM_FRACTION)
        GovernorTimelockControl(_timelockController)
    {
        require(
            address(_rewardToken) != address(0),
            "FarmGovernor: reward token cannot be zero address"
        );
        require(
            address(_timelockController) != address(0),
            "FarmGovernor: timelock controller cannot be zero address"
        );

        rewardToken = _rewardToken;
        _timelock = _timelockController;
        // Replace _setupRole with _grantRole
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
        _grantRole(REWARD_ROLE, msg.sender);
        _customVotingPeriod = INITIAL_VOTING_PERIOD;
        _quorumNumerator = INITIAL_QUORUM_FRACTION;

        _grantRole(TIMELOCK_ADMIN_ROLE, address(this));
        _grantRole(PROPOSER_ROLE, address(this));
        _grantRole(EXECUTOR_ROLE, address(this));
        _grantRole(CANCELLER_ROLE, address(this));
    }

    function timelock() public view virtual override returns (address) {
        return address(_timelock);
    }

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(GovernorSettings, IGovernor)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(GovernorSettings, IGovernor)
        returns (uint256)
    {
        return _customVotingPeriod;
    }

    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(GovernorVotesQuorumFraction, IGovernor)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    /**
     * @dev Returns the quorum numerator.
     */
    function quorumNumerator() public view override returns (uint256) {
        return _quorumNumerator;
    }

    function state(
        uint256 proposalId
    )
        public
        view
        override(GovernorTimelockControl, Governor)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        require(!paused(), "FarmGovernor: paused");
        uint256 proposalId = super.propose(
            targets,
            values,
            calldatas,
            description
        );

        _proposals[proposalId] = Proposal({
            targets: targets,
            values: values,
            calldatas: calldatas,
            description: description
        });

        // Emit an event when a proposal is created
        emit ProposalCreated(
            proposalId,
            _msgSender(),
            targets,
            values,
            calldatas,
            description
        );

        return proposalId;
    }

    function proposalThreshold()
        public
        view
        override(GovernorSettings, Governor)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorTimelockControl, Governor) {
        // Inline the custom condition logic here
        require(true, "Custom condition not met");
        // If you need more complex logic in the future, you can add it here directly

        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorTimelockControl, Governor) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorTimelockControl, Governor)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(GovernorTimelockControl, Governor, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Custom functionalities

    /**
     * @dev Allows the governor to update the voting period.
     * @param newVotingPeriod The new voting period in blocks.
     */
    function updateVotingPeriod(
        uint256 newVotingPeriod
    ) external onlyRole(GOVERNOR_ROLE) {
        _customVotingPeriod = newVotingPeriod;
        emit VotingPeriodUpdated(newVotingPeriod);
    }

    /**
     * @dev Allows the governor to update the quorum fraction.
     * @param newQuorumFraction The new quorum fraction in percentage.
     */
    function updateQuorumFraction(
        uint256 newQuorumFraction
    ) external onlyRole(GOVERNOR_ROLE) {
        _updateQuorumNumerator(newQuorumFraction);
        emit QuorumFractionUpdated(newQuorumFraction);
    }

    /**
     * @dev Rewards participants for their involvement in governance.
     * @param proposalId The ID of the proposal.
     */
    function rewardParticipants(
        uint256 proposalId
    ) external onlyRole(REWARD_ROLE) {
        require(
            state(proposalId) == ProposalState.Executed ||
                state(proposalId) == ProposalState.Defeated,
            "Proposal not ended"
        );

        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = proposalVotes(proposalId);
        uint256 totalVotes = againstVotes + forVotes + abstainVotes;

        require(totalVotes > 0, "No votes cast");

        uint256 totalReward = TOTAL_REWARD_POOL;

        address[] memory voters = getVotersForProposal(proposalId);
        uint256[] memory rewards = new uint256[](voters.length);

        // Calculate rewards
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            uint256 votingPower = getVotes(voter, proposalSnapshot(proposalId));
            rewards[i] = (votingPower * totalReward) / totalVotes;
        }

        // Batch mint rewards
        rewardToken.batchMint(voters, rewards);

        // Emit events
        for (uint256 i = 0; i < voters.length; i++) {
            if (rewards[i] > 0) {
                emit ParticipantRewarded(proposalId, voters[i], rewards[i]);
            }
        }
    }

    /**
     * @dev Executes an external call as part of a proposal.
     * @param target The target address to call.
     * @param value The value to send with the call.
     * @param data The call data.
     */
    function proposeExternalCall(
        address target,
        uint256 value,
        bytes memory data,
        string memory description
    ) public returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = target;

        uint256[] memory values = new uint256[](1);
        values[0] = value;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;

        return propose(targets, values, calldatas, description);
    }

    /**
     * @dev Cancels a proposal if certain conditions are met.
     * @param targets The targets of the proposal.
     * @param values The values associated with the proposal.
     * @param calldatas The calldata for the proposal.
     * @param descriptionHash The hash of the proposal description.
     */
    function cancelProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external onlyRole(GOVERNOR_ROLE) returns (uint256) {
        uint256 proposalId = _cancel(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        emit ProposalCanceled(proposalId);
        return proposalId;
    }

    /**
     * @dev Pauses governance operations in case of emergencies.
     */
    function pause() external onlyRole(GOVERNOR_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses governance operations.
     */
    function unpause() external onlyRole(GOVERNOR_ROLE) {
        _unpause();
    }

    /**
     * @dev Sets the address of the Seed contract.
     * @param _seedAddress The address of the Seed contract.
     */
    function setSeedAddress(
        address _seedAddress
    ) public onlyRole(GOVERNOR_ROLE) {
        require(_seedAddress != address(0), "Invalid address");
        seedAddress = _seedAddress;
        emit SeedAddressUpdated(_seedAddress);
    }

    /**
     * @dev Rewards participants for their involvement in governance.
     * @param proposalId The ID of the proposal.
     * @param participant The address of the participant to reward.
     * @param amount The amount of tokens to reward.
     */
    function rewardParticipant(
        uint256 proposalId,
        address participant,
        uint256 amount
    ) external onlyRole(GOVERNOR_ROLE) {
        require(
            state(proposalId) == ProposalState.Executed ||
                state(proposalId) == ProposalState.Defeated,
            "Proposal not ended"
        );
        require(
            getVotes(participant, proposalSnapshot(proposalId)) > 0,
            "Participant did not vote"
        );

        rewardToken.mint(participant, amount);
        emit ParticipantRewarded(proposalId, participant, amount);
    }

    /**
     * @dev Executes a proposal on the Seed contract.
     * @param newValue The new value to store in the Seed contract.
     */
    function proposeExecutionOnSeed(
        uint256 newValue,
        string memory description
    ) public returns (uint256) {
        require(seedAddress != address(0), "Seed address not set");

        address[] memory targets = new address[](1);
        targets[0] = seedAddress;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", newValue);

        return propose(targets, values, calldatas, description);
    }

    // Override the _countVote function to track voters
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory params
    ) internal override(Governor, GovernorCountingSimple) {
        super._countVote(proposalId, account, support, weight, params);

        if (!_proposalVoters[proposalId][account]) {
            _proposalVoters[proposalId][account] = true;
            _proposalVotersList[proposalId].push(account);
        }
    }

    // Implement the getVotersForProposal function
    function getVotersForProposal(
        uint256 proposalId
    ) public view returns (address[] memory) {
        return _proposalVotersList[proposalId];
    }

    function getProposal(
        uint256 proposalId
    )
        public
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        )
    {
        Proposal storage proposal = _proposals[proposalId];
        return (
            proposal.targets,
            proposal.values,
            proposal.calldatas,
            proposal.description
        );
    }

    // Add this function to grant the REWARD_ROLE
    function grantRewardRole(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(REWARD_ROLE, account);
    }
}
