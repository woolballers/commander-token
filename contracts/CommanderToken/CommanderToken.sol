// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./utils/AddressesOrNFTs.sol";
import "./interfaces/ICommanderToken.sol";

/**
 * @dev Implementation of CommanderToken Standard
 */
contract CommanderToken is ICommanderToken, ERC721, Ownable {
    using Address for address;
    using Strings for uint256;
    using AddressesOrNFTs for AddressesOrNFTs.AddressOrNFT;

    uint256 public constant ADDRESS_NOT_NFT = 0;

    struct Token {
        bool exists;
        mapping(address => mapping(uint256 => bool)) dependencies; //NFT contract & Token Id to dependent/independent
        bool transferable;
        bool burnable;
    }

    //this is done to prevent gas incase there is no change to dependencies or transferable/burnable
    bool public defaultTransferable = true;
    bool public defaultBurnable = true;

    // Mapping from token ID to token data
    mapping(uint256 => Token) private _tokens;

    // Mapping from token ID to owner address
    mapping(uint256 => AddressesOrNFTs.AddressOrNFT) private _owners;

    // Mapping owner address or NFT owner to token count
    mapping(address /* addressOrNFT */ => mapping(uint256 /* nftTokenIdOr0 */ => uint256))
        private _balances;

    // Mapping from token ID to approved address or NFT
    mapping(uint256 => AddressesOrNFTs.AddressOrNFT) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address /* addressOrNFT */ => mapping(uint256 /* nftTokenIdOr0 */ => mapping(address /* addressOrNFT */ => mapping(uint256 /* nftTokenIdOr0 */ => bool))))
        private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, IERC165) returns (bool) {
        return
            interfaceId == type(ICommanderToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(
        address owner
    ) public view virtual override(ERC721, IERC721) returns (uint256) {
        require(
            owner != address(0),
            "ERC721: address zero is not a valid owner"
        );
        return _balances[owner][ADDRESS_NOT_NFT];
    }

    function balanceOf(
        address _NFTContract,
        uint256 _NFTTokenId
    ) external view returns (uint256 balance) {
        require(
            _NFTContract != address(0),
            "ERC721: contract address zero is not a valid owner"
        );

        return _balances[_NFTContract][_NFTTokenId];
    }

    function burn(uint256 tokenId) public virtual override {}

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
        require(tokenExists == true, "CommanderToken: invalid token ID");
        AddressesOrNFTs.AddressOrNFT memory tokenOwner = _ownerOfNft(_tokenId);

        return (tokenOwner.addressOrNftContract, tokenOwner.tokenId);
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        address owner = CommanderToken.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(
        uint256 tokenId
    ) public view virtual override(ERC721, IERC721) returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId].addressOrNftContract;
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override(ERC721, IERC721) {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual override(ERC721, IERC721) returns (bool) {
        return
            _operatorApprovals[owner][ADDRESS_NOT_NFT][operator][
                ADDRESS_NOT_NFT
            ];
    }

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

        AddressesOrNFTs.AddressOrNFT memory tokenOwner = _tokenApprovals[
            tokenId
        ];
        return (tokenOwner.addressOrNftContract, tokenOwner.tokenId);
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
            _operatorApprovals[owner][ADDRESS_NOT_NFT][
                operatorNFTContractAddress
            ][operatorNftTokenId];
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
            _operatorApprovals[ownerNftContractAddress][ownerNftTokenId][
                operator
            ][ADDRESS_NOT_NFT];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );

        _transfer(from, to, tokenId);
    }

    /**
     * From address to NFT
     *
     */
    function transferFromToNft(
        address _fromAddress,
        address _toNFTContractAddress,
        uint256 _toId,
        uint256 _tokenId
    ) public virtual override {
        _transfer(_fromAddress, _toNFTContractAddress, _toId, _tokenId);
    }

    /**
     * From NFT to address
     */
    function transferFromNft(
        address _fromNFTContractAddress,
        uint256 _fromId,
        address _toAddress,
        uint256 _tokenId
    ) public virtual override {
        _transfer(_fromNFTContractAddress, _fromId, _toAddress, _tokenId);
    }

    /**
     * From NFT to NFT
     */
    function transferFromNftToNft(
        address _fromNFTContractAddress,
        uint256 _fromId,
        address _toNFTContractAddress,
        uint256 _toId,
        uint256 _tokenId
    ) public virtual override {
        _transfer(
            _fromNFTContractAddress,
            _fromId,
            _toNFTContractAddress,
            _toId,
            _tokenId
        );
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
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(ERC721, IERC721) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual override {
        _transfer(from, to, tokenId);
        // require(
        //     ERC721._checkOnERC721Received(from, to, tokenId, data),
        //     "ERC721: transfer to non ERC721Receiver implementer"
        // );
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(
        uint256 tokenId
    ) internal view virtual override returns (address) {
        if (!_owners[tokenId].isNFT()) {
            return _owners[tokenId].getAddress();
        } else {
            return address(0);
        }
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(
        uint256 tokenId
    ) public view virtual override(ERC721, IERC721) returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOfNft(
        uint256 tokenId
    ) internal view virtual returns (AddressesOrNFTs.AddressOrNFT memory) {
        if (_owners[tokenId].isNFT()) {
            return _owners[tokenId];
        } else {
            AddressesOrNFTs.AddressOrNFT memory addressOrNFT;
            return addressOrNFT;
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
    function _exists(
        uint256 tokenId
    ) internal view virtual override returns (bool) {
        if (_ownerOf(tokenId) != address(0)) {
            return true;
        } else {
            return _ownerOfNft(tokenId).addressOrNftContract != address(0);
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
        return _ownerOfNft(tokenId).addressOrNftContract != address(0);
    }

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
        address owner = CommanderToken.ownerOf(tokenId);
        return (spender == owner ||
            isApprovedForAll(owner, spender) ||
            getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721) {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual override(ERC721) {
        _mint(to, tokenId);
        // require(
        //     ERC721._checkOnERC721Received(address(0), to, tokenId, data),
        //     "ERC721: transfer to non ERC721Receiver implementer"
        // );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721) {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to][ADDRESS_NOT_NFT] += 1;
        }

        _owners[tokenId] = AddressesOrNFTs.AddressOrNFT(to, ADDRESS_NOT_NFT);

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
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
            _balances[toNftContract][toNftTokenId] += 1;
        }

        _owners[tokenId] = AddressesOrNFTs.AddressOrNFT(
            toNftContract,
            toNftTokenId
        );

        // to do:  fixemit Transfer(address(0), to, tokenId);

        // to do: fix _afterTokenTransfer(address(0), to, tokenId, 1);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        address owner = CommanderToken.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = CommanderToken.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner][ADDRESS_NOT_NFT] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(
            CommanderToken.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(
            CommanderToken.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from][ADDRESS_NOT_NFT] -= 1;
            _balances[to][ADDRESS_NOT_NFT] += 1;
        }
        _owners[tokenId] = AddressesOrNFTs.AddressOrNFT(to, ADDRESS_NOT_NFT);

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address toNftContract,
        uint256 toNftTokenId,
        uint256 tokenId
    ) internal virtual {
        require(
            CommanderToken.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );

        // _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        // require(
        //     ERC721.ownerOf(tokenId) == from,
        //     "ERC721: transfer from incorrect owner"
        // );

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from][ADDRESS_NOT_NFT] -= 1;
            _balances[toNftContract][toNftTokenId] += 1;
        }
        _owners[tokenId] = AddressesOrNFTs.AddressOrNFT(
            toNftContract,
            toNftTokenId
        );

        //emit Transfer(from, to, tokenId);

        //_afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address fromNftContract,
        uint256 fromNftTokenId,
        address to,
        uint256 tokenId
    ) internal virtual {
        (address nftContract, uint256 nftTokenId) = CommanderToken.ownerOfNft(
            tokenId
        );
        require(
            (nftContract == fromNftContract) && (nftTokenId == fromNftTokenId),
            "CommanderToken: transfer from incorrect owner"
        );
        require(
            to != address(0),
            "CommanderToken: transfer to the zero address"
        );

        //_beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        // require(
        //     ERC721.ownerOf(tokenId) == from,
        //     "ERC721: transfer from incorrect owner"
        // );

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[fromNftContract][fromNftTokenId] -= 1;
            _balances[to][ADDRESS_NOT_NFT] += 1;
        }
        _owners[tokenId] = AddressesOrNFTs.AddressOrNFT(to, ADDRESS_NOT_NFT);

        //emit Transfer(from, to, tokenId);

        //_afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address fromNftContract,
        uint256 fromNftTokenId,
        address toNftContract,
        uint256 toNftTokenId,
        uint256 tokenId
    ) internal virtual {
        (address nftContract, uint256 nftTokenId) = CommanderToken.ownerOfNft(
            tokenId
        );
        require(
            (nftContract == fromNftContract) && (nftTokenId == fromNftTokenId),
            "CommanderToken: transfer from incorrect owner"
        );
        //require(to != address(0), "ERC721: transfer to the zero address");

        //_beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        // require(
        //     ERC721.ownerOf(tokenId) == from,
        //     "ERC721: transfer from incorrect owner"
        // );

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[fromNftContract][fromNftTokenId] -= 1;
            _balances[toNftContract][toNftTokenId] += 1;
        }
        _owners[tokenId] = AddressesOrNFTs.AddressOrNFT(
            toNftContract,
            toNftTokenId
        );

        //emit Transfer(from, to, tokenId);

        //_afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual override {
        _tokenApprovals[tokenId] = AddressesOrNFTs.AddressOrNFT(
            to,
            ADDRESS_NOT_NFT
        );
        emit Approval(CommanderToken.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual override {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][ADDRESS_NOT_NFT][operator][
            ADDRESS_NOT_NFT
        ] = approved;
        emit ApprovalForAll(owner, operator, approved);
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
        uint256 /* firstTokenId */,
        uint256 batchSize
    ) internal virtual override {
        if (batchSize > 1) {
            if (from != address(0)) {
                _balances[from][ADDRESS_NOT_NFT] -= batchSize;
            }
            if (to != address(0)) {
                _balances[to][ADDRESS_NOT_NFT] += batchSize;
            }
        }
    }

    function _checkTokenDefaults(uint256 tokenId) internal virtual {
        if (!_tokens[tokenId].exists) {
            _tokens[tokenId].exists = true;
            _tokens[tokenId].burnable = defaultBurnable;
            _tokens[tokenId].transferable = defaultTransferable;
        }
    }

    /**
     * Let transfer and burn be dependent on another token.
     * In this caes you cannot transfer or burn your token unless all the tokens you depend on
     * are transferable or burnable.
     * dependency only works if 'dependentTokenId' from 'dependableContractAddress' is owned by uint256 '_tokenId'.
     * Caller must be the owner, opertaor or approved to use _tokenId.
     */
    function setDependence(
        uint256 tokenId,
        address dependableContractAddress,
        uint256 dependentTokenId,
        bool dependent
    ) public virtual {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _checkTokenDefaults(tokenId);
        _tokens[tokenId].dependencies[dependableContractAddress][
            dependentTokenId
        ] = dependent;
    }

    // EYAL'S ADDITION
    function isDependent(
        uint256 tokenId,
        address dependableContractAddress,
        uint256 dependentTokenId
    ) public view virtual override returns (bool) {
        return
            _tokens[tokenId].dependencies[dependableContractAddress][
                dependentTokenId
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
        _checkTokenDefaults(tokenId);
        _tokens[tokenId].transferable = transferable;
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
        _checkTokenDefaults(tokenId);

        _tokens[tokenId].burnable = burnable;
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
}
