// SPDX-License-Identifier: MIT
// Contract for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./interfaces/ICommanderToken.sol";

/**
 * @title Commander Token Interface
 * @author Eyal Ron, Tomer Leicht, Ahmad Afuni
 * @dev Commander Tokens is an extenntion to ERC721 with the ability to create non-transferable or non-burnable tokens.
 * @dev For this cause we add a new mechniasm enabling a token to depend on another token.
 * @dev If Token A depends on B, then if Token B is nontransferable or unburnable, so does Token A.
 * @dev if token B depedns on token A, we again call A a Commander Token (CT).
 */
contract CommanderToken is ICommanderToken, ERC721Enumerable {
    struct ExternalToken {
        ICommanderToken tokensCollection;
        uint256 tokenId;
    }

    struct Token {
        bool nontransferable;
        bool burnable;

        // The CTs the Token depends on
        ExternalToken[] dependencies;
        
        // Manages the indices of dependencies
        mapping(address => mapping(uint256 => uint256)) dependenciesIndex;

        // A whitelist of addresses the token can be transferred to regardless of the value of "nontransferable"
        mapping(address => bool)                        whitelist;
    }

    modifier approvedOrOwner(uint256 tokenId) {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    // Token Id -> token's data
    mapping(uint256 => Token) private _tokens;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    /**
     * @dev Adds to tokenId dependency on CTId from contract CTContractAddress.
     * @dev Recall, you can only transfer or burn a Token if all the Commander Tokens it depends on are
     * @dev transferable or burnable, correspondingly.
     * @dev Dependency is allowed only if both tokens have the same owner, use setDependenceUnsafe otherwise.
     * @dev The caller must be the owner, opertaor or approved to use _tokenId.
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
        ExternalToken memory newDependency;
        newDependency.tokensCollection = ICommanderToken(CTContractAddress);
        newDependency.tokenId = CTId;

        // save the index of the new dependency
        _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] =
            _tokens[tokenId].dependencies.length +
            1;

        // add dependency
        _tokens[tokenId].dependencies.push(newDependency);

    }

    /**
     * @dev Removes from tokenId the dependency on CTId from contract CTContractAddress.
     */
    function removeDependence(
        uint256 tokenId,
        address CTContractAddress,
        uint256 CTId
    ) public virtual override {
        ICommanderToken CTContract = ICommanderToken(CTContractAddress);

        // dependency is removed either by CTContractAddress, or by the owner if
        // the CTId is transferable and burnable.
        require(
            ( _isApprovedOrOwner(msg.sender, tokenId) &&
            CTContract.isTransferable(CTId) &&
            CTContract.isBurnable(CTId) ) ||
            ( msg.sender == CTContractAddress),
            "Commander Token: sender is not permitted to remove dependency"
        );

        // check that tokenId is indeed dependent on CTId
        require(
            _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] > 0,
            "Commander Token: tokenId is not dependent on CTid from contract CTContractAddress"
        );

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

    /**
     * @dev Checks if tokenId depends on CTId from CTContractAddress.
     **/
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

    /**
     * @dev Sets the transferable status of tokenId.
     **/
    function setTransferable(
        uint256 tokenId,
        bool transferable
    ) public virtual override approvedOrOwner(tokenId) {
        _tokens[tokenId].nontransferable = !transferable;
    }

    /**
     * @dev Sets the burnable status of tokenId.
     **/
    function setBurnable(
        uint256 tokenId,
        bool burnable
    ) public virtual override approvedOrOwner(tokenId) {
        _tokens[tokenId].burnable = burnable;
    }

    /**
     * @dev Checks the transferable status of tokenId.
     **/
    function isTransferable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return !_tokens[tokenId].nontransferable;
    }

    /**
     * @dev Checks the burnable status of tokenId.
     **/
    function isBurnable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return _tokens[tokenId].burnable;
    }

    /**
     * @dev Checks all the tokens that tokenId depends on are transferable.
     **/
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

    /**
     * @dev Checks all the tokens that tokenId depends on are burnable.
     **/
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

    /**
     * @dev Checks if tokenId can be transferred.
     **/
    function isTokenTransferable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return isTransferable(tokenId) && isDependentTransferable(tokenId);
    }

    /**
     * @dev Checks if tokenId can be burned.
     **/
    function isTokenBurnable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return isBurnable(tokenId) && isDependentBurnable(tokenId);
    }

    /**
     * @dev burns tokenId.
     * @dev isTokenBurnable must return 'true'.
     **/
    function burn(uint256 tokenId) public virtual override {}

    /************************
     * Whitelist functions  *
     ************************/

     /**
      * @dev Adds or removes an address from the whiltelist of tokenId.
      * @dev tokenId can be transferred to whitelisted addresses even when its set to be nontransferable.
      **/
    function setTransferWhitelist(
        uint256 tokenId, 
        address whitelistAddress,
        bool    isWhitelisted
    ) public virtual override approvedOrOwner(tokenId) {
        _tokens[tokenId].whitelist[whitelistAddress] = isWhitelisted;
    }

    /**
      * @dev Checks if tokenId can be transferred to addressToTransferTo, without taking its dependence into consideration.
      **/
    function isTransferableToAddress(
        uint256 tokenId, 
        address addressToTransferTo
    ) public view virtual override returns (bool) {
        return _tokens[tokenId].whitelist[addressToTransferTo];
    }
    
    /**
      * @dev Checks if all the dependences of tokenId can be transferred to addressToTransferTo,
      **/
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

    /**
      * @dev Checks if tokenId can be transferred to addressToTransferTo.
      **/
    function isTokenTransferableToAddress(
        uint256 tokenId, 
        address transferToAddress
    ) public view virtual override returns (bool) {
        return isTransferableToAddress(tokenId, transferToAddress) && isDependentTransferableToAddress(tokenId, transferToAddress);
    }

    /***********************************************
     * Overrided functions from ERC165 and ERC721  *
     ***********************************************/
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return
            interfaceId == type(ICommanderToken).interfaceId ||
            super.supportsInterface(interfaceId);
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
