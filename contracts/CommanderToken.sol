// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./interfaces/ICommanderToken.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

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
        uint256 tokenID;
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

    modifier approvedOrOwner(uint256 tokenID) {
        require(
            _isApprovedOrOwner(msg.sender, tokenID),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    // Token ID -> token's data
    mapping(uint256 => Token) internal _tokens;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    /**
     * @dev Adds to tokenID dependency on CTID from contract CTContractAddress.
     * @dev A token can be transfered or burned only if all the tokens it depends on are transferable or burnable, correspondingly.
     * @dev The caller must be the owner, opertaor or approved to use tokenID.
     */
    function setDependence(
        uint256 tokenID,
        address CTContractAddress,
        uint256 CTID
    )
        public
        virtual
        override
        approvedOrOwner(tokenID)
    {
        // checks that tokenID is not dependent already on CTID
        require(
            _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID] == 0,
            "Commander Token: tokenID already depends on CTid from CTContractAddress"
        );

        // creates ExternalToken variable to express the new dependency
        ExternalToken memory newDependency;
        newDependency.tokensCollection = ICommanderToken(CTContractAddress);
        newDependency.tokenID = CTID;

        // saves the index of the new dependency
        // we need to add '1' to the index since the first index is '0', but '0' is also 
        // the default value of uint256, so if we add '1' in
        // order to differentiate the first index from an empty mapping entry.
        _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID] =
            _tokens[tokenID].dependencies.length+1;

        // adds dependency
        _tokens[tokenID].dependencies.push(newDependency);

        emit NewDependence(tokenID, CTContractAddress, CTID);

    }

    /**
     * @dev Removes from tokenID the dependency on CTID from contract CTContractAddress.
     */
    function removeDependence(
        uint256 tokenID,
        address CTContractAddress,
        uint256 CTID
    ) public virtual override {
        // casts CTContractAddress to type ICommanderToken 
        ICommanderToken CTContract = ICommanderToken(CTContractAddress);

        // CTContractAddress can always remove the dependency, but the owner 
        // of tokenID can remove it only if CTID is transferable & burnable
        require(
            ( _isApprovedOrOwner(msg.sender, tokenID) &&
            CTContract.isTransferable(CTID) &&
            CTContract.isBurnable(CTID) ) ||
            ( msg.sender == CTContractAddress ),
            "Commander Token: sender is not permitted to remove dependency"
        );

        // checks that tokenID is indeed dependent on CTID
        require(
            _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID] > 0,
            "Commander Token: tokenID is not dependent on CTid from contract CTContractAddress"
        );

        // gets the index of the token we are about to remove from dependencies
        // we remove '1' because we added '1' when saving the index in setDependence, 
        // see the comment in setDependence for an explanation
        uint256 dependencyIndex = _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID]-1;

        // clears dependenciesIndex for this token
        delete _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID];

        // removes dependency: copy the last element of the array to the place of 
        // what was removed, then remove the last element from the array
        uint256 lastDependecyIndex = _tokens[tokenID].dependencies.length - 1;
        _tokens[tokenID].dependencies[dependencyIndex] = _tokens[tokenID]
            .dependencies[lastDependecyIndex];
        _tokens[tokenID].dependencies.pop();

        emit RemovedDependence(tokenID, CTContractAddress, CTID);
    }

    /**
     * @dev Checks if tokenID depends on CTID from CTContractAddress.
     **/
    function isDependent(
        uint256 tokenID,
        address CTContractAddress,
        uint256 CTID
    ) public view virtual override returns (bool) {
        return
            _tokens[tokenID].dependenciesIndex[CTContractAddress][CTID] > 0
                ? true
                : false;
    }

    /**
     * @dev Sets the transferable property of tokenID.
     **/
    function setTransferable(
        uint256 tokenID,
        bool transferable
    ) public virtual override approvedOrOwner(tokenID) {
        _tokens[tokenID].nontransferable = !transferable;
    }

    /**
     * @dev Sets the burnable status of tokenID.
     **/
    function setBurnable(
        uint256 tokenID,
        bool burnable
    ) public virtual override approvedOrOwner(tokenID) {
        _tokens[tokenID].nonburnable = !burnable;
    }

    /**
     * @dev Checks the transferable property of tokenID 
     * @dev (only of the token itself, not of its dependencies).
     **/
    function isTransferable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        return !_tokens[tokenID].nontransferable;
    }

    /**
     * @dev Checks the burnable property of tokenID 
     * @dev (only of the token itself, not of its dependencies).
     **/
    function isBurnable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        return !_tokens[tokenID].nonburnable;
    }

    /**
     * @dev Checks if all the tokens that tokenID depends on are transferable or not 
     * @dev (only of the dependencies, not of the token).
     **/
    function isDependentTransferable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenID].dependencies.length; i++) {
            ICommanderToken CTContract = _tokens[tokenID]
                .dependencies[i]
                .tokensCollection;
            uint256 CTID = _tokens[tokenID].dependencies[i].tokenID;
            if (!CTContract.isTokenTransferable(CTID)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Checks all the tokens that tokenID depends on are burnable 
     * @dev (only of the dependencies, not of the token).
     **/
    function isDependentBurnable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenID].dependencies.length; i++) {
            ICommanderToken CTContract = _tokens[tokenID]
                .dependencies[i]
                .tokensCollection;
            uint256 CTID = _tokens[tokenID].dependencies[i].tokenID;
            if (!CTContract.isTokenBurnable(CTID)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Checks if tokenID can be transferred 
     * @dev (meaning, both the token itself and all of its dependncies are transferable).
     **/
    function isTokenTransferable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        return isTransferable(tokenID) && isDependentTransferable(tokenID);
    }

    /**
     * @dev Checks if tokenID can be burned.
     * @dev (meaning, both the token itself and all of its dependncies are transferable).
     **/
    function isTokenBurnable(
        uint256 tokenID
    ) public view virtual override returns (bool) {
        return isBurnable(tokenID) && isDependentBurnable(tokenID);
    }

    /**
     * @dev burns tokenID.
     * @dev isTokenBurnable must return 'true'.
     **/
    function burn(uint256 tokenID) public virtual override approvedOrOwner(tokenID) {
        require(isTokenBurnable(tokenID), "Commander Token: the token or one of its Commander Tokens are not burnable");

        // 'delete' in solidity doesn't work on mappings, so we delete the mapping items manually
        for (uint i=0; i<_tokens[tokenID].dependencies.length; i++) {
            ExternalToken memory CT =  _tokens[tokenID].dependencies[i];
            delete _tokens[tokenID].dependenciesIndex[address(CT.tokensCollection)][CT.tokenID];
        }

        // delete the rest
        delete _tokens[tokenID];

        // TODO: whitelist is NOT deleted since we don't hold the indices of this mapping
        // TODO: consider fixing this in a later version
    }

    /************************
     * Whitelist functions  *
     ************************/

     /**
      * @dev Adds or removes an address from the whitelist of tokenID.
      * @dev tokenID can be transferred to whitelisted addresses even when its set to be nontransferable.
      **/
    function setTransferWhitelist(
        uint256 tokenID, 
        address whitelistAddress,
        bool    isWhitelisted
    ) public virtual override approvedOrOwner(tokenID) {
        _tokens[tokenID].whitelist[whitelistAddress] = isWhitelisted;
    }

    /**
     * @dev Checks if an address is whitelisted.
     **/
    function isAddressWhitelisted(
        uint256 tokenID, 
        address whitelistAddress
    ) public view virtual override returns (bool) {
        return _tokens[tokenID].whitelist[whitelistAddress];
    }

    /**
      * @dev Checks if tokenID can be transferred to addressToTransferTo, without taking its dependence into consideration.
      **/
    function isTransferableToAddress(
        uint256 tokenID, 
        address addressToTransferTo
    ) public view virtual override returns (bool) {
        // either token is transferable (to all addresses, and specifically to 'addressToTransferTo') 
        // or otherwise the address is whitelisted
        return (isTransferable(tokenID) || isAddressWhitelisted(tokenID, addressToTransferTo));
    }
    
    /**
      * @dev Checks if all the dependences of tokenID can be transferred to addressToTransferTo,
      **/
    function isDependentTransferableToAddress(
        uint256 tokenID, 
        address transferToAddress
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[tokenID].dependencies.length; i++) {
            ICommanderToken STContract = _tokens[tokenID]
                .dependencies[i]
                .tokensCollection;
            uint256 STID = _tokens[tokenID].dependencies[i].tokenID;

            if (!STContract.isTokenTransferableToAddress(STID, transferToAddress)) {
                return false;
            }
        }

        return true;
    }

    /**
      * @dev Checks if tokenID can be transferred to addressToTransferTo.
      **/
    function isTokenTransferableToAddress(
        uint256 tokenID, 
        address transferToAddress
    ) public view virtual override returns (bool) {
        return isTransferableToAddress(tokenID, transferToAddress) && isDependentTransferableToAddress(tokenID, transferToAddress);
    }

    /***********************************************
     * Overrided functions from ERC165 and ERC721  *
     ***********************************************/
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override(ERC721, IERC165) returns (bool) {
        return
            interfaceID == type(ICommanderToken).interfaceId ||
            super.supportsInterface(interfaceID);
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
        uint256 tokenID,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenID, batchSize);

        require(
                isTransferableToAddress(tokenID, to),
                "Commander Token: the token status is set to nontransferable"
            );

        require(
                isDependentTransferableToAddress(tokenID, to),
                "Commander Token: the token depends on at least one nontransferable token"
            );
    }
}
