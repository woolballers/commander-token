// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

library AddressesOrNFTs {
    using Address for address;
    struct AddressOrNFT {
        address addressOrNftContract;
        uint256 tokenId;
    }

    function isNFT(
        AddressOrNFT storage addressOrNFT
    ) public view returns (bool) {
        return
            addressOrNFT.addressOrNftContract.isContract() &&
            addressOrNFT.tokenId != 0;
    }

    function getAddress(
        AddressOrNFT storage addressOrNFT
    ) public view returns (address) {
        return
            isNFT(addressOrNFT)
                ? address(0)
                : address(addressOrNFT.addressOrNftContract);
    }

    function toString(
        AddressOrNFT storage addressOrNFT
    ) public view returns (string memory) {
        if (isNFT(addressOrNFT)) {
            return
                string(
                    abi.encodePacked(
                        Strings.toHexString(
                            uint160(addressOrNFT.addressOrNftContract)
                        ),
                        ":",
                        Strings.toHexString(addressOrNFT.tokenId)
                    )
                );
        } else {
            return
                Strings.toHexString(uint160(addressOrNFT.addressOrNftContract));
        }
    }
}
