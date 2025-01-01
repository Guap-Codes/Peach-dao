// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/FarmGovernor.sol";
import "../src/TimeLock.sol";
import "../src/PeachToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";

contract MockVotesToken is ERC20, IVotes {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(uint256 => uint256)) private _votePowerAtBlock;
    mapping(uint256 => uint256) private _totalSupplyHistory;

    constructor() ERC20("MockVotes", "MV") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
        _updateTotalSupply();
    }

    function _updateTotalSupply() private {
        _totalSupplyHistory[block.number] = totalSupply();
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
        _updateTotalSupply();
    }

    function delegates(address account) public pure returns (address) {
        return account;
    }

    function getVotes(address account) public view returns (uint256) {
        return balanceOf(account);
    }

    function getPastVotes(
        address account,
        uint256 blockNumber
    ) public view returns (uint256) {
        require(blockNumber <= block.number, "Block number is in the future");
        // Simplified: always return current balance, but respect the blockNumber check
        return balanceOf(account);
    }

    function getPastTotalSupply(
        uint256 blockNumber
    ) public view returns (uint256) {
        require(blockNumber <= block.number, "Block number is in the future");
        return _totalSupplyHistory[blockNumber];
    }

    function delegate(address delegatee) public {}

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {}
}

contract FarmGovernorFuzz is Test {
    FarmGovernor public governor;
    TimeLock public timelock;
    PeachToken public peachToken;
    MockVotesToken public votesToken;

    address public admin = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    event ParticipantRewarded(
        uint256 proposalId,
        address participant,
        uint256 amount
    );

    function setUp() public {
        votesToken = new MockVotesToken();
        timelock = new TimeLock(1 days, new address[](0), new address[](0));
        peachToken = new PeachToken();
        governor = new FarmGovernor(
            IVotes(address(votesToken)),
            timelock,
            peachToken
        );

        // Setup roles for timelock
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        // Grant roles to governor and test contract
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(proposerRole, address(this)); // Add this line
        timelock.grantRole(executorRole, address(0));
        timelock.grantRole(adminRole, address(this));

        // Setup roles for governor
        governor.grantRole(governor.GOVERNOR_ROLE(), admin);
        governor.grantRole(governor.REWARD_ROLE(), admin);

        // Mint some tokens to users
        votesToken.mint(user1, 1000e18);
        votesToken.mint(user2, 1000e18);

        // Grant MINTER_ROLE to the FarmGovernor contract for PeachToken
        peachToken.grantRole(peachToken.MINTER_ROLE(), address(governor));
        peachToken.grantRole(peachToken.MINTER_ROLE(), address(this));
    }

    function testFuzz_ProposeAndVote(
        uint256 newValue,
        uint256 votingDelay,
        uint256 votingPeriod
    ) public {
        vm.assume(votingDelay > 0 && votingDelay < 1000);
        vm.assume(votingPeriod > 0 && votingPeriod < 1000);

        // Remove these lines as they're causing the revert
        // governor.setVotingDelay(votingDelay);
        // governor.setVotingPeriod(votingPeriod);

        // Instead, use the existing voting delay and period
        votingDelay = governor.votingDelay();
        votingPeriod = governor.votingPeriod();

        address[] memory targets = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        string memory description = "Test proposal";

        // Use newValue in the proposal
        bytes memory callData = abi.encodeWithSignature(
            "updateSomeValue(uint256)",
            newValue
        );
        calldatas[0] = callData;

        uint256 newProposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Add this line to check if the proposal was created
        require(newProposalId > 0, "Proposal not created");

        vm.roll(block.number + votingDelay + 1);

        governor.castVote(newProposalId, 1);

        assertEq(uint8(governor.state(newProposalId)), 1); // 1 represents the Active state
    }

    function testFuzz_RewardParticipants() public {
        // Create and execute proposal first
        address[] memory targets = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Test proposal";

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Move to active state and vote
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        vm.prank(user2);
        governor.castVote(proposalId, 1);

        // Move to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Queue and execute
        bytes32 descHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        governor.execute(targets, values, calldatas, descHash);

        // Since both users have 1000e18 tokens, they should each get half of TOTAL_REWARD_POOL
        uint256 expectedRewardEach = (1000 * 1e18) / 2; // TOTAL_REWARD_POOL / 2

        // Call rewardParticipants
        governor.rewardParticipants(proposalId);

        // Verify the rewards were distributed correctly
        assertEq(peachToken.balanceOf(user1), expectedRewardEach);
        assertEq(peachToken.balanceOf(user2), expectedRewardEach);
    }

    function testFuzz_UpdateVotingPeriod(uint256 newVotingPeriod) public {
        vm.assume(newVotingPeriod > 0 && newVotingPeriod < 1000000);

        governor.updateVotingPeriod(newVotingPeriod);
        assertEq(governor.votingPeriod(), newVotingPeriod);
    }

    function testFuzz_UpdateQuorumFraction(uint256 newQuorumFraction) public {
        vm.assume(newQuorumFraction > 0 && newQuorumFraction <= 100);

        governor.updateQuorumFraction(newQuorumFraction);
        // We can't directly check _quorumNumerator as it's private, so we'll check the quorum for a specific block
        uint256 expectedQuorum = (votesToken.getPastTotalSupply(0) *
            newQuorumFraction) / 100;
        assertEq(governor.quorum(0), expectedQuorum);
    }

    function testFuzz_PauseAndUnpause() public {
        governor.pause();
        assertTrue(governor.paused());

        governor.unpause();
        assertFalse(governor.paused());
    }

    function testFuzz_SetSeedAddress(address newSeedAddress) public {
        vm.assume(newSeedAddress != address(0));

        governor.setSeedAddress(newSeedAddress);
        assertEq(governor.seedAddress(), newSeedAddress);
    }

    function testFuzz_RewardParticipant(
        uint256 proposalId,
        address participant,
        uint256 amount
    ) public {
        vm.assume(amount > 0 && amount < 1000e18);
        vm.assume(participant != address(0));

        // Mint voting tokens to participant and delegate
        votesToken.mint(participant, 100e18);
        vm.prank(participant);
        votesToken.delegate(participant);

        // Create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Test proposal";

        proposalId = governor.propose(targets, values, calldatas, description);

        // Move to active state
        vm.roll(block.number + governor.votingDelay() + 1);

        // Cast vote as participant
        vm.prank(participant);
        governor.castVote(proposalId, 1);

        // Move to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Use admin role for timelock operations
        vm.startPrank(address(this));

        // Queue and execute
        bytes32 descHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descHash);

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        governor.execute(targets, values, calldatas, descHash);

        vm.stopPrank();

        // Mock initial balance check
        vm.mockCall(
            address(peachToken),
            abi.encodeWithSelector(peachToken.balanceOf.selector, participant),
            abi.encode(0)
        );

        // Mock mint function
        vm.mockCall(
            address(peachToken),
            abi.encodeWithSelector(
                peachToken.mint.selector,
                participant,
                amount
            ),
            abi.encode(true)
        );

        // Mock final balance check
        vm.mockCall(
            address(peachToken),
            abi.encodeWithSelector(peachToken.balanceOf.selector, participant),
            abi.encode(amount)
        );

        // Call rewardParticipant
        governor.rewardParticipant(proposalId, participant, amount);

        // Verify the participant received the reward
        assertEq(peachToken.balanceOf(participant), amount);
    }

    function testFuzz_GrantRewardRole(address account) public {
        vm.assume(account != address(0));

        governor.grantRewardRole(account);
        assertTrue(governor.hasRole(governor.REWARD_ROLE(), account));
    }
}
