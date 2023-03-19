// SPDX-License-Identifier: MIT
// Interface for an NFT that command another NFT or be commanded by another NFT

pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev An interface extending ERC721 with the ability to create non-transferable or non-burnable tokens.
 * @dev For this cause we add a new mechniasm enabling a token to depend on another token.
 * @dev If Token A depends on B, then if Token B is nontransferable or unburnable, so does Token A.
 * @dev if token B depedns on token A, we again call A a Commander Token (CT).
 */
interface ICommanderToken is IERC721 {
    /**
     * Sets dependence of tokenId on another token, called Commander Token or CT. 
     * CT may be a token belonging to another ICommanderToken contract.
     * 
     * The dependency means that if CT is not transferable or burnable, then so does tokenId.
     * 
     * Dependency can remove either by the owner of tokenId, in case CTId is 
     * both transferable or burnable), or by the contract CTContractAddress.
     */
    function setDependence(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

    function removeDependence(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

    function isDependent(uint256 tokenId, address CTContractAddress, uint256 CTId) external view returns (bool);

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
     * A whitelist mechanism. If an address is whitelisted it means the token can be transferred
     * to it, regardless of the value of 'isTokenTransferable'.
     */
    function setTransferWhitelist(uint256 tokenId, address whitelistAddress, bool isWhitelisted) external;
    function isTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);
    function isDependentTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);
    function isTokenTransferableToAddress(uint256 tokenId, address transferToAddress) external view returns (bool);

    /**
     * Mint and burn are not part of ERC721, since the standard doesn't specify any 
     * rules for how they're done (or if they're done at all). However, we add a burn function to
     * ICommanderToken, since its implementation depends on the dependence system.
     */
    function burn(uint256 tokenId) external;
}
