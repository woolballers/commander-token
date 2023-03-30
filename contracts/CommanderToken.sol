// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./interfaces/ICommanderToken.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

/**
 * @title Commander Token Reference Implementation
 * @author Eyal Ron, Tomer Leicht, Ahmad Afuni
 * @dev Commander Tokens is an extension to ERC721 with the ability to create non-transferable or non-burnable tokens.
 * @dev For this cause, we add a new mechanism enabling a token to depend on another token.
 * @dev If Token A depends on B, then if Token B is nontransferable or unburnable, so does Token A.
 * @dev If token B depedns on token A, we again call A a Commander Token (CT).
 */
contract CommanderToken is ICommanderToken, ERC721 {
    struct ExternalToken {
        ICommanderToken tokensCollection;
        uint256 tokenId;
    }

    struct Token {
        bool nontransferable;
        bool nonburnable;

        // The Commander Tokens this Token struct depends on
        ExternalToken[] dependencies;
        
        // A mapping to manage the indices of "dependencies"
        mapping(address => mapping(uint256 => uint256)) dependenciesIndex;

        // A whitelist of addresses the token can be transferred to regardless of the value of "nontransferable"
        // Note: an address can be whitelisted but the token still won't be transferable to this address 
        // if it depends on a nontransferable token
        mapping(address => bool)                        whitelist;
    }

    modifier approvedOrOwner(uint256 tokenId) {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    // Token ID -> token's data
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
     * @dev A token can be transfered or burned only if all the tokens it depends on are transferable or burnable, correspondingly.
     * @dev The caller must be the owner, opertaor or approved to use tokenId.
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
        // checks that tokenId is not dependent already on CTId
        require(
            _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] == 0,
            "Commander Token: tokenId already depends on CTid from CTContractAddress"
        );

        // creates ExternalToken variable to express the new dependency
        ExternalToken memory newDependency;
        newDependency.tokensCollection = ICommanderToken(CTContractAddress);
        newDependency.tokenId = CTId;

        // saves the index of the new dependency
        // we need to add '1' to the index since the first index is '0', but '0' is also 
        // the default value of uint256, so if we add '1' in
        // order to differentiate the first index from an empty mapping entry.
        _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] =
            _tokens[tokenId].dependencies.length+1;

        // adds dependency
        _tokens[tokenId].dependencies.push(newDependency);

        emit NewDependence(tokenId, CTContractAddress, CTId);

    }

    /**
     * @dev Removes from tokenId the dependency on CTId from contract CTContractAddress.
     */
    function removeDependence(
        uint256 tokenId,
        address CTContractAddress,
        uint256 CTId
    ) public virtual override {
        // casts CTContractAddress to type ICommanderToken 
        ICommanderToken CTContract = ICommanderToken(CTContractAddress);

        // CTContractAddress can always remove the dependency, but the owner 
        // of tokenId can remove it only if CTId is transferable & burnable
        require(
            ( _isApprovedOrOwner(msg.sender, tokenId) &&
            CTContract.isTransferable(CTId) &&
            CTContract.isBurnable(CTId) ) ||
            ( msg.sender == CTContractAddress ),
            "Commander Token: sender is not permitted to remove dependency"
        );

        // checks that tokenId is indeed dependent on CTId
        require(
            _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId] > 0,
            "Commander Token: tokenId is not dependent on CTid from contract CTContractAddress"
        );

        // gets the index of the token we are about to remove from dependencies
        // we remove '1' because we added '1' when saving the index in setDependence, 
        // see the comment in setDependence for an explanation
        uint256 dependencyIndex = _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId]-1;

        // clears dependenciesIndex for this token
        delete _tokens[tokenId].dependenciesIndex[CTContractAddress][CTId];

        // removes dependency: copy the last element of the array to the place of 
        // what was removed, then remove the last element from the array
        uint256 lastDependecyIndex = _tokens[tokenId].dependencies.length - 1;
        _tokens[tokenId].dependencies[dependencyIndex] = _tokens[tokenId]
            .dependencies[lastDependecyIndex];
        _tokens[tokenId].dependencies.pop();

        emit RemovedDependence(tokenId, CTContractAddress, CTId);
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
     * @dev Sets the transferable property of tokenId.
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
        _tokens[tokenId].nonburnable = !burnable;
    }

    /**
     * @dev Checks the transferable property of tokenId 
     * @dev (only of the token itself, not of its dependencies).
     **/
    function isTransferable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return !_tokens[tokenId].nontransferable;
    }

    /**
     * @dev Checks the burnable property of tokenId 
     * @dev (only of the token itself, not of its dependencies).
     **/
    function isBurnable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return !_tokens[tokenId].nonburnable;
    }

    /**
     * @dev Checks if all the tokens that tokenId depends on are transferable or not 
     * @dev (only of the dependencies, not of the token).
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
     * @dev Checks all the tokens that tokenId depends on are burnable 
     * @dev (only of the dependencies, not of the token).
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
     * @dev Checks if tokenId can be transferred 
     * @dev (meaning, both the token itself and all of its dependncies are transferable).
     **/
    function isTokenTransferable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return isTransferable(tokenId) && isDependentTransferable(tokenId);
    }

    /**
     * @dev Checks if tokenId can be burned.
     * @dev (meaning, both the token itself and all of its dependncies are transferable).
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
    function burn(uint256 tokenId) public virtual override approvedOrOwner(tokenId) {
        require(isTokenBurnable(tokenId), "Commander Token: the token or one of its Commander Tokens are not burnable");

        // 'delete' in solidity doesn't work on mappings, so we delete the mapping items manually
        for (uint i=0; i<_tokens[tokenId].dependencies.length; i++) {
            ExternalToken memory CT =  _tokens[tokenId].dependencies[i];
            delete _tokens[tokenId].dependenciesIndex[address(CT.tokensCollection)][CT.tokenId];
        }

        // delete the rest
        delete _tokens[tokenId];

        // TODO: whitelist is NOT deleted since we don't hold the indices of this mapping
        // TODO: consider fixing this in a later version
    }

    /************************
     * Whitelist functions  *
     ************************/

     /**
      * @dev Adds or removes an address from the whitelist of tokenId.
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
     * @dev Checks if an address is whitelisted.
     **/
    function isAddressWhitelisted(
        uint256 tokenId, 
        address whitelistAddress
    ) public view virtual override returns (bool) {
        return _tokens[tokenId].whitelist[whitelistAddress];
    }

    /**
      * @dev Checks if tokenId can be transferred to addressToTransferTo, without taking its dependence into consideration.
      **/
    function isTransferableToAddress(
        uint256 tokenId, 
        address addressToTransferTo
    ) public view virtual override returns (bool) {
        // either token is transferable (to all addresses, and specifically to 'addressToTransferTo') 
        // or otherwise the address is whitelisted
        return (isTransferable(tokenId) || _tokens[tokenId].whitelist[addressToTransferTo]);
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
    ) public view virtual override(ERC721, IERC165) returns (bool) {
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

        require(
                isTransferableToAddress(tokenId, to),
                "Commander Token: the token status is set to nontransferable"
            );

        require(
                isDependentTransferableToAddress(tokenId, to),
                "Commander Token: the token depends on at least one nontransferable token"
            );
    }
}
