// SPDX-License-Identifier: MIT
// Contract for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./interfaces/ICommanderToken.sol";

/**
 * @dev Implementation of CommanderToken Standard
 */
contract CommanderTokenV3 is ICommanderToken, ERC721Enumerable {
    struct ExternalToken {
        ICommanderToken tokensCollection;
        uint256 tokenId;
    }

    struct Token {
        bool transferable;
        bool burnable;
        ExternalToken[] dependencies; // array of CTs the token depends on
        ExternalToken[] lockedTokens; // array of STs locked to this token
        
        // manages the indices of the dependencies and lockedTokens
        mapping(address => mapping(uint256 => uint256)) dependenciesIndex;
        mapping(address => mapping(uint256 => uint256)) lockingsIndex;

        // a whitelist of addresses the token can be transferred to regardless of its transferable status
        mapping(address => bool)                        whitelist;
        
        // 0 if the token is unlocked, hold the information of the locking token otherwise
        ExternalToken locked;
    }

    // verifies that the sender owns a token
    modifier approvedOrOwner(uint256 tokenId) {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    // verifies that two tokens have the same owner
    modifier sameOwner(
        uint256 CTId,
        address STContractAddress,
        uint256 STId
    ) {
        require(
            ERC721.ownerOf(CTId) == ERC721(STContractAddress).ownerOf(STId),
            "CommanderToken: not sameOwner"
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
        uint256 STId,
        address CTContractAddress,
        uint256 CTId
    )
        public
        virtual
        override
        approvedOrOwner(STId)
        sameOwner(STId, CTContractAddress, CTId)
    {
        // check that STId is not dependent already on CTId
        require(
            _tokens[STId].dependenciesIndex[CTContractAddress][CTId] == 0,
            "Commander Token: STid already depends on CTid from CTContractAddress"
        );

        // CTId must be locked to STId before setting dependence
        (address CTLockedContract, uint256 CTLockedToTokenId) = ICommanderToken(
            CTContractAddress
        ).isLocked(CTId);
        
        require (CTLockedContract == address(this) && 
                CTLockedToTokenId == STId, 
                "Commander Token: CTId must be locked to STId before setting dependence"
        );

        setDependenceUnsafe(STId, CTContractAddress, CTId);
    }

    function setDependenceUnsafe(
        uint256 STId,
        address CTContractAddress,
        uint256 CTId
    )
        public
        virtual
        override
        approvedOrOwner(STId)
        sameOwner(STId, CTContractAddress, CTId)
    {
        // create ExternalToken variable to express the dependency
        ExternalToken memory newDependency; //TODO not sure memory is the location for this variable
        newDependency.tokensCollection = ICommanderToken(CTContractAddress);
        newDependency.tokenId = CTId;

        // save the index of the new dependency
        _tokens[STId].dependenciesIndex[CTContractAddress][CTId] =
            _tokens[STId].dependencies.length +
            1;

        // add dependency
        _tokens[STId].dependencies.push(newDependency);

    }

    /**
     * Removes the dependency of a Commander Token from a Private token.
     */
    function removeDependence(
        uint256 STId,
        address CTContractAddress,
        uint256 CTId
    ) public virtual override approvedOrOwner(STId) {
        // check that STId is indeed dependent on CTId
        require(
            _tokens[STId].dependenciesIndex[CTContractAddress][CTId] > 0,
            "Commander Token: the commander token is not dependent on private token"
        );

        ICommanderToken CTContract = ICommanderToken(CTContractAddress);

        // the CTId needs to be transferable and burnable for the dependency to be remove,
        // otherwise, the owner of CTId could transfer it in any case, simply by removing all dependencies
        if (!CTContract.isTransferable(CTId))
            CTContract.setTransferable(CTId, true);

        if (!CTContract.isBurnable(CTId)) CTContract.setBurnable(CTId, true);

        // remove locking of the dependent token
        removeLockedToken(STId, CTContractAddress, CTId);

        // get the index of the token we are about to remove from dependencies
        uint256 dependencyIndex = _tokens[STId].dependenciesIndex[
            CTContractAddress
        ][CTId];

        // clear dependenciesIndex for this token
        _tokens[STId].dependenciesIndex[CTContractAddress][CTId] = 0;

        // remove dependency: copy the last element of the array to the place of what was removed, then remove the last element from the array
        uint256 lastDependecyIndex = _tokens[STId].dependencies.length - 1;
        _tokens[STId].dependencies[dependencyIndex] = _tokens[STId]
            .dependencies[lastDependecyIndex];
        _tokens[STId].dependencies.pop();
    }

    function isDependent(
        uint256 STId,
        address CTContractAddress,
        uint256 CTId
    ) public view virtual override returns (bool) {
        return
            _tokens[STId].dependenciesIndex[CTContractAddress][CTId] > 0
                ? true
                : false;
    }

    /**
     * Locks a Private Token to a Commander Token. Both tokens must have the same owner.
     *
     * With such a lock in place, the Private Token transfer and burn functions can't be called by
     * its owner as long as the locking is in place.
     *
     * If the Commander Token is transferred or burned, it also transfers or burns the Private Token.
     * If the Private Token is untransferable or unburnable, then a call to the transfer or burn function of the Commander Token unlocks
     * the Private  Tokens.
     *
     */
    function lock(
        uint256 STId,
        address CTContract,
        uint256 CTId
    )
        public
        virtual
        override
        approvedOrOwner(STId)
        sameOwner(STId, CTContract, CTId)
    {
        // check that STId is not dependent already on CTId to prevent loops

        require(
            _tokens[STId].dependenciesIndex[CTContract][CTId] == 0,
            "Commander Token: the specified STId depends on CTId in the CTContract specified."
        );

        // check that STId is unlocked
        (, uint256 lockedCT) = isLocked(STId);
        require(lockedCT == 0, "Commander Token: token is already locked");

        // lock token
        _tokens[STId].locked.tokensCollection = ICommanderToken(CTContract);
        _tokens[STId].locked.tokenId = CTId;

        // nofity CTId in CTContract that STId wants to lock to it
        ICommanderToken(CTContract).addLockedToken(CTId, address(this), STId);
    }

    /**
     * unlocks a Private Token from a Commander Token.
     *
     * This function must be called from the contract of the Commander Token.
     */
    function unlock(
        uint256 STId
    )
        public
        virtual
        override
        onlyContract(address(_tokens[STId].locked.tokensCollection))
    {
        // remove locking
        _tokens[STId].locked.tokensCollection = ICommanderToken(address(0));
        _tokens[STId].locked.tokenId = 0;
    }

    /**
     * @dev returns (0x0, 0) if token is unlocked or the locking token (contract and id) otherwise
     */
    function isLocked(
        uint256 STId
    ) public view virtual override returns (address, uint256) {
        return (
            address(_tokens[STId].locked.tokensCollection),
            _tokens[STId].locked.tokenId
        );
    }

    /**
     * addLockedToken notifies a Commander Token that a Private Token, with the same owner, is locked to it.
     * removeLockedToken removes a token that is locked to the Commander Token .
     */
    function addLockedToken(
        uint256 CTId,
        address STContract,
        uint256 STId
    )
        public
        virtual
        override
        sameOwner(CTId, STContract, STId)
        onlyContract(STContract)
    {
        // check that STId from STContract is not locked already to CTId
        require(
            _tokens[CTId].lockingsIndex[STContract][STId] == 0,
            "Commander Token: the Solider Token is already locked to the Commander Token"
        );

        // create ExternalToken variable to express the locking
        ExternalToken memory newLocking; //TODO not sure memory is the location for this variable
        newLocking.tokensCollection = ICommanderToken(STContract);
        newLocking.tokenId = STId;

        // save the index of the new dependency
        _tokens[CTId].lockingsIndex[STContract][STId] = _tokens[CTId]
            .lockedTokens
            .length;

        // add a locked token
        _tokens[CTId].lockedTokens.push(newLocking);
    }

    function removeLockedToken(
        uint256 CTId,
        address STContract,
        uint256 STId
    ) public virtual override {
        // check that STId from STContract is indeed locked to CTId
        require(
            _tokens[CTId].lockingsIndex[STContract][STId] > 0,
            "Commander Token: STId in contract STContract is not locked to CTId"
        );

        // get the index of the token we are about to remove from locked tokens
        uint256 lockIndex = _tokens[CTId].lockingsIndex[STContract][STId];

        // clear lockingsIndex for this token
        _tokens[CTId].dependenciesIndex[STContract][STId] = 0;

        // remove locking: copy the last element of the array to the place of what was removed, then remove the last element from the array
        uint256 lastLockingsIndex = _tokens[CTId].lockedTokens.length - 1;
        _tokens[CTId].lockedTokens[lockIndex] = _tokens[CTId].lockedTokens[
            lastLockingsIndex
        ];
        _tokens[CTId].lockedTokens.pop();

        // notify STContract that locking was removed
        ICommanderToken(STContract).unlock(STId);

    }

    // TODO add also NFT owner
    function setTransferable(
        uint256 tokenId,
        bool transferable
    ) public virtual override approvedOrOwner(tokenId) {
        _tokens[tokenId].transferable = transferable;
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
        return _tokens[tokenId].transferable;
    }

    function isBurnable(
        uint256 tokenId
    ) public view virtual override returns (bool) {
        return _tokens[tokenId].burnable;
    }

    function isDependentTransferable(
        uint256 CTId
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[CTId].dependencies.length; i++) {
            ICommanderToken STContract = _tokens[CTId]
                .dependencies[i]
                .tokensCollection;
            uint256 STId = _tokens[CTId].dependencies[i].tokenId;
            if (!STContract.isTokenTransferable(STId)) {
                return false;
            }
        }
        return true;
    }

    function isDependentBurnable(
        uint256 CTId
    ) public view virtual override returns (bool) {
        for (uint256 i = 0; i < _tokens[CTId].dependencies.length; i++) {
            ICommanderToken STContract = _tokens[CTId]
                .dependencies[i]
                .tokensCollection;
            uint256 STId = _tokens[CTId].dependencies[i].tokenId;
            if (!STContract.isTokenBurnable(STId)) {
                return false;
            }
        }
        return true;
    }

    function isTokenTransferable(
        uint256 CTId
    ) public view virtual override returns (bool) {
        return isTransferable(CTId) && isDependentTransferable(CTId);
    }

    function isTokenBurnable(
        uint256 CTId
    ) public view virtual override returns (bool) {
        return isBurnable(CTId) && isDependentBurnable(CTId);
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

    /**
     * @dev we reimplement this function in order to add a test for the case that the token is locked.
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(IERC721, ERC721) {
        //solhint-disable-next-line max-line-length

        // TODO: don't we need to unlock tokenId? otherwise it's still locked, and to the wrong token
        (, uint256 lockedCT) = isLocked(tokenId);
        if (lockedCT > 0)
            require(
                msg.sender == address(_tokens[tokenId].locked.tokensCollection),
                "Commander Token: token is locked and caller is not the contract holding the locking token"
            );
        else
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: caller is not token owner or approved"
            );

        _transfer(from, to, tokenId);
    }

    /**
     * @dev we reimplement this function in order to add a test for the case that the token is locked.
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(IERC721, ERC721) {
        (, uint256 lockedCT) = isLocked(tokenId);
        if (lockedCT > 0)
            require(
                msg.sender == address(_tokens[tokenId].locked.tokensCollection),
                "Commander Token: token is locked and caller is not the contract holding the locking token"
            );
        else
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: caller is not token owner or approved"
            );

        _safeTransfer(from, to, tokenId, data);
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
                "Commander Token: the token depends on at least one untransferable token"
            );
            STContract.transferFrom(from, to, STId);
        }

        // transfer each token locked to tokenId, if the token is untransferable, then simply unlock it
        for (uint i; i < _tokens[tokenId].lockedTokens.length; i++) {
            ICommanderToken STContract = _tokens[tokenId]
                .lockedTokens[i]
                .tokensCollection;
            uint256 STId = _tokens[tokenId].lockedTokens[i].tokenId;
            if (!STContract.isTransferable(STId))
                removeLockedToken(tokenId, address(STContract), STId);
            else STContract.transferFrom(from, to, STId);
        }
    }
}
