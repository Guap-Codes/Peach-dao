# FarmGovernor

FarmGovernor is a custom implementation of a governance contract using OpenZeppelin's framework with added functionalities. It's designed to manage decentralized decision-making processes for a farming or agricultural-related decentralized application (DApp).

## Features

- Customizable voting periods and quorum requirements
- Timelock functionality for delayed execution of proposals
- Reward system for governance participants
- Pausable governance operations for emergency situations
- Integration with a custom reward token (PeachToken)
- Ability to execute proposals on an external Seed contract

## Contract Structure

The FarmGovernor contract inherits from several OpenZeppelin contracts:

- Governor
- GovernorSettings
- GovernorCountingSimple
- GovernorVotes
- GovernorVotesQuorumFraction
- GovernorTimelockControl
- AccessControl
- Pausable

## Key Functions

- `updateVotingPeriod`: Allows governors to change the voting period
- `updateQuorumFraction`: Allows governors to update the quorum requirement
- `rewardParticipant`: Mints and distributes rewards to governance participants
- `executeExternalCall`: Allows governors to execute external calls
- `cancelProposal`: Allows governors to cancel proposals
- `pause` and `unpause`: Controls for pausing governance operations
- `setSeedAddress`: Sets the address of the Seed contract
- `executeProposalOnSeed`: Executes a proposal on the Seed contract

## Setup and Deployment

1. Install dependencies:
   ```
   npm install @openzeppelin/contracts
   ```

2. Deploy the TimeLock, PeachToken, and any other required contracts.

3. Deploy the FarmGovernor contract, providing the addresses of the governance token, TimeLock, and PeachToken as constructor arguments.

## Usage

1. Create a proposal using the `propose` function.
2. Vote on proposals using the inherited voting functions from OpenZeppelin's Governor contract.
3. Execute passed proposals using the `execute` function.
4. Governors can manage the contract using functions like `updateVotingPeriod`, `updateQuorumFraction`, `pause`, etc.

## Security Considerations

- The contract uses OpenZeppelin's battle-tested contracts as a foundation, which provides a good level of security.
- Access control is implemented using OpenZeppelin's AccessControl, with a GOVERNOR_ROLE for privileged operations.
- The contract is Pausable, allowing for emergency stops if needed.
- Always ensure that only trusted addresses are given the GOVERNOR_ROLE.

## License

This project is licensed under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Disclaimer

This code is provided as-is and has not been audited. Use at your own risk in production environments.