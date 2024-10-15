# Aderyn Analysis Report

This report was generated by [Aderyn](https://github.com/Cyfrin/aderyn), a static analysis tool built by [Cyfrin](https://cyfrin.io), a blockchain security company. This report is not a substitute for manual audit or security review. It should not be relied upon for any purpose other than to assist in the identification of potential security vulnerabilities.
# Table of Contents

- [Summary](#summary)
  - [Files Summary](#files-summary)
  - [Files Details](#files-details)
  - [Issue Summary](#issue-summary)
- [Low Issues](#low-issues)
  - [L-1: Centralization Risk for trusted owners](#l-1-centralization-risk-for-trusted-owners)
  - [L-2: Deprecated OpenZeppelin functions should not be used](#l-2-deprecated-openzeppelin-functions-should-not-be-used)
  - [L-3: Solidity pragma should be specific, not wide](#l-3-solidity-pragma-should-be-specific-not-wide)
  - [L-4: Missing checks for `address(0)` when assigning values to address state variables](#l-4-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
  - [L-5: `public` functions not used internally could be marked `external`](#l-5-public-functions-not-used-internally-could-be-marked-external)
  - [L-6: Define and use `constant` variables instead of using literals](#l-6-define-and-use-constant-variables-instead-of-using-literals)
  - [L-7: Event is missing `indexed` fields](#l-7-event-is-missing-indexed-fields)
  - [L-8: PUSH0 is not supported by all chains](#l-8-push0-is-not-supported-by-all-chains)
  - [L-9: Internal functions called only once can be inlined](#l-9-internal-functions-called-only-once-can-be-inlined)
  - [L-10: Unused Imports](#l-10-unused-imports)
  - [L-11: State variable changes but no event is emitted.](#l-11-state-variable-changes-but-no-event-is-emitted)
  - [L-12: State variable could be declared immutable](#l-12-state-variable-could-be-declared-immutable)


# Summary

## Files Summary

| Key | Value |
| --- | --- |
| .sol Files | 4 |
| Total nSLOC | 443 |


## Files Details

| Filepath | nSLOC |
| --- | --- |
| src/FarmGovernor.sol | 351 |
| src/PeachToken.sol | 60 |
| src/Seed.sol | 25 |
| src/TimeLock.sol | 7 |
| **Total** | **443** |


## Issue Summary

| Category | No. of Issues |
| --- | --- |
| High | 0 |
| Low | 12 |


# Low Issues

## L-1: Centralization Risk for trusted owners

Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

<details><summary>19 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 29](src/FarmGovernor.sol#L29)

	```solidity
	    AccessControl,
	```

- Found in src/FarmGovernor.sol [Line: 246](src/FarmGovernor.sol#L246)

	```solidity
	    ) external onlyRole(GOVERNOR_ROLE) {
	```

- Found in src/FarmGovernor.sol [Line: 256](src/FarmGovernor.sol#L256)

	```solidity
	    ) external onlyRole(GOVERNOR_ROLE) {
	```

- Found in src/FarmGovernor.sol [Line: 266](src/FarmGovernor.sol#L266)

	```solidity
	    ) external onlyRole(REWARD_ROLE) {
	```

- Found in src/FarmGovernor.sol [Line: 341](src/FarmGovernor.sol#L341)

	```solidity
	    ) external onlyRole(GOVERNOR_ROLE) returns (uint256) {
	```

- Found in src/FarmGovernor.sol [Line: 355](src/FarmGovernor.sol#L355)

	```solidity
	    function pause() external onlyRole(GOVERNOR_ROLE) {
	```

- Found in src/FarmGovernor.sol [Line: 362](src/FarmGovernor.sol#L362)

	```solidity
	    function unpause() external onlyRole(GOVERNOR_ROLE) {
	```

- Found in src/FarmGovernor.sol [Line: 372](src/FarmGovernor.sol#L372)

	```solidity
	    ) public onlyRole(GOVERNOR_ROLE) {
	```

- Found in src/FarmGovernor.sol [Line: 387](src/FarmGovernor.sol#L387)

	```solidity
	    ) external onlyRole(GOVERNOR_ROLE) {
	```

- Found in src/FarmGovernor.sol [Line: 477](src/FarmGovernor.sol#L477)

	```solidity
	    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
	```

- Found in src/PeachToken.sol [Line: 14](src/PeachToken.sol#L14)

	```solidity
	contract PeachToken is ERC20, ERC20Permit, ERC20Votes, AccessControl, Pausable {
	```

- Found in src/PeachToken.sol [Line: 33](src/PeachToken.sol#L33)

	```solidity
	    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
	```

- Found in src/PeachToken.sol [Line: 41](src/PeachToken.sol#L41)

	```solidity
	    function pause() public onlyRole(PAUSER_ROLE) {
	```

- Found in src/PeachToken.sol [Line: 49](src/PeachToken.sol#L49)

	```solidity
	    function unpause() public onlyRole(PAUSER_ROLE) {
	```

- Found in src/PeachToken.sol [Line: 89](src/PeachToken.sol#L89)

	```solidity
	    ) public onlyRole(MINTER_ROLE) {
	```

- Found in src/Seed.sol [Line: 7](src/Seed.sol#L7)

	```solidity
	contract Seed is AccessControl, Pausable {
	```

- Found in src/Seed.sol [Line: 19](src/Seed.sol#L19)

	```solidity
	    function store(uint256 newValue) public onlyRole(STORE_ROLE) whenNotPaused {
	```

- Found in src/Seed.sol [Line: 27](src/Seed.sol#L27)

	```solidity
	    function pause() public onlyRole(PAUSER_ROLE) {
	```

- Found in src/Seed.sol [Line: 31](src/Seed.sol#L31)

	```solidity
	    function unpause() public onlyRole(PAUSER_ROLE) {
	```

</details>



## L-2: Deprecated OpenZeppelin functions should not be used

Openzeppelin has deprecated several functions and replaced with newer versions. Please consult https://docs.openzeppelin.com/

<details><summary>6 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 88](src/FarmGovernor.sol#L88)

	```solidity
	        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	```

- Found in src/FarmGovernor.sol [Line: 89](src/FarmGovernor.sol#L89)

	```solidity
	        _setupRole(GOVERNOR_ROLE, msg.sender);
	```

- Found in src/FarmGovernor.sol [Line: 90](src/FarmGovernor.sol#L90)

	```solidity
	        _setupRole(REWARD_ROLE, msg.sender);
	```

- Found in src/PeachToken.sol [Line: 22](src/PeachToken.sol#L22)

	```solidity
	        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	```

- Found in src/PeachToken.sol [Line: 23](src/PeachToken.sol#L23)

	```solidity
	        _setupRole(MINTER_ROLE, msg.sender);
	```

- Found in src/PeachToken.sol [Line: 24](src/PeachToken.sol#L24)

	```solidity
	        _setupRole(PAUSER_ROLE, msg.sender);
	```

</details>



## L-3: Solidity pragma should be specific, not wide

Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.0;`, use `pragma solidity 0.8.0;`

<details><summary>4 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 2](src/FarmGovernor.sol#L2)

	```solidity
	pragma solidity ^0.8.19;
	```

- Found in src/PeachToken.sol [Line: 2](src/PeachToken.sol#L2)

	```solidity
	pragma solidity ^0.8.19;
	```

- Found in src/Seed.sol [Line: 2](src/Seed.sol#L2)

	```solidity
	pragma solidity ^0.8.19;
	```

- Found in src/TimeLock.sol [Line: 2](src/TimeLock.sol#L2)

	```solidity
	pragma solidity ^0.8.19;
	```

</details>



## L-4: Missing checks for `address(0)` when assigning values to address state variables

Check for `address(0)` when assigning values to address state variables.

<details><summary>2 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 86](src/FarmGovernor.sol#L86)

	```solidity
	        rewardToken = _rewardToken;
	```

- Found in src/FarmGovernor.sol [Line: 87](src/FarmGovernor.sol#L87)

	```solidity
	        _timelock = _timelockController;
	```

</details>



## L-5: `public` functions not used internally could be marked `external`

Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

<details><summary>20 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 100](src/FarmGovernor.sol#L100)

	```solidity
	    function timelock() public view virtual override returns (address) {
	```

- Found in src/FarmGovernor.sol [Line: 106](src/FarmGovernor.sol#L106)

	```solidity
	    function votingDelay()
	```

- Found in src/FarmGovernor.sol [Line: 115](src/FarmGovernor.sol#L115)

	```solidity
	    function votingPeriod()
	```

- Found in src/FarmGovernor.sol [Line: 124](src/FarmGovernor.sol#L124)

	```solidity
	    function quorum(
	```

- Found in src/FarmGovernor.sol [Line: 180](src/FarmGovernor.sol#L180)

	```solidity
	    function proposalThreshold()
	```

- Found in src/FarmGovernor.sol [Line: 218](src/FarmGovernor.sol#L218)

	```solidity
	    function supportsInterface(
	```

- Found in src/FarmGovernor.sol [Line: 311](src/FarmGovernor.sol#L311)

	```solidity
	    function proposeExternalCall(
	```

- Found in src/FarmGovernor.sol [Line: 370](src/FarmGovernor.sol#L370)

	```solidity
	    function setSeedAddress(
	```

- Found in src/FarmGovernor.sol [Line: 406](src/FarmGovernor.sol#L406)

	```solidity
	    function proposeExecutionOnSeed(
	```

- Found in src/FarmGovernor.sol [Line: 453](src/FarmGovernor.sol#L453)

	```solidity
	    function getProposal(
	```

- Found in src/FarmGovernor.sol [Line: 475](src/FarmGovernor.sol#L475)

	```solidity
	    function grantRewardRole(
	```

- Found in src/PeachToken.sol [Line: 33](src/PeachToken.sol#L33)

	```solidity
	    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
	```

- Found in src/PeachToken.sol [Line: 41](src/PeachToken.sol#L41)

	```solidity
	    function pause() public onlyRole(PAUSER_ROLE) {
	```

- Found in src/PeachToken.sol [Line: 49](src/PeachToken.sol#L49)

	```solidity
	    function unpause() public onlyRole(PAUSER_ROLE) {
	```

- Found in src/PeachToken.sol [Line: 80](src/PeachToken.sol#L80)

	```solidity
	    function supportsInterface(
	```

- Found in src/PeachToken.sol [Line: 86](src/PeachToken.sol#L86)

	```solidity
	    function batchMint(
	```

- Found in src/Seed.sol [Line: 19](src/Seed.sol#L19)

	```solidity
	    function store(uint256 newValue) public onlyRole(STORE_ROLE) whenNotPaused {
	```

- Found in src/Seed.sol [Line: 23](src/Seed.sol#L23)

	```solidity
	    function retrieve() public view returns (uint256) {
	```

- Found in src/Seed.sol [Line: 27](src/Seed.sol#L27)

	```solidity
	    function pause() public onlyRole(PAUSER_ROLE) {
	```

- Found in src/Seed.sol [Line: 31](src/Seed.sol#L31)

	```solidity
	    function unpause() public onlyRole(PAUSER_ROLE) {
	```

</details>



## L-6: Define and use `constant` variables instead of using literals

If the same constant literal value is used multiple times, create a constant state variable and reference it throughout the contract.

<details><summary>4 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 81](src/FarmGovernor.sol#L81)

	```solidity
	        GovernorSettings(1, /* 1 block */ 50400, /* 1 week */ 0)
	```

- Found in src/FarmGovernor.sol [Line: 83](src/FarmGovernor.sol#L83)

	```solidity
	        GovernorVotesQuorumFraction(4)
	```

- Found in src/FarmGovernor.sol [Line: 91](src/FarmGovernor.sol#L91)

	```solidity
	        _customVotingPeriod = 50400; // Initial voting period
	```

- Found in src/FarmGovernor.sol [Line: 92](src/FarmGovernor.sol#L92)

	```solidity
	        _quorumNumerator = 4; // Initial quorum fraction
	```

</details>



## L-7: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

<details><summary>2 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 59](src/FarmGovernor.sol#L59)

	```solidity
	    event ProposalCreated(
	```

- Found in src/FarmGovernor.sol [Line: 424](src/FarmGovernor.sol#L424)

	```solidity
	    event ParticipantRewarded(
	```

</details>



## L-8: PUSH0 is not supported by all chains

Solc compiler version 0.8.20 switches the default target EVM version to Shanghai, which means that the generated bytecode will include PUSH0 opcodes. Be sure to select the appropriate EVM version in case you intend to deploy on a chain other than mainnet like L2 chains that may not support PUSH0, otherwise deployment of your contracts will fail.

<details><summary>4 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 2](src/FarmGovernor.sol#L2)

	```solidity
	pragma solidity ^0.8.19;
	```

- Found in src/PeachToken.sol [Line: 2](src/PeachToken.sol#L2)

	```solidity
	pragma solidity ^0.8.19;
	```

- Found in src/Seed.sol [Line: 2](src/Seed.sol#L2)

	```solidity
	pragma solidity ^0.8.19;
	```

- Found in src/TimeLock.sol [Line: 2](src/TimeLock.sol#L2)

	```solidity
	pragma solidity ^0.8.19;
	```

</details>



## L-9: Internal functions called only once can be inlined

Instead of separating the logic into a separate function, consider inlining the logic into the calling function. This can reduce the number of function calls and improve readability.

<details><summary>1 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 235](src/FarmGovernor.sol#L235)

	```solidity
	    function customCondition() internal pure returns (bool) {
	```

</details>



## L-10: Unused Imports

Redundant import statement. Consider removing it.

<details><summary>1 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 14](src/FarmGovernor.sol#L14)

	```solidity
	import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
	```

</details>



## L-11: State variable changes but no event is emitted.

State variable changes in this function but no event is emitted.

<details><summary>4 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 244](src/FarmGovernor.sol#L244)

	```solidity
	    function updateVotingPeriod(
	```

- Found in src/FarmGovernor.sol [Line: 254](src/FarmGovernor.sol#L254)

	```solidity
	    function updateQuorumFraction(
	```

- Found in src/FarmGovernor.sol [Line: 370](src/FarmGovernor.sol#L370)

	```solidity
	    function setSeedAddress(
	```

- Found in src/Seed.sol [Line: 19](src/Seed.sol#L19)

	```solidity
	    function store(uint256 newValue) public onlyRole(STORE_ROLE) whenNotPaused {
	```

</details>



## L-12: State variable could be declared immutable

State variables that are should be declared immutable to save gas. Add the `immutable` attribute to state variables that are only changed in the constructor

<details><summary>2 Found Instances</summary>


- Found in src/FarmGovernor.sol [Line: 32](src/FarmGovernor.sol#L32)

	```solidity
	    PeachToken public rewardToken;
	```

- Found in src/FarmGovernor.sol [Line: 33](src/FarmGovernor.sol#L33)

	```solidity
	    TimeLock private _timelock;
	```

</details>


