// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Seed is AccessControl, Pausable {
    bytes32 public constant STORE_ROLE = keccak256("STORE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 private value;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STORE_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    event ValueStored(uint256 newValue);

    function store(uint256 newValue) public onlyRole(STORE_ROLE) whenNotPaused {
        value = newValue;
        emit ValueStored(newValue);
    }

    function retrieve() public view returns (uint256) {
        return value;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
