// SPDX-License-Identifier: MIT
// Interface for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev An interface extending ERC721 with the ability to ability to lock one token to another.
 * @dev If token A is locked to B, then:
 * @dev a. A cannot be transferred or burned unless B is transferred or burned, and, 
 * @dev b. every transfer of B, also transfers A.
 * @dev Locking is possible if and only if both tokens have the same owner.
 */
interface ILockedToken is IERC721 {
    /**
     * @dev Emitted when tokenId is locked to LockingId from LockingContract.
     */
    event NewLocking(uint256 tokenId, address LockingContract, uint256 LockingId);

    /**
     * @dev Emitted when a locking tokenId to LockingId from LockingContract is removed.
     */
    event Unlocked(uint256 tokenId);

    
    /**
     * Locks a Locked Token to a Locking Token. Both tokens must have the same owner.
     * 
     * The Locked Token's transfer and burn functions can't be called by its owner as long as the locking is in place.
     * 
     * If the Locking Token is transferred or burned, it also transfers or burns the Locked Token.
     * If the Locked Locked is untransferable or unburnable, then a call to the transfer or burn function of the Locking Token simply unlocks the Locked Token.
    */
    function lock(uint256 tokenId, address LockingContract, uint256 LockingId) external;

    function unlock(uint256 tokenId) external;

    function isLocked(uint256 tokenId) external view returns (address, uint256);

    /**
     * addLockedToken:    notifies a Locking Token that a Locked Token, with the same owner is locked to it. 
     * removeLockedToken: let a Locking Token removes the locking of a Locked Token. Can also be used 
     *                    by a Locked Token to notify the Locking token that the locking was removed.
    */ 
    function addLockedToken(uint256 tokenId, address LockedContract, uint256 LockedId) external;

    function removeLockedToken(uint256 tokenId, address LockedContract, uint256 LockedId) external;

    function burn(uint256 tokenId) external;
}
