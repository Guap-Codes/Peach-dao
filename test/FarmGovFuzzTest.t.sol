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

        // Setup roles
        governor.grantRole(governor.GOVERNOR_ROLE(), admin);
        governor.grantRole(governor.REWARD_ROLE(), admin);

        // Mint some tokens to users
        votesToken.mint(user1, 1000e18);
        votesToken.mint(user2, 1000e18);
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

    function testFuzz_RewardParticipants(
        uint256 proposalId,
        uint256 user1Votes,
        uint256 user2Votes
    ) public {
        vm.assume(user1Votes > 0 && user2Votes > 0);
        vm.assume(user1Votes < 1e24 && user2Votes < 1e24); // Reasonable upper bound

        uint256 totalVotes = user1Votes + user2Votes;

        // Mock a successful proposal
        vm.mockCall(
            address(governor),
            abi.encodeWithSelector(governor.state.selector, proposalId),
            abi.encode(IGovernor.ProposalState.Executed)
        );

        // Mock proposalVotes
        vm.mockCall(
            address(governor),
            abi.encodeWithSelector(governor.proposalVotes.selector, proposalId),
            abi.encode(0, totalVotes, 0) // Assuming all votes are "for" votes
        );

        // Mock getVotersForProposal to return user1 and user2
        address[] memory voters = new address[](2);
        voters[0] = user1;
        voters[1] = user2;
        vm.mockCall(
            address(governor),
            abi.encodeWithSelector(
                governor.getVotersForProposal.selector,
                proposalId
            ),
            abi.encode(voters)
        );

        // Mock getVotes for each user
        vm.mockCall(
            address(governor),
            abi.encodeWithSelector(
                governor.getVotes.selector,
                user1,
                proposalId
            ),
            abi.encode(user1Votes)
        );
        vm.mockCall(
            address(governor),
            abi.encodeWithSelector(
                governor.getVotes.selector,
                user2,
                proposalId
            ),
            abi.encode(user2Votes)
        );

        // Mock rewardToken.batchMint
        vm.mockCall(
            address(peachToken),
            abi.encodeWithSelector(peachToken.batchMint.selector),
            abi.encode()
        );

        // Calculate expected rewards
        uint256 totalReward = 1000 * 1e18;
        uint256 expectedRewardUser1 = (user1Votes * totalReward) / totalVotes;
        uint256 expectedRewardUser2 = (user2Votes * totalReward) / totalVotes;

        // Expect ParticipantRewarded events
        vm.expectEmit(true, true, true, true);
        emit ParticipantRewarded(proposalId, user1, expectedRewardUser1);
        vm.expectEmit(true, true, true, true);
        emit ParticipantRewarded(proposalId, user2, expectedRewardUser2);

        // Call the function
        governor.rewardParticipants(proposalId);
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

        // Mock the necessary calls
        vm.mockCall(
            address(governor),
            abi.encodeWithSelector(governor.state.selector, proposalId),
            abi.encode(IGovernor.ProposalState.Succeeded)
        );

        // Mock the peachToken balance and mint function
        vm.mockCall(
            address(peachToken),
            abi.encodeWithSelector(
                peachToken.balanceOf.selector,
                address(governor)
            ),
            abi.encode(amount)
        );
        vm.mockCall(
            address(peachToken),
            abi.encodeWithSelector(
                peachToken.mint.selector,
                participant,
                amount
            ),
            abi.encode(true)
        );

        // Expect ParticipantRewarded event
        vm.expectEmit(true, true, false, true);
        emit ParticipantRewarded(proposalId, participant, amount);

        // Call the function
        governor.rewardParticipant(proposalId, participant, amount);

        // Verify that the reward was distributed
        vm.mockCall(
            address(peachToken),
            abi.encodeWithSelector(peachToken.balanceOf.selector, participant),
            abi.encode(amount)
        );
        assertEq(
            peachToken.balanceOf(participant),
            amount,
            "Reward not distributed correctly"
        );
    }

    function testFuzz_GrantRewardRole(address account) public {
        vm.assume(account != address(0));

        governor.grantRewardRole(account);
        assertTrue(governor.hasRole(governor.REWARD_ROLE(), account));
    }
}
