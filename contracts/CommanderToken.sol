// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICommanderToken.sol";

contract CommanderToken is ICommanderToken, ERC721, Ownable {
    enum TokenTypes {
        Erc721Type,
        CommanderTokenType,
        None
    }

    bool public defaultTransferable;
    bool public defaultBurnable;

    // EYAL'S ADDITION
    // TODO: by address we mean a contract of type CommanderToken
    struct NftOwner {
        address nftContract;
        uint256 ownerTokenId;
    }

    // EYAL'S ADDITION
    struct Token {
        bool exists;
        mapping(address => mapping(uint256 => bool)) dependencies; //NFT contract & Token Id to dependent/independent
        bool transferable;
        bool burnable;
    }

    // EYAL'S ADDITION
    mapping(uint256 => Token) private _tokens;

    // EYAL'S ADDITION
    // Mapping from token ID to token owner
    mapping(uint256 => NftOwner) private _ownersNft;

    // EYAL'S ADDITION
    // A struct (as NftOwner) can't be the key of mapping, instead we use this mapping
    // This maps NFTContract/ownerTokenId to token count
    mapping(address => mapping(uint256 => uint256)) private _balancesNft;

    // Mapping from token ID to approved address
    mapping(uint256 => NftOwner) private _tokenApprovalsNft;

    // Mapping from owner to operator approvals
    // approval for NFT Owner (contract, tokenId) to operator address for all tokens
    mapping(address => mapping(uint256 => mapping(address => bool)))
        private _operatorApprovalsNftOwner;

    // Mapping from owner to operator approvals
    // approval for address owner to NFT operator (contract, tokenId) for all tokens
    mapping(address => mapping(address => mapping(uint256 => bool)))
        private _operatorNftApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {}

    // EYAL'S ADDITION
    /**
     * @dev See {ICommanderToken}.
     */
    function balanceOf(
        address _NFTContract,
        uint256 _NFTTokenId
    ) external view returns (uint256 balance) {
        require(
            _NFTContract != address(0),
            "ERC721: contract address zero is not a valid owner"
        );
        require(
            _NFTTokenId != 0,
            "ERC721: NFT token ID zero is not a valid owner"
        );
        return _balancesNft[_NFTContract][_NFTTokenId];
    }

    // EYAL'S ADDITION
    /**
     * @dev See {IERC721-balanceOf}.
     */
    function ownerOfNft(
        uint256 _tokenId
    )
        public
        view
        virtual
        override
        returns (address NFTContractAddress, uint256 owner)
    {
        // check that token exists
        bool tokenExists = _existsNft(_tokenId);
        require(tokenExists == false, "CommanderToken: invalid token ID");

        NftOwner memory TokenOwner = _ownerOfNft(_tokenId);
        return (TokenOwner.nftContract, TokenOwner.ownerTokenId);
    }

    function safeTransferFrom(
        address _fromAddress,
        address _toNFTContractAddress,
        uint256 _toTokenId,
        uint256 _tokenId
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "ERC721: caller is not token owner or approved"
        );
        //_safeTransfer(_fromAddress, to, _tokenId, "");
    }

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
    ) public virtual override {}

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
    ) public virtual override {}

    /**
     * From address to NFT
     */
    function transferFrom(
        address _fromAddress,
        address _toNFTContractAddress,
        uint256 _toId,
        uint256 _tokenId
    ) public virtual override {}

    /**
     * From NFT to address
     */
    function transferFrom(
        address _fromNFTContractAddress,
        uint256 _fromId,
        address _toAddress,
        uint256 _tokenId
    ) public virtual override {}

    /**
     * From NFT to NFT
     */
    function transferFrom(
        address _fromNFTContractAddress,
        uint256 _fromId,
        address _toNFTContractAddress,
        uint256 _toId,
        uint256 _tokenId
    ) public virtual override {}

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
    ) external virtual override {}

    function getApprovedNft(
        uint256 tokenId
    )
        public
        view
        virtual
        override
        returns (address _NFTContractAddress, uint256 _tokenId)
    {
        _requireMinted(tokenId);

        NftOwner memory TokenOwner = _tokenApprovalsNft[tokenId];
        return (TokenOwner.nftContract, TokenOwner.ownerTokenId);
    }

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
    ) public virtual override {}

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(
        address owner,
        address operatorNFTContractAddress,
        uint256 operatorNftTokenId
    ) public view virtual override returns (bool) {
        return
            _operatorNftApprovals[owner][operatorNFTContractAddress][
                operatorNftTokenId
            ];
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(
        address ownerNftContractAddress,
        uint256 ownerNftTokenId,
        address operator
    ) public view virtual override returns (bool) {
        return
            _operatorApprovalsNftOwner[ownerNftContractAddress][
                ownerNftTokenId
            ][operator];
    }

    /**
     * Let transfer and burn be dependent on another token.
     * In this caes you cannot transfer or burn your token unless all the tokens you depend on
     * are transferable or burnable.
     * dependency only works if '_dependentTokenId' from '_dependableContractAddress' is owned by uint256 '_tokenId'.
     * Caller must be the owner, opertaor or approved to use _tokenId.
     */
    function setDependence(
        uint256 _tokenId,
        ICommanderToken _dependableContractAddress,
        uint256 _dependentTokenId,
        bool _dependent
    ) public virtual override {}

    // EYAL'S ADDITION
    function isDependent(
        uint256 _tokenId,
        address _dependableContractAddress,
        uint256 _dependentTokenId
    ) public view virtual override returns (bool) {
        return
            _tokens[_tokenId].dependencies[_dependableContractAddress][
                _dependentTokenId
            ];
    }

    // Set default value of `transferable` field of token
    function setDefaultTransferable(bool transferable) external {
        defaultTransferable = transferable;
    }

    // EYAL'S ADDITION
    // TODO add also NFT owner
    function setTransferable(
        uint256 tokenId,
        bool transferable
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _tokens[tokenId].transferable = transferable;
        if (!_tokens[tokenId].exists) {
            _tokens[tokenId].exists = true;
            _tokens[tokenId].burnable = defaultBurnable;
        }
    }

    // Set default value of `burnable` field of token
    function setDefaultBurnable(bool burnable) external {
        defaultBurnable = burnable;
    }

    // EYAL'S ADDITION
    // TODO add also NFT owner
    function setBurnable(
        uint256 tokenId,
        bool burnable
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _tokens[tokenId].burnable = burnable;
        if (!_tokens[tokenId].exists) {
            _tokens[tokenId].exists = true;
            _tokens[tokenId].transferable = defaultTransferable;
        }
    }

    function isTransferable(
        uint256 _tokenId
    ) public view virtual override returns (bool) {
        return
            _tokens[_tokenId].exists
                ? _tokens[_tokenId].transferable
                : defaultTransferable;
    }

    function isBurnable(
        uint256 _tokenId
    ) public view virtual override returns (bool) {
        return
            _tokens[_tokenId].exists
                ? _tokens[_tokenId].burnable
                : defaultBurnable;
    }

    function burn(uint256 tokenId) public virtual override {}

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view virtual override returns (bool) {
        TokenTypes tokenType = _typeOf(tokenId);

        if (tokenType == TokenTypes.Erc721Type) {
            return ERC721._isApprovedOrOwner(spender, tokenId);
        } else if (tokenType == TokenTypes.CommanderTokenType) {
            (address _NFTContractAddress, uint256 _tokenId) = CommanderToken
                .ownerOfNft(tokenId);
            return (spender ==
                CommanderToken(_NFTContractAddress).ownerOf(_tokenId) ||
                isApprovedForAll(_NFTContractAddress, _tokenId, spender) ||
                getApproved(tokenId) == spender);
        }
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    // function _isApprovedOrOwner(
    //     address spender,
    //     uint256 tokenId
    // ) internal view virtual override returns (bool) {
    //     address owner = ERC721.ownerOf(tokenId);
    //     return (spender == owner ||
    //         isApprovedForAll(owner, spender) ||
    //         getApproved(tokenId) == spender);
    // }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOfNft(
        uint256 tokenId
    ) internal view virtual returns (NftOwner memory) {
        return _ownersNft[tokenId];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _existsAll(uint256 tokenId) internal view virtual returns (bool) {
        if (_exists(tokenId) != false) {
            return true;
        } else {
            return _existsNft(tokenId);
        }
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _existsNft(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOfNft(tokenId).nftContract != address(0);
    }

    function _typeOf(
        uint256 tokenId
    ) internal view virtual returns (TokenTypes) {
        address owner = ERC721._ownerOf(tokenId);
        if (owner != address(0)) {
            return TokenTypes.Erc721Type;
        } else {
            NftOwner memory owner2 = _ownerOfNft(tokenId);
            if (owner2.nftContract != address(0)) {
                return TokenTypes.CommanderTokenType;
            }
        }
        return TokenTypes.None;
    }

    function _mint(
        address toNftContract,
        uint256 toNftTokenId,
        uint256 tokenId
    ) internal virtual {
        require(
            toNftContract != address(0),
            "ERC721: mint to the zero address"
        );
        require(!_exists(tokenId), "ERC721: token already minted");

        // to do: fix _beforeTokenTransfer(address(0), toNftContract, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balancesNft[toNftContract][toNftTokenId] += 1;
        }

        _ownersNft[tokenId] = NftOwner(toNftContract, toNftTokenId);

        // to do:  fixemit Transfer(address(0), to, tokenId);

        // to do: fix _afterTokenTransfer(address(0), to, tokenId, 1);
    }
}
