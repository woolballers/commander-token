// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../CommanderTokenV3.sol";

contract MintTest is CommanderTokenV3 {
    constructor(
        string memory name_,
        string memory symbol_
    ) CommanderTokenV3(name_, symbol_) {}

    function mint(address to, uint256 tokenId) external {
        // to do: change to _safeMint
        _mint(to, tokenId);
    }
}
