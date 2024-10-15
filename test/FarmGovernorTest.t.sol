// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {FarmGovernor} from "../src/FarmGovernor.sol";
import {PeachToken} from "../src/PeachToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Seed} from "../src/Seed.sol";
import {console} from "forge-std/console.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract FarmGovernorTest is Test {
    PeachToken token;
    TimeLock timelock;
    FarmGovernor governor;
    Seed seed;

    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote passes, you have 1 hour before you can enact
    uint256 public constant QUORUM_PERCENTAGE = 4; // Need 4% of voters to pass
    uint256 public constant VOTING_PERIOD = 50400; // This is how long voting lasts
    uint256 public constant VOTING_DELAY = 1; // How many blocks till a proposal vote becomes active

    address[] proposers;
    address[] executors;

    bytes[] functionCalls;
    address[] addressesToCall;
    uint256[] values;

    address public constant VOTER = address(1);
    address public constant VOTER2 = address(2);
    address public constant VOTER3 = address(3);

    function setUp() public {
        token = new PeachToken();
        token.mint(VOTER, 100e18);
        token.mint(VOTER2, 100e18);
        token.mint(VOTER3, 100e18);

        vm.prank(VOTER);
        token.delegate(VOTER);
        vm.prank(VOTER2);
        token.delegate(VOTER2);
        vm.prank(VOTER3);
        token.delegate(VOTER3);

        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new FarmGovernor(token, timelock, token); // Using PeachToken as both governance and reward token

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, msg.sender);

        seed = new Seed();
        seed.grantRole(seed.DEFAULT_ADMIN_ROLE(), address(timelock));
        seed.grantRole(seed.STORE_ROLE(), address(governor));
        seed.grantRole(seed.STORE_ROLE(), address(timelock));
        seed.grantRole(seed.PAUSER_ROLE(), address(governor));

        governor.setSeedAddress(address(seed)); // Set the seed address in the governor

        // Grant roles to the test contract
        governor.grantRole(governor.DEFAULT_ADMIN_ROLE(), address(this));
        governor.grantRole(governor.GOVERNOR_ROLE(), address(this));
    }

    function testCantUpdateSeedWithoutGovernance() public {
        console.log("Testing: Cannot update seed without governance");
        vm.prank(VOTER);
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000000001 is missing role 0x9cf888df9829983a4501c3e5076732bbf523e06c6b31f6ce065f61c2aec20567"
        );
        seed.store(1);
    }

    function testGovernanceUpdatesSeed() public {
        uint256 valueToStore = 777;
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(
            valueToStore
        );

        // Check the initial state
        console.log("Initial Seed value:", seed.retrieve());
        console.log(
            "Initial proposal state:",
            uint256(governor.state(proposalId))
        );

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast votes from multiple voters to meet quorum
        vm.prank(VOTER);
        governor.castVote(proposalId, 1); // Vote in favor
        vm.prank(VOTER2);
        governor.castVote(proposalId, 1); // Vote in favor
        vm.prank(VOTER3);
        governor.castVote(proposalId, 1); // Vote in favor

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Check if the proposal succeeded
        console.log(
            "Proposal state after voting:",
            uint256(governor.state(proposalId))
        );

        // Queue the proposal
        governor.queue(addressesToCall, values, functionCalls, descriptionHash);

        // Check the state after queueing
        console.log(
            "Proposal state after queueing:",
            uint256(governor.state(proposalId))
        );

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // Execute the proposal
        governor.execute(
            addressesToCall,
            values,
            functionCalls,
            descriptionHash
        );

        // Check the final state
        console.log("Final Seed value:", seed.retrieve());
        console.log(
            "Final proposal state:",
            uint256(governor.state(proposalId))
        );

        assert(seed.retrieve() == valueToStore);
    }

    function testVoteAgainstProposal() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(888);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(VOTER);
        governor.castVote(proposalId, 0); // Vote against

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        assert(governor.state(proposalId) == IGovernor.ProposalState.Defeated);

        // Use descriptionHash to verify the proposal details
        (, , , string memory description) = governor.getProposal(proposalId);

        assert(keccak256(bytes(description)) == descriptionHash);
    }

    function testAbstainFromProposal() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(999);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(VOTER);
        governor.castVote(proposalId, 2); // Abstain

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        assert(governor.state(proposalId) == IGovernor.ProposalState.Defeated);

        // Verify the proposal details using descriptionHash
        (
            ,
            ,
            ,
            /* address[] memory proposalTargets*/ /* uint256[] memory proposalValues*/ /* bytes[] memory proposalCalldatas*/ string
                memory proposalDescription
        ) = governor.getProposal(proposalId);

        assert(keccak256(bytes(proposalDescription)) == descriptionHash);
    }

    function testMultipleVoters() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(1111);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(VOTER);
        governor.castVote(proposalId, 1); // Vote in favor
        vm.prank(VOTER2);
        governor.castVote(proposalId, 1); // Vote in favor
        vm.prank(VOTER3);
        governor.castVote(proposalId, 0); // Vote against

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        assert(governor.state(proposalId) == IGovernor.ProposalState.Succeeded);

        // Verify the proposal details using descriptionHash
        (
            ,
            ,
            ,
            /* address[] memory proposalTargets */ /* uint256[] memory proposalValues*/ /* bytes[] memory proposalCalldatas */ string
                memory proposalDescription
        ) = governor.getProposal(proposalId);

        assert(keccak256(bytes(proposalDescription)) == descriptionHash);
    }

    function testFailedProposalDueToQuorum() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(2222);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Only one voter with 100 tokens, not enough for quorum
        vm.prank(VOTER);
        governor.castVote(proposalId, 1); // Vote in favor

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        assert(governor.state(proposalId) == IGovernor.ProposalState.Defeated);

        // Use descriptionHash to verify the proposal details
        (
            ,
            ,
            ,
            /*address[] memory proposalTargets*/ /*uint256[] memory proposalValues*/ /* bytes[] memory proposalCalldatas*/ string
                memory proposalDescription
        ) = governor.getProposal(proposalId);

        assert(keccak256(bytes(proposalDescription)) == descriptionHash);
    }

    function testExecuteProposalBeforeVotingPeriodEnds() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(3333);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(VOTER);
        governor.castVote(proposalId, 1); // Vote in favor

        // Try to execute before voting period ends
        vm.expectRevert();
        governor.execute(
            addressesToCall,
            values,
            functionCalls,
            descriptionHash
        );
    }

    function testQueueFailedProposal() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(4444);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(VOTER);
        governor.castVote(proposalId, 0); // Vote against

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Try to queue a failed proposal
        vm.expectRevert();
        governor.queue(addressesToCall, values, functionCalls, descriptionHash);

        // Verify that the proposal state is indeed Defeated
        assert(governor.state(proposalId) == IGovernor.ProposalState.Defeated);
    }

    function testUpdateVotingPeriod() public {
        uint256 newVotingPeriod = 100000;

        // Create a proposal to update the voting period
        bytes memory callData = abi.encodeWithSignature(
            "updateVotingPeriod(uint256)",
            newVotingPeriod
        );
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory proposalValues = new uint256[](1);
        proposalValues[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;
        string memory description = "Update voting period";

        // Ensure the governor has the necessary role to update voting period
        governor.grantRole(governor.GOVERNOR_ROLE(), address(timelock));

        uint256 proposalId = governor.propose(
            targets,
            proposalValues,
            calldatas,
            description
        );

        // Fast forward to active proposal state
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Vote on the proposal (ensure quorum is met)
        vm.prank(VOTER);
        governor.castVote(proposalId, 1); // Vote in favor
        vm.prank(VOTER2);
        governor.castVote(proposalId, 1); // Vote in favor
        vm.prank(VOTER3);
        governor.castVote(proposalId, 1); // Vote in favor

        // Fast forward to end of voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, proposalValues, calldatas, descriptionHash);

        // Fast forward past the minimum delay
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // Execute the proposal
        governor.execute(targets, proposalValues, calldatas, descriptionHash);

        // Check if the voting period has been updated
        assertEq(
            governor.votingPeriod(),
            newVotingPeriod,
            "Voting period should be updated"
        );
    }

    function testUpdateQuorumFraction() public {
        uint256 newQuorumFraction = 10;

        // Log initial quorum fraction
        console.log("Initial quorum fraction:", governor.quorumNumerator());

        vm.prank(address(this));
        governor.updateQuorumFraction(newQuorumFraction);

        // Log updated quorum fraction
        console.log("Updated quorum fraction:", governor.quorumNumerator());

        // Move to active state
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Calculate expected quorum
        uint256 totalSupply = token.totalSupply();
        uint256 expectedQuorum = (totalSupply * newQuorumFraction) / 100;

        // Get actual quorum
        uint256 actualQuorum = governor.quorum(block.number - 1);

        // Log values for debugging
        console.log("Total supply:", totalSupply);
        console.log("Expected quorum:", expectedQuorum);
        console.log("Actual quorum:", actualQuorum);

        // Assert
        assertEq(
            actualQuorum,
            expectedQuorum,
            "Quorum should match the new fraction"
        );
    }

    function testRewardParticipants() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(5555);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(VOTER);
        governor.castVote(proposalId, 1);
        vm.prank(VOTER2);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        governor.queue(addressesToCall, values, functionCalls, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        governor.execute(
            addressesToCall,
            values,
            functionCalls,
            descriptionHash
        );

        // Ensure the governor has enough tokens to reward participants
        uint256 rewardAmount = 10e18; // Adjust this value based on your reward logic
        token.mint(address(governor), rewardAmount * 2); // Mint enough for both voters

        uint256 initialBalance = token.balanceOf(VOTER);
        uint256 initialGovernorBalance = token.balanceOf(address(governor));

        // Grant the REWARD_ROLE to the test contract
        bytes32 rewardRole = governor.REWARD_ROLE();
        vm.prank(address(governor));
        governor.grantRole(rewardRole, address(this));

        // Call rewardParticipants
        governor.rewardParticipants(proposalId);

        uint256 finalBalance = token.balanceOf(VOTER);
        uint256 finalGovernorBalance = token.balanceOf(address(governor));

        console.log("Initial VOTER balance:", initialBalance);
        console.log("Final VOTER balance:", finalBalance);
        console.log("Initial Governor balance:", initialGovernorBalance);
        console.log("Final Governor balance:", finalGovernorBalance);

        assertGt(
            finalBalance,
            initialBalance,
            "VOTER balance should increase after reward"
        );
        assertLt(
            finalGovernorBalance,
            initialGovernorBalance,
            "Governor balance should decrease after reward"
        );
    }

    function testCancelProposal() public {
        // Create a proposal
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(6666);

        // Get the proposer (usually the address that created the proposal)
        address proposer = address(this);

        // Ensure the proposer has the necessary role to cancel
        governor.grantRole(governor.PROPOSER_ROLE(), proposer);

        // Cancel the proposal as the proposer
        vm.prank(proposer);
        governor.cancelProposal(
            addressesToCall,
            values,
            functionCalls,
            descriptionHash
        );

        // Assert that the proposal state is now Canceled
        assert(governor.state(proposalId) == IGovernor.ProposalState.Canceled);
    }

    function testPauseAndUnpause() public {
        // Ensure the governor has the GOVERNOR_ROLE
        governor.grantRole(governor.GOVERNOR_ROLE(), address(governor));

        vm.prank(address(governor));
        governor.pause();

        // Verify that the contract is paused
        assertTrue(governor.paused(), "Contract should be paused");

        // Try to create a proposal while paused
        vm.expectRevert("FarmGovernor: paused");
        _createProposal(7777);

        vm.prank(address(governor));
        governor.unpause();

        // Verify that the contract is unpaused
        assertFalse(governor.paused(), "Contract should be unpaused");

        // Should work after unpausing
        (uint256 proposalId, ) = _createProposal(7777);
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "Proposal should be in Pending state"
        );
    }

    function testAccessControl() public {
        // Try to update voting period without GOVERNOR_ROLE
        vm.prank(VOTER);
        vm.expectRevert();
        governor.updateVotingPeriod(1000);

        // Grant GOVERNOR_ROLE to VOTER
        vm.prank(address(governor));
        governor.grantRole(governor.GOVERNOR_ROLE(), VOTER);

        // Should work now
        vm.prank(VOTER);
        governor.updateVotingPeriod(1000);
    }

    function testSetInvalidSeedAddress() public {
        vm.prank(address(governor));
        vm.expectRevert(
            "AccessControl: account 0xf62849f9a0b5bf2913b396098f7c7019b51a820a is missing role 0x7935bd0ae54bc31f548c14dba4d37c5c64b3f8ca900cb468fb8abd54d5894f55"
        );
        governor.setSeedAddress(address(0));
    }

    function _createProposal(
        uint256 valueToStore
    ) internal returns (uint256, bytes32) {
        string memory description = "Store value in Seed";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "store(uint256)",
            valueToStore
        );
        addressesToCall = [address(seed)];
        values = [0];
        functionCalls = [encodedFunctionCall];

        uint256 proposalId = governor.propose(
            addressesToCall,
            values,
            functionCalls,
            description
        );

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        return (proposalId, descriptionHash);
    }

    function testProposalCreation() public {
        governor.grantRole(governor.PROPOSER_ROLE(), address(this));
        (, bytes32 descriptionHash) = _createProposal(888);
        bytes32 expectedHash = keccak256(bytes("Store value in Seed"));
        assertEq(descriptionHash, expectedHash, "Description hash mismatch");
    }

    function testProposalExecution() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(888);

        // Define proposal details
        address[] memory targets = new address[](1);
        targets[0] = address(seed);

        uint256[] memory proposalValues = new uint256[](1);
        proposalValues[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 888);

        // Advance time to voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast votes from multiple voters to meet quorum
        vm.prank(VOTER);
        governor.castVote(proposalId, 1); // Vote in favor
        vm.prank(VOTER2);
        governor.castVote(proposalId, 1); // Vote in favor
        vm.prank(VOTER3);
        governor.castVote(proposalId, 1); // Vote in favor

        // Advance time to end of voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Check proposal state before queueing
        require(
            governor.state(proposalId) == IGovernor.ProposalState.Succeeded,
            "Proposal should be in Succeeded state"
        );

        // Queue the proposal
        governor.queue(targets, proposalValues, calldatas, descriptionHash);

        // Check proposal state after queueing
        require(
            governor.state(proposalId) == IGovernor.ProposalState.Queued,
            "Proposal should be in Queued state"
        );

        // Advance time to after timelock
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // Execute the proposal
        governor.execute(targets, proposalValues, calldatas, descriptionHash);

        // Verify the execution
        assertEq(seed.retrieve(), 888, "Seed value should be updated to 888");
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "Proposal should be in Executed state"
        );
    }

    function testProposalCancellation() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(888);

        // Define proposal details
        address[] memory targets = new address[](1);
        targets[0] = address(seed); // Assuming 'seed' is your target contract

        uint256[] memory proposalValues = new uint256[](1);
        proposalValues[0] = 0; // No ETH being sent

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 888);

        // Assuming your FarmGovernor has a cancelProposal function
        governor.cancelProposal(
            targets,
            proposalValues,
            calldatas,
            descriptionHash
        );

        assert(governor.state(proposalId) == IGovernor.ProposalState.Canceled);
    }

    function testProposalState() public {
        (uint256 proposalId, bytes32 descriptionHash) = _createProposal(888);
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(
            uint256(state),
            uint256(IGovernor.ProposalState.Pending),
            "Incorrect initial state"
        );

        // Verify the proposal details using descriptionHash
        (, , , string memory description) = governor.getProposal(proposalId);

        assertEq(
            keccak256(bytes(description)),
            descriptionHash,
            "Description hash mismatch"
        );
    }

    function testSeedInitialValue() public {
        assertEq(seed.retrieve(), 0, "Initial value should be 0");
    }

    function testSeedStoreAndRetrieve() public {
        uint256 newValue = 42;
        vm.prank(address(governor));
        seed.store(newValue);
        assertEq(
            seed.retrieve(),
            newValue,
            "Retrieved value should match stored value"
        );
    }

    function testSeedStoreWithoutRole() public {
        vm.prank(VOTER);
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000000001 is missing role 0x9cf888df9829983a4501c3e5076732bbf523e06c6b31f6ce065f61c2aec20567"
        );
        seed.store(10);
    }

    function testSeedStoreWithRole() public {
        vm.prank(address(governor));
        seed.store(10);
        assertEq(
            seed.retrieve(),
            10,
            "Value should be stored when called with proper role"
        );
    }

    function testSeedPauseWithoutRole() public {
        vm.prank(VOTER);
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000000001 is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
        );
        seed.pause();
    }

    function testSeedPauseWithRole() public {
        vm.prank(address(governor));
        seed.pause();
        assertTrue(seed.paused(), "Seed should be paused");
    }

    function testSeedRoleManagement() public {
        // Test granting and revoking roles
        vm.prank(address(timelock));
        seed.grantRole(seed.STORE_ROLE(), VOTER);
        assertTrue(
            seed.hasRole(seed.STORE_ROLE(), VOTER),
            "VOTER should have STORE_ROLE"
        );

        vm.prank(address(timelock));
        seed.revokeRole(seed.STORE_ROLE(), VOTER);
        assertFalse(
            seed.hasRole(seed.STORE_ROLE(), VOTER),
            "VOTER should not have STORE_ROLE after revocation"
        );
    }
}
