// SPDX-License-Identifier: MIT
// Interface for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @dev An interface extending ERC721 where one token can be locked or dependent on another token.
 * @dev Both cases (dependence, locking) are possible only if the tokens have the same owner.
 * @dev If token A is locked to token B, we call B a Commander Token (CT), and A Private Token (PT).
 * @dev if token B depedns on A, we again call B a Commander Token (CT), and A Private Token (PT).
 * @dev If token A is locked to token B, then A cannot be transferred without B being transferred.
 */
interface ICommanderToken is IERC721Enumerable {
    /**
     * Sets dependence of one token (called Commander Token or CT) on another token (called Private Token or PT). 
     * The Private Token must be locked to the Commander Token, in order to prevent that Private Token will be transfered
     * while the dependency is in place. If such a locking does not exist yet, setDependence creates it.
     * 
     * When Token A depends on Token B it means that each transfer or burn of token A, also transfers or
     * burns token B, and if token B is untransferable or unburnable, then so does token A. 
     * 
     * Both tokens must have the same owner.
     */
    function setDependence(uint256 CTId, address PTContractAddress, uint256 PTId) external;

    function removeDependence(uint256 CTId, address PTContractAddress, uint256 PTId) external;

    function isDependent(uint256 CTId, address PTContractAddress, uint256 PTId) external view returns (bool);

    /**
     * Locks a Private Token to a Commander Token. Both tokens must have the same owner.
     * 
     * The Private Token transfer and burn functions can't be called by its owner as long as the locking is in place.
     * 
     * If the Commander Token is transferred or burned, it also transfers or burns the Private Token.
     * If the Private Token is untransferable or unburnable, then a call to the transfer or burn function of the Commander Token unlocks
     * the Private  Tokens.
     * 
    */
    function lock(uint256 PTId, address CTContract, uint256 CTId) external;

    function unlock(uint256 PTId) external;

    function isLocked(uint256 PTId) external view returns (address, uint256);

    /**
     * addLockedToken notifies a Commander Token that a Private Token, with the same owner, is locked to it. 
     * removeLockedToken let a Commander Token remove the locking of a Private Token.
    */ 
    function addLockedToken(uint256 PTId, address CTContract, uint256 CTId) external;

    function removeLockedToken(uint256 PTId, address CTContract, uint256 CTId) external;

    /**
     * These functions are for managing the effect of dependence of tokens.
     * If a token is untransferable, then all the tokens depending on it are untransferable as well.
     * If a token is unburnable, then all the tokens depending on it are unburnable as well.
     */
    function setTransferable(uint256 tokenId, bool transferable) external;

    function setBurnable(uint256 tokenId, bool burnable) external;

    function isTransferable(uint256 tokenId) external view returns (bool);

    function tokenTranferable(uint256 tokenId) external view returns (bool);

    function isDependentTransferable(uint256 tokenId) external view returns (bool);

    function isBurnable(uint256 tokenId) external view returns (bool);

    /**
     * Mint and burn are not part of ERC721, since the standard doesn't specify any rules for how they're done (or if they're done at all).
     * However, we add a burn function to ICommanderToken, since its implementation depends on the dependence system.
     */
    function burn(uint256 tokenId) external;
}
