// SPDX-License-Identifier: MIT
// Interface for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Locked Token Reference Implementation
 * @author Eyal Ron, Tomer Leicht, Ahmad Afuni
 * @dev Locked Tokens enable the automatic transfer of tokens.
 * @dev If token A is locked to B, then:
 * @dev 1. A cannot be transferred or burned unless B is transferred or burned, and,
 * @dev 2. every transfer of B, also transfers A.
 * @dev Locking is possible if and only if both tokens have the same owner.
 */
interface ILockedToken is IERC721 {
    /**
     * @dev Emitted when tokenID is locked to LockingID from LockingContract.
     */
    event NewLocking(uint256 tokenID, address LockingContract, uint256 LockingID);

    /**
     * @dev Emitted when a locking tokenID to LockingID from LockingContract is removed.
     */
    event Unlocked(uint256 tokenID);

    
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
    function lock(uint256 tokenID, address LockingContract, uint256 LockingID) external;

    /**
     * @dev unlocks a a token.
     * @dev This function must be called from the contract that locked tokenID.
     */
    function unlock(uint256 tokenID) external;

    /**
     * @dev returns (0x0, 0) if token is unlocked or the locking token (contract and id) otherwise
     */
    function isLocked(uint256 tokenID) external view returns (address, uint256);

    /**
     * @dev addLockedToken notifies a Token that another token (LockedID), with the same owner, is locked to it.
     */ 
    function addLockedToken(uint256 tokenID, address LockedContract, uint256 LockedID) external;

    /**
     * @dev removeLockedToken removes a token that was locked to the tokenID.
     */
    function removeLockedToken(uint256 tokenID, address LockedContract, uint256 LockedID) external;

    /**
     * Mint and burn are not part of ERC721, since the standard doesn't specify any 
     * rules for how they're done (or if they're done at all). However, we add a burn function to
     * ILockedToken, since its implementation depends on the locking system.
     */

    /**
     * @dev Burns the tokenID and all the tokens locked to it.
     * @dev If a locked token is unburnable, it unlocks it.
     **/
    function burn(uint256 tokenID) external;
}
