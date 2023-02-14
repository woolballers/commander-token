// SPDX-License-Identifier: MIT
// Contract for an NFT that can be belonged to another NFT

pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev An interface extending ERC721 to allow owner to be another NFT, from any collection
 */
interface ICommanderToken is IERC721 {
    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(
        address _NFTContract,
        uint256 _ownerId
    ) external view returns (uint256 balance);

    /**
     * @dev Returns the NFT owner of the `tokenId` token.
     * @dev If the token is not owned by another  NFT, it returns (0x, 0).
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOfNft(
        uint256 _tokenId
    ) external view returns (address NFTContractAddress, uint256 owner);

    /**
     * @dev Safely transfers `tokenId` to the posession of an NFT token
     *
     * Requirements:
     *
     * - `fromAddress` cannot be the zero address.
     * - `toNFTContractAddress` MUST be an address of an ITokenOwnableTokens contract.
     * - `toTokenId` MUST be an ID of a minted token in toNFTContractAddress (i.e., owner is not 0x0).
     * - `tokenId` token must exists in this contract.
     *
     */
    function safeTransferFrom(
        address fromAddress,
        address toNFTContractAddress,
        uint256 toTokenId,
        uint256 tokenId
    ) external;

    /**
     * @dev Safely transfers `tokenId` to the posession of an NFT token
     *
     * Requirements:
     *
     *
     */
    function safeTransferFrom(
        address _fromNFTContractAddress,
        uint256 _fromTokenId,
        address _toAddress,
        uint256 _tokenId
    ) external;

    /**
     * @dev Safely transfers `tokenId` to the posession of an NFT token
     *
     * Requirements:
     *
     *
     */
    function safeTransferFrom(
        address _fromNFTContractAddress,
        uint256 _fromTokenId,
        address _toNFTContractAddress,
        uint256 _toTokenId,
        uint256 _tokenId
    ) external;

    /**
     * From address to NFT
     */
    function transferFromToNft(
        address _fromAddress,
        address _toNFTContractAddress,
        uint256 _toId,
        uint256 _tokenId
    ) external;

    /**
     * From NFT to address
     */
    function transferFromNft(
        address _fromNFTContractAddress,
        uint256 _fromId,
        address _toAddress,
        uint256 _tokenId
    ) external;

    /**
     * From NFT to NFT
     */
    function transferFromNftToNft(
        address _fromNFTContractAddress,
        uint256 _fromId,
        address _toNFTContractAddress,
        uint256 _toId,
        uint256 _tokenId
    ) external;

    /**
     * @dev Gives permission to an owner of an NFT token to transfer, set dependence or burn `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     * Approving an NFT account clears an approved address if there was any.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `_tokenId` must exist in this contract, and '_approvedId' must exist in _toNFTContractAddress,
     *
     * Emits an {Approval} event.
     */
    function approve(
        address _toNFTContractAddress,
        uint256 _approvedId,
        uint256 _tokenId
    ) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApprovedNft(
        uint256 tokenId
    ) external view returns (address _NFTContractAddress, uint256 _tokenId);

    /**
     * @dev Approve or remove NFT `operator` as an operator for the caller.
     * Operators can call {transferFrom}, {safeTransferFrom}, {setDependence} or {burn} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(
        address _operatorNFTContractAddress,
        uint256 _operatorId,
        bool _approved
    ) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(
        address owner,
        address _operatorNFTContractAddress,
        uint256 _operatorId
    ) external view returns (bool);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(
        address ownerNftContractAddress,
        uint256 ownerNftTokenId,
        address operator
    ) external view returns (bool);

    /**
     * Let transfer and burn be dependent on another token.
     * In this caes you cannot transfer or burn your token unless all the tokens you depend on
     * are transferable or burnable.
     * dependency only works if '_dependentTokenId' from '_dependableContractAddress' is owned by uint256 '_tokenId'.
     * Caller must be the owner, opertaor or approved to use _tokenId.
     */
    function setDependence(
        uint256 _tokenId,
        address _dependableContractAddress,
        uint256 _dependentTokenId,
        bool _dependent
    ) external;

    function isDependent(
        uint256 _tokenId,
        address _dependableContractAddress,
        uint256 _dependentTokenId
    ) external view returns (bool);

    /**
     * These functions are for managing dependence of one token on another.
     */

    function setBurnable(uint256 _tokenId, bool _burnable) external;

    function setTransferable(uint256 _tokenId, bool _transferable) external;

    function isTransferable(uint256 _tokenId) external view returns (bool);

    function tokenTranferable(uint256 _tokenId) external view returns (bool);

    function isDependentTransferable(
        uint256 _tokenId
    ) external view returns (bool);

    function isBurnable(uint256 _tokenId) external view returns (bool);

    function burn(uint256 tokenId) external;
}
