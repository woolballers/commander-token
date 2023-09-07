// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../CommanderToken.sol";

contract MintCommanderTokenTest is CommanderToken {
    constructor(
        string memory name_,
        string memory symbol_
    ) CommanderToken(name_, symbol_) {}

    function mint(address to, uint256 tokenID) external {
        // to do: change to _safeMint
        _mint(to, tokenID);
    }
}
