// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./interfaces/ILockedToken.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title Locked Token Reference Implementation
 * @author Eyal Ron, Tomer Leicht, Ahmad Afuni
 * @dev Locked Tokens enable the automatic transfer of tokens.
 * @dev If token A is locked to B, then:
 * @dev 1. A cannot be transferred or burned unless B is transferred or burned, and,
 * @dev 2. every transfer of B, also transfers A.
 * @dev Locking is possible if and only if both tokens have the same owner.
 */
contract LockedToken is ILockedToken, ERC721 {
    struct ExternalToken {
        ILockedToken tokensCollection;
        uint256 tokenId;
    }

    struct Token {
        ExternalToken[] lockedTokens; // array of tokens locked to this token
        
        // A mapping to manage the indices of "lockedTokens"
        mapping(address => mapping(uint256 => uint256)) lockingsIndex;

        // 0 if this token is unlocked, or otherwise holds the information of the locking token
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
        uint256 token1Id,
        address Token2ContractAddress,
        uint256 Token2Id
    ) {
        require(
            ERC721.ownerOf(token1Id) == ERC721(Token2ContractAddress).ownerOf(Token2Id),
            "Locked Token: the tokens do not have the same owner"
        );
        _;
    }

    modifier onlyContract(address contractAddress) {
        require(
            contractAddress == msg.sender,
            "Locked Token: transaction is not sent from the correct contract"
        );
        _;
    }

    modifier isApproveOwnerOrLockingContract(uint256 tokenId) {
        (, uint256 lockedCT) = isLocked(tokenId);
        if (lockedCT > 0)
            require(
                msg.sender == address(_tokens[tokenId].locked.tokensCollection),
                "Locked Token: tokenId is locked and caller is not the contract holding the locking token"
            );
        else
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
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
     * @dev Locks tokenId CTId from contract CTContract. Both tokens must have the same owner.
     * @dev 
     * @dev With such a lock in place, tokenId transfer and burn functions can't be called by
     * @dev its owner as long as the locking is in place.
     * @dev 
     * @dev If LckingId is transferred or burned, it also transfers or burns tokenId.
     * @dev If tokenId is nontransferable or unburnable, then a call to the transfer or
     * @dev burn function of the LockingId unlocks the tokenId.
     */
    function lock(
        uint256 tokenId,
        address LockingContract,
        uint256 LockingId
    )
        public
        virtual
        override
        approvedOrOwner(tokenId)
        sameOwner(tokenId, LockingContract, LockingId)
    {
        // check that tokenId is unlocked
        (address LockedContract, uint256 lockedCT) = isLocked(tokenId);
        require(lockedCT == 0, "Locked Token: token is already locked");

        // Check that LockingId is not locked to tokenId, otherwise the locking enters a deadlock.
        // Warning: A deadlock migt still happen if LockingId might is locked to another token 
        // which is locked to tokenId, but we leave this unchecked, so be careful using this.
        (LockedContract, lockedCT) = ILockedToken(LockingContract).isLocked(LockingId);
        require(LockedContract != address(this) || lockedCT != tokenId, 
            "Locked Token: Deadlock deteceted! LockingId is locked to tokenId");

        // lock token
        _tokens[tokenId].locked.tokensCollection = ILockedToken(LockingContract);
        _tokens[tokenId].locked.tokenId = LockingId;

        // nofity LockingId in LockingContract that tokenId is locked to it
        ILockedToken(LockingContract).addLockedToken(LockingId, address(this), tokenId);

        emit NewLocking(tokenId, LockingContract, LockingId);
    }

    /**
     * @dev unlocks a a token.
     * @dev This function must be called from the contract that locked tokenId.
     */
    function unlock(
        uint256 tokenId
    )
        public
        virtual
        override
        onlyContract(address(_tokens[tokenId].locked.tokensCollection))
    {
        // remove locking
        _tokens[tokenId].locked.tokensCollection = ILockedToken(address(0));
        _tokens[tokenId].locked.tokenId = 0;

        emit Unlocked(tokenId);
    }

    /**
     * @dev returns (0x0, 0) if token is unlocked or the locking token (contract and id) otherwise
     */
    function isLocked(
        uint256 tokenId
    ) public view virtual override returns (address, uint256) {
        return (
            address(_tokens[tokenId].locked.tokensCollection),
            _tokens[tokenId].locked.tokenId
        );
    }

    /**
     * @dev addLockedToken notifies a Token that another token (LockedId), with the same owner, is locked to it.
     */
    function addLockedToken(
        uint256 tokenId,
        address LockedContract,
        uint256 LockedId
    )
        public
        virtual
        override
        sameOwner(tokenId, LockedContract, LockedId)
        onlyContract(LockedContract)
    {
        // check that LockedId from LockedContract is not locked already to tokenId
        require(
            _tokens[tokenId].lockingsIndex[LockedContract][LockedId] == 0,
            "Locked Token: tokenId is already locked to LockedId from contract LockedContract"
        );

        // create ExternalToken variable to express the locking
        ExternalToken memory newLocking;
        newLocking.tokensCollection = ILockedToken(LockedContract);
        newLocking.tokenId = LockedId;

        // save the index of the new dependency
        // we need to add '1' to the index since the first index is '0', but '0' is also 
        // the default value of uint256, so if we add '1' in
        // order to differentiate the first index from an empty mapping entry.
        _tokens[tokenId].lockingsIndex[LockedContract][LockedId] = _tokens[tokenId]
            .lockedTokens
            .length+1;

        // add a locked token
        _tokens[tokenId].lockedTokens.push(newLocking);
    }

    /**
     * @dev removeLockedToken removes a token that was locked to the tokenId.
     */
    function removeLockedToken(
        uint256 tokenId,
        address LockedContract,
        uint256 LockedId
    ) public virtual override {
        // check that LockedId from LockedContract is indeed locked to tokenId
        require(
            _tokens[tokenId].lockingsIndex[LockedContract][LockedId] > 0,
            "Locked Token: LockedId in contract LockedContract is not locked to tokenId"
        );

        // get the index of the token we are about to remove from locked tokens
        // we remove '1' because we added '1' when saving the index in addLockedToken, 
        // see the comment in addLockedToken for an explanation
        uint256 lockIndex = _tokens[tokenId].lockingsIndex[LockedContract][LockedId] - 1;

        // clear lockingsIndex for this token
        _tokens[tokenId].lockingsIndex[LockedContract][LockedId] = 0;

        // remove locking: copy the last element of the array to the place of what was removed, then remove the last element from the array
        uint256 lastLockingsIndex = _tokens[tokenId].lockedTokens.length - 1;
        _tokens[tokenId].lockedTokens[lockIndex] = _tokens[tokenId].lockedTokens[
            lastLockingsIndex
        ];
        _tokens[tokenId].lockedTokens.pop();

        // notify LockedContract that locking was removed
        ILockedToken(LockedContract).unlock(LockedId);
    }

    /**
     * @dev Burns the tokenId and all the tokens locked to it.
     * @dev If a locked token is unburnable, it unlocks it.
     **/
    function burn(uint256 tokenId) public virtual override isApproveOwnerOrLockingContract(tokenId) {
        // burn each token locked to tokenId 
        // if the token is unburnable, then simply unlock it
        for (uint i; i < _tokens[tokenId].lockedTokens.length; i++) {
            ILockedToken STContract = _tokens[tokenId]
                .lockedTokens[i]
                .tokensCollection;
            uint256 STId = _tokens[tokenId].lockedTokens[i].tokenId;
            STContract.burn(STId);
        }

        // burn the token
        // 'delete' in solidity doesn't work on mappings, so we delete the mapping items manually
        for (uint i=0; i<_tokens[tokenId].lockedTokens.length; i++) {
            ExternalToken memory CT =  _tokens[tokenId].lockedTokens[i];
            delete _tokens[tokenId].lockingsIndex[address(CT.tokensCollection)][CT.tokenId];
        }

        // delete the rest
        delete _tokens[tokenId];
    }

    /***********************************************
     * Overrided functions from ERC165 and ERC721  *
     ***********************************************/

    /**
     * @dev we reimplement this function to add the isApproveOwnerOrLockingContract modifier
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(IERC721, ERC721) isApproveOwnerOrLockingContract(tokenId) {
        //solhint-disable-next-line max-line-length

        ERC721._transfer(from, to, tokenId);
    }

    /**
     * @dev we reimplement this function to add the isApproveOwnerOrLockingContract modifier
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(IERC721, ERC721) isApproveOwnerOrLockingContract(tokenId) {

        _safeTransfer(from, to, tokenId, data);
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

        // transfer each token locked to tokenId 
        // if the token is nontransferable, then simply unlock it
        for (uint i; i < _tokens[tokenId].lockedTokens.length; i++) {
            ILockedToken STContract = _tokens[tokenId]
                .lockedTokens[i]
                .tokensCollection;
            uint256 STId = _tokens[tokenId].lockedTokens[i].tokenId;
            STContract.transferFrom(from, to, STId);
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, IERC165) returns (bool) {
        return
            interfaceId == type(ILockedToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
