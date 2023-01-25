// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../CommanderToken.sol";

contract CommanderTokenMintTest is CommanderToken {
    constructor(
        string memory name_,
        string memory symbol_
    ) CommanderToken(name_, symbol_) {}

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

    function setDefaultTransferable(bool transferable) external {
	defaultTransferable = transferable;
    }
	
    function setDefaultBurnable(bool burnable) external {
	defaultBurnable = burnable;
    }
}
