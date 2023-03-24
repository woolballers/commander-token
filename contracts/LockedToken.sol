// SPDX-License-Identifier: MIT
// Contract for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./interfaces/ILockedToken.sol";

/**
 * @dev Implementation of Locked Token Standard
 */
contract LockedToken is ILockedToken, ERC721Enumerable {
    struct ExternalToken {
        ILockedToken tokensCollection;
        uint256 tokenId;
    }

    struct Token {
        ExternalToken[] lockedTokens; // array of STs locked to this token
        
        // manages the indices of lockedTokens
        mapping(address => mapping(uint256 => uint256)) lockingsIndex;

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
        uint256 token1Id,
        address Token2ContractAddress,
        uint256 Token2Id
    ) {
        require(
            ERC721.ownerOf(token1Id) == ERC721(Token2ContractAddress).ownerOf(Token2Id),
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
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    
    /**
     * @dev Locks tokenId CTId from contract CTContract. Both tokens must have the same owner.
     *
     * With such a lock in place, the Private Token transfer and burn functions can't be called by
     * its owner as long as the locking is in place.
     *
     * If the Commander Token is transferred or burned, it also transfers or burns the Private Token.
     * If the Private Token is nontransferable or unburnable, then a call to the transfer or burn function of the Commander Token unlocks
     * the Private  Tokens.
     *
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
        (, uint256 lockedCT) = isLocked(tokenId);
        require(lockedCT == 0, "Commander Token: token is already locked");

        // lock token
        _tokens[tokenId].locked.tokensCollection = ILockedToken(LockingContract);
        _tokens[tokenId].locked.tokenId = LockingId;

        // nofity LockingId in LockingContract that tokenId wants to lock to it
        ILockedToken(LockingContract).addLockedToken(LockingId, address(this), tokenId);

        emit NewLocking(tokenId, LockingContract, LockingId);
    }

    /**
     * unlocks a Private Token from a Commander Token.
     *
     * This function must be called from the contract of the Commander Token.
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
     * addLockedToken notifies a Token that another token (LTId), with the same owner, is locked to it.
     * removeLockedToken removes a token that was locked to the tokenId.
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
            "Commander Token: the Solider Token is already locked to the Commander Token"
        );

        // create ExternalToken variable to express the locking
        ExternalToken memory newLocking;
        newLocking.tokensCollection = ILockedToken(LockedContract);
        newLocking.tokenId = LockedId;

        // save the index of the new dependency
        _tokens[tokenId].lockingsIndex[LockedContract][LockedId] = _tokens[tokenId]
            .lockedTokens
            .length;

        // add a locked token
        _tokens[tokenId].lockedTokens.push(newLocking);
    }

    function removeLockedToken(
        uint256 tokenId,
        address STContract,
        uint256 STId
    ) public virtual override {
        // check that STId from STContract is indeed locked to tokenId
        require(
            _tokens[tokenId].lockingsIndex[STContract][STId] > 0,
            "Commander Token: STId in contract STContract is not locked to tokenId"
        );

        // get the index of the token we are about to remove from locked tokens
        uint256 lockIndex = _tokens[tokenId].lockingsIndex[STContract][STId];

        // clear lockingsIndex for this token
        _tokens[tokenId].lockingsIndex[STContract][STId] = 0;

        // remove locking: copy the last element of the array to the place of what was removed, then remove the last element from the array
        uint256 lastLockingsIndex = _tokens[tokenId].lockedTokens.length - 1;
        _tokens[tokenId].lockedTokens[lockIndex] = _tokens[tokenId].lockedTokens[
            lastLockingsIndex
        ];
        _tokens[tokenId].lockedTokens.pop();

        // notify STContract that locking was removed
        ILockedToken(STContract).unlock(STId);

    }


    function burn(uint256 tokenId) public virtual override {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return
            interfaceId == type(ILockedToken).interfaceId ||
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

        // transfer each token locked to tokenId, if the token is nontransferable, then simply unlock it
        for (uint i; i < _tokens[tokenId].lockedTokens.length; i++) {
            ILockedToken STContract = _tokens[tokenId]
                .lockedTokens[i]
                .tokensCollection;
            uint256 STId = _tokens[tokenId].lockedTokens[i].tokenId;
            STContract.transferFrom(from, to, STId);
        }
    }
}
