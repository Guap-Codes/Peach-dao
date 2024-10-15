// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title TimeLock
 * @dev A contract that controls the time delay for executing proposals.
 */
contract TimeLock is TimelockController {
    /**
     * @dev Initializes the contract with the specified parameters.
     * @param minDelay The minimum delay before executing a proposal.
     * @param proposers The list of addresses that can propose.
     * @param executors The list of addresses that can execute.
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) TimelockController(minDelay, proposers, executors, msg.sender) {}
}
