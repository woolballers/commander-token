// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../CommanderTokenV2.sol";

contract CommanderTokenMintTest is CommanderTokenV2 {
    constructor(
        string memory name_,
        string memory symbol_
    ) CommanderTokenV2(name_, symbol_) {}

    function mint(address to, uint256 tokenId) external {
        // to do: change to _safeMint
        _mint(to, tokenId);
    }

    function mint(
        address toNFTContract,
        uint256 toNFTTokenId,
        uint256 tokenId
    ) external {
        // to do: change to _safeMint
        _mint(toNFTContract, toNFTTokenId, tokenId);
    }
}
