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
        uint256 tokenID;
    }

    struct Token {
        ExternalToken[] lockedTokens; // array of tokens locked to this token
        
        // A mapping to manage the indices of "lockedTokens"
        mapping(address => mapping(uint256 => uint256)) lockingsIndex;

        // 0 if this token is unlocked, or otherwise holds the information of the locking token
        ExternalToken locked;
    }

    // verifies that the sender owns a token
    modifier approvedOrOwner(uint256 tokenID) {
        require(
            _isApprovedOrOwner(msg.sender, tokenID),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    // verifies that two tokens have the same owner
    modifier sameOwner(
        uint256 token1ID,
        address Token2ContractAddress,
        uint256 Token2ID
    ) {
        require(
            ERC721.ownerOf(token1ID) == ERC721(Token2ContractAddress).ownerOf(Token2ID),
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

    modifier isApproveOwnerOrLockingContract(uint256 tokenID) {
        (, uint256 lockedCT) = isLocked(tokenID);
        if (lockedCT > 0)
            require(
                msg.sender == address(_tokens[tokenID].locked.tokensCollection),
                "Locked Token: tokenID is locked and caller is not the contract holding the locking token"
            );
        else
            require(
                _isApprovedOrOwner(_msgSender(), tokenID),
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
     * @dev Locks tokenID CTID from contract CTContract. Both tokens must have the same owner.
     * @dev 
     * @dev With such a lock in place, tokenID transfer and burn functions can't be called by
     * @dev its owner as long as the locking is in place.
     * @dev 
     * @dev If LockingID is transferred or burned, it also transfers or burns tokenID.
     * @dev If tokenID is nontransferable or unburnable, then a call to the transfer or
     * @dev burn function of the LockingID unlocks the tokenID.
     */
    function lock(
        uint256 tokenID,
        address LockingContract,
        uint256 LockingID
    )
        public
        virtual
        override
        approvedOrOwner(tokenID)
        sameOwner(tokenID, LockingContract, LockingID)
    {
        // check that tokenID is unlocked
        (address LockedContract, uint256 lockedCT) = isLocked(tokenID);
        require(lockedCT == 0, "Locked Token: token is already locked");

        // Check that LockingID is not locked to tokenID, otherwise the locking enters a deadlock.
        // Warning: A deadlock migt still happen if LockingID might is locked to another token 
        // which is locked to tokenID, but we leave this unchecked, so be careful using this.
        (LockedContract, lockedCT) = ILockedToken(LockingContract).isLocked(LockingID);
        require(LockedContract != address(this) || lockedCT != tokenID, 
            "Locked Token: Deadlock deteceted! LockingID is locked to tokenID");

        // lock token
        _tokens[tokenID].locked.tokensCollection = ILockedToken(LockingContract);
        _tokens[tokenID].locked.tokenID = LockingID;

        // nofity LockingID in LockingContract that tokenID is locked to it
        ILockedToken(LockingContract).addLockedToken(LockingID, address(this), tokenID);

        emit NewLocking(tokenID, LockingContract, LockingID);
    }

    /**
     * @dev unlocks a a token.
     * @dev This function must be called from the contract that locked tokenID.
     */
    function unlock(
        uint256 tokenID
    )
        public
        virtual
        override
        onlyContract(address(_tokens[tokenID].locked.tokensCollection))
    {
        // remove locking
        _tokens[tokenID].locked.tokensCollection = ILockedToken(address(0));
        _tokens[tokenID].locked.tokenID = 0;

        emit Unlocked(tokenID);
    }

    /**
     * @dev returns (0x0, 0) if token is unlocked or the locking token (contract and id) otherwise
     */
    function isLocked(
        uint256 tokenID
    ) public view virtual override returns (address, uint256) {
        return (
            address(_tokens[tokenID].locked.tokensCollection),
            _tokens[tokenID].locked.tokenID
        );
    }

    /**
     * @dev addLockedToken notifies a Token that another token (LockedID), with the same owner, is locked to it.
     */
    function addLockedToken(
        uint256 tokenID,
        address LockedContract,
        uint256 LockedID
    )
        public
        virtual
        override
        sameOwner(tokenID, LockedContract, LockedID)
        onlyContract(LockedContract)
    {
        // check that LockedID from LockedContract is not locked already to tokenID
        require(
            _tokens[tokenID].lockingsIndex[LockedContract][LockedID] == 0,
            "Locked Token: tokenID is already locked to LockedID from contract LockedContract"
        );

        // create ExternalToken variable to express the locking
        ExternalToken memory newLocking;
        newLocking.tokensCollection = ILockedToken(LockedContract);
        newLocking.tokenID = LockedID;

        // save the index of the new dependency
        // we need to add '1' to the index since the first index is '0', but '0' is also 
        // the default value of uint256, so if we add '1' in
        // order to differentiate the first index from an empty mapping entry.
        _tokens[tokenID].lockingsIndex[LockedContract][LockedID] = _tokens[tokenID]
            .lockedTokens
            .length+1;

        // add a locked token
        _tokens[tokenID].lockedTokens.push(newLocking);
    }

    /**
     * @dev removeLockedToken removes a token that was locked to the tokenID.
     */
    function removeLockedToken(
        uint256 tokenID,
        address LockedContract,
        uint256 LockedID
    ) public virtual override {
        // check that LockedID from LockedContract is indeed locked to tokenID
        require(
            _tokens[tokenID].lockingsIndex[LockedContract][LockedID] > 0,
            "Locked Token: LockedID in contract LockedContract is not locked to tokenID"
        );

        // get the index of the token we are about to remove from locked tokens
        // we remove '1' because we added '1' when saving the index in addLockedToken, 
        // see the comment in addLockedToken for an explanation
        uint256 lockIndex = _tokens[tokenID].lockingsIndex[LockedContract][LockedID] - 1;

        // clear lockingsIndex for this token
        _tokens[tokenID].lockingsIndex[LockedContract][LockedID] = 0;

        // remove locking: copy the last element of the array to the place of what was removed, then remove the last element from the array
        uint256 lastLockingsIndex = _tokens[tokenID].lockedTokens.length - 1;
        _tokens[tokenID].lockedTokens[lockIndex] = _tokens[tokenID].lockedTokens[
            lastLockingsIndex
        ];
        _tokens[tokenID].lockedTokens.pop();

        // notify LockedContract that locking was removed
        ILockedToken(LockedContract).unlock(LockedID);
    }

    /**
     * @dev Burns the tokenID and all the tokens locked to it.
     * @dev If a locked token is unburnable, it unlocks it.
     **/
    function burn(uint256 tokenID) public virtual override isApproveOwnerOrLockingContract(tokenID) {
        // burn each token locked to tokenID 
        // if the token is unburnable, then simply unlock it
        for (uint i; i < _tokens[tokenID].lockedTokens.length; i++) {
            ILockedToken STContract = _tokens[tokenID]
                .lockedTokens[i]
                .tokensCollection;
            uint256 STID = _tokens[tokenID].lockedTokens[i].tokenID;
            STContract.burn(STID);
        }

        // burn the token
        // 'delete' in solidity doesn't work on mappings, so we delete the mapping items manually
        for (uint i=0; i<_tokens[tokenID].lockedTokens.length; i++) {
            ExternalToken memory CT =  _tokens[tokenID].lockedTokens[i];
            delete _tokens[tokenID].lockingsIndex[address(CT.tokensCollection)][CT.tokenID];
        }

        // delete the rest
        delete _tokens[tokenID];
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
        uint256 tokenID
    ) public virtual override(IERC721, ERC721) isApproveOwnerOrLockingContract(tokenID) {
        //solhint-disable-next-line max-line-length

        ERC721._transfer(from, to, tokenID);
    }

    /**
     * @dev we reimplement this function to add the isApproveOwnerOrLockingContract modifier
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenID,
        bytes memory data
    ) public virtual override(IERC721, ERC721) isApproveOwnerOrLockingContract(tokenID) {

        _safeTransfer(from, to, tokenID, data);
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

        // transfer each token locked to tokenID 
        // if the token is nontransferable, then simply unlock it
        for (uint i; i < _tokens[tokenID].lockedTokens.length; i++) {
            ILockedToken STContract = _tokens[tokenID]
                .lockedTokens[i]
                .tokensCollection;
            uint256 STID = _tokens[tokenID].lockedTokens[i].tokenID;
            STContract.transferFrom(from, to, STID);
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override(ERC721, IERC165) returns (bool) {
        return
            interfaceID == type(ILockedToken).interfaceID ||
            super.supportsInterface(interfaceID);
    }
}
