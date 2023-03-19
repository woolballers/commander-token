// SPDX-License-Identifier: MIT
// Contract for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./interfaces/ICommanderToken.sol";

/**
 * @dev Implementation of CommanderToken Standard
 */
contract CommanderToken is ICommanderToken, ERC721Enumerable {
    struct ExternalToken {
        ICommanderToken tokensCollection;
        uint256 tokenId;
    }

    struct Token {
        bool nontransferable;
        bool burnable;
        ExternalToken[] dependencies; // array of CTs the token depends on
        
        // manages the indices of dependencies
        mapping(address => mapping(uint256 => uint256)) dependenciesIndex;

        // a whitelist of addresses the token can be transferred to regardless of its transferable status
        mapping(address => bool)                        whitelist;
        

    }

    // verifies that the sender owns a token
    modifier approvedOrOwner(uint256 tokenId) {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    modifier onlyContract(address contractAddress) {
        require(
            contractAddress == msg.sender,
            "Commander Token: transaction is not sent by the correct contract"
        );
        _;
    }

    // mapping from token Id to token data
    mapping(uint256 => Token) private _tokens;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {}

    /**
     * Sets the dependenct of a Solider Token on a Commander token.
     * Recall, you can only transfer or burn a Token if all the Commander Tokens it depends on are
     * transferable or burnable, correspondingly.
     * Dependency is allowed only if both tokens have the same owner, use setDependenceUnsafe otherwise.
     * The caller must be the owner, opertaor or approved to use _tokenId.
     */
    function setDependence(
        uint256 tokenId,
        address CTContractAddress,
        uint256 CTId
    )
        public
        virtual
        override
        approvedOrOwner(tokenId)
    {
        // check that tokenId is not dependent already on CTId
        require(
            _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] == 0,
            "Commander Token: tokenId already depends on CTid from CTContractAddress"
        );

        // create ExternalToken variable to express the dependency
        ExternalToken memory newDependency; //TODO not sure memory is the location for this variable
        newDependency.tokensCollection = ICommanderToken(CTContractAddress);
        newDependency.tokenId = CTId;

        // save the index of the new dependency
        _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] =
            _tokens[tokenId].dependencies.length +
            1;

        // add dependency
        _tokens[tokenId].dependencies.push(newDependency);

    }

    // TODO: also CTContractAddress can remove
    /**
     * Removes the dependency of a Commander Token from a Private token.
     */
    function removeDependence(
        uint256 tokenId,
        address CTContractAddress,
        uint256 CTId
    ) public virtual override approvedOrOwner(tokenId) {
        // check that tokenId is indeed dependent on CTId
        require(
            _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] > 0,
            "Commander Token: tokenId is not dependent on CTid from contract CTContractAddress"
        );

        ICommanderToken CTContract = ICommanderToken(CTContractAddress);

        // the CTId needs to be transferable and burnable for the dependency to be remove,
        // otherwise, the owner of CTId could transfer it in any case, simply by removing all dependencies
        if (!CTContract.isTransferable(CTId))
            CTContract.setTransferable(CTId, true);

        if (!CTContract.isBurnable(CTId)) CTContract.setBurnable(CTId, true);

        // get the index of the token we are about to remove from dependencies
        uint256 dependencyIndex = _tokens[tokenId].dependenciesIndex[
            CTContractAddress
        ][CTId];

        // clear dependenciesIndex for this token
        _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] = 0;

        // remove dependency: copy the last element of the array to the place of what was removed, then remove the last element from the array
        uint256 lastDependecyIndex = _tokens[tokenId].dependencies.length - 1;
        _tokens[tokenId].dependencies[dependencyIndex] = _tokens[tokenId]
            .dependencies[lastDependecyIndex];
        _tokens[tokenId].dependencies.pop();
    }

    function isDependent(
        uint256 tokenId,
        address CTContractAddress,
        uint256 CTId
    ) public view virtual override returns (bool) {
        return
            _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] > 0
                ? true
                : false;
    }

    // TODO add also NFT owner
    function setTransferable(
        uint256 tokenId,
        bool transferable
    ) public virtual override approvedOrOwner(tokenId) {
        _tokens[tokenId].nontransferable = !transferable;
    }

    // TODO add also NFT owner
    function setBurnable(
        uint256 tokenId,
        bool burnable
    ) public virtual override approvedOrOwner(tokenId) {
        _tokens[tokenId].burnable = burnable;
    }

    function isTransferable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return !_tokens[tokenId].nontransferable;
    }

    function isBurnable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return _tokens[tokenId].burnable;
    }

    function isDependentTransferable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenId].dependencies.length; i++) {
            ICommanderToken CTContract = _tokens[tokenId]
                .dependencies[i]
                .tokensCollection;
            uint256 CTId = _tokens[tokenId].dependencies[i].tokenId;
            if (!CTContract.isTokenTransferable(CTId)) {
                return false;
            }
        }
        return true;
    }

    function isDependentBurnable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenId].dependencies.length; i++) {
            ICommanderToken CTContract = _tokens[tokenId]
                .dependencies[i]
                .tokensCollection;
            uint256 CTId = _tokens[tokenId].dependencies[i].tokenId;
            if (!CTContract.isTokenBurnable(CTId)) {
                return false;
            }
        }
        return true;
    }

    function isTokenTransferable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return isTransferable(tokenId) && isDependentTransferable(tokenId);
    }

    function isTokenBurnable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return isBurnable(tokenId) && isDependentBurnable(tokenId);
    }

    function burn(uint256 tokenId) public virtual override {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    // TODO: not sure about what I did here
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return
            interfaceId == type(ICommanderToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }


    /************************
     * Whitelist functions
     ************************/
    function setTransferWhitelist(
        uint256 tokenId, 
        address whitelistAddress,
        bool    isWhitelisted
    ) public virtual override approvedOrOwner(tokenId) {
        _tokens[tokenId].whitelist[whitelistAddress] = isWhitelisted;
    }

    function isTransferableToAddress(
        uint256 tokenId, 
        address addressToTransferTo
    ) public view virtual override returns (bool) {
        return _tokens[tokenId].whitelist[addressToTransferTo];
    }
    
    function isDependentTransferableToAddress(
        uint256 tokenId, 
        address transferToAddress
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenId].dependencies.length; i++) {
            ICommanderToken STContract = _tokens[tokenId]
                .dependencies[i]
                .tokensCollection;
            uint256 STId = _tokens[tokenId].dependencies[i].tokenId;

            if (!STContract.isTokenTransferableToAddress(STId, transferToAddress)) {
                return false;
            }
        }
        return true;
    }

    function isTokenTransferableToAddress(
        uint256 tokenId, 
        address transferToAddress
    ) public view virtual override returns (bool) {
        return isTransferableToAddress(tokenId, transferToAddress) && isDependentTransferableToAddress(tokenId, transferToAddress);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        // transfer each token that tokenId depends on
        for (uint i; i < _tokens[tokenId].dependencies.length; i++) {
            ICommanderToken STContract = _tokens[tokenId]
                .dependencies[i]
                .tokensCollection;
            uint256 STId = _tokens[tokenId].dependencies[i].tokenId;
            require(
                STContract.isTransferable(STId),
                "Commander Token: the token depends on at least one nontransferable token"
            );
            STContract.transferFrom(from, to, STId);
        }
    }
}
