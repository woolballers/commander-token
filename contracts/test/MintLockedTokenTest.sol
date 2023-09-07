// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../LockedToken.sol";

contract MintLockedTokenTest is LockedToken {
    constructor(
        string memory name_,
        string memory symbol_
    ) LockedToken(name_, symbol_) {}

    function mint(address to, uint256 tokenID) external {
        // to do: change to _safeMint
        _mint(to, tokenID);
    }
}
