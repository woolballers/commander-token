// SPDX-License-Identifier: MIT
// Interface for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @dev An interface extending ERC721 with the ability to create non-transferable or non-burnable tokens.
 * @dev For this cause we add two new mechniasms enabling a token to depend on or be locked to another token.
 * @dev If Token A depends on B, then if Token B is nontransferable or unburnable, so does Token A.
 * @dev If token A is locked to B, then A cannot be transferred unless B is transferred, and every transfer of B, transfers also A.
 * @dev Locking is possible if and only if both tokens have the same owner.
 * @dev if token B depedns on token A, we again call A a Commander Token (CT), and A Solider Token (ST).
 * @dev If token A is locked to token B, we call B a Commander Token (CT), and a Solider Token (ST).
 */
interface ICommanderToken is IERC721Enumerable {
    /**
     * Sets dependence of one token (called Solider Token or ST) on another token (called Commander Token or CT). 
     * 
     * setDependence requires that the CT is locked to the ST, in order to avoid the risk of the CT 
     * being transferred while the depedency is in place. This also implies that both tokens have the same owner.
     * 
     * setDependenceUnsafe, however, allows creating a dependency without locking in place, which also allows to depend
     * on a token from another owner.
     * 
     * The dependency means that if CT is not transferable or burnable, then so does ST,
     * 
     * Dependency can remove either by the owner of STId (in case CTId is both transferable or burnable), or 
     * by the a transaction from, otherwise.
     */
    function setDependence(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

    function setDependenceUnsafe(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

    function removeDependence(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

    function isDependent(uint256 tokenId, address CTContractAddress, uint256 CTId) external view returns (bool);

    /**
     * Locks a Solider Token (ST) to a Commander Token (CT). Both tokens must have the same owner.
     * 
     * The ST transfer and burn functions can't be called by its owner as long as the locking is in place.
     * 
     * If the CT is transferred or burned, it also transfers or burns the ST.
     * If the ST is untransferable or unburnable, then a call to the transfer or burn function of the CT unlocks the ST.
    */
    function lock(uint256 tokenId, address CTContract, uint256 CTId) external;

    function unlock(uint256 tokenId) external;

    function isLocked(uint256 tokenId) external view returns (address, uint256);

    /**
     * addLockedToken notifies a token that a Solider Token (ST), with the same owner, is locked to it. 
     * removeLockedToken let a Commander Token remove the locking of a Solider Token.
    */ 
    function addLockedToken(uint256 tokenId, address STContract, uint256 STId) external;

    function removeLockedToken(uint256 tokenId, address STContract, uint256 STId) external;
// 
    /**
     * These functions are for managing the effect of dependence of tokens.
     * If a token is untransferable, then all the tokens depending on it are untransferable as well.
     * If a token is unburnable, then all the tokens depending on it are unburnable as well.
     */
    function setTransferable(uint256 tokenId, bool transferable) external;
    function setBurnable(uint256 tokenId, bool burnable) external;

    // Check the transferable and burnable properties of the token itself
    function isTransferable(uint256 tokenId) external view returns (bool);
    function isBurnable(uint256 tokenId) external view returns (bool);

    // check if all the tokens a token depends on are transferable/burnable
    function isDependentTransferable(uint256 tokenId) external view returns (bool);
    function isDependentBurnable(uint256 tokenId) external view returns (bool);

    // check if the token is transferable or burnable, i.e., the token and all of
    // the tokens it depends on are transferable or burnable, correspondingly.
    function isTokenTransferable(uint256 tokenID) external view returns (bool);
    function isTokenBurnable(uint256 tokenID) external view returns (bool);

    /** 
     * A whitelist mechanism.
     */
    function setTransferWhitelist(uint256 tokenId, address whitelistAddress, bool isWhitelisted) external;
    function isTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);
    function isDependentTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);
    function isTokenTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);

    /**
     * Mint and burn are not part of ERC721, since the standard doesn't specify any rules for how they're done (or if they're done at all).
     * However, we add a burn function to ICommanderToken, since its implementation depends on the dependence system.
     */
    function burn(uint256 tokenId) external;
}
