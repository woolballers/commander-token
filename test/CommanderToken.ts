import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";


const TokenName = "CommanderTokenTest";
const TokenSymbol = "CTT";

/*
  const TestNftOwner = {
    nftContract: "0x0000000000000000000000000000000000000000",
    ownerTokenId: 0
}
*/

// etherjs overloading bug - https://github.com/NomicFoundation/hardhat/issues/2203


// Start test block
describe('CommanderToken', function () {
    before(async function () {
        this.CommanderTokenMintTestFactory = await ethers.getContractFactory('CommanderTokenMintTest');
    });

    beforeEach(async function () {
        // deploy the contract
        this.CommanderToken = await this.CommanderTokenMintTestFactory.deploy(TokenName, TokenSymbol);
        await this.CommanderToken.deployed();

        // Get the contractOwner and collector addresses as well as owner account
        const signers = await ethers.getSigners();
        this.contractOwner = signers[0].address;
        this.collector = signers[1].address;
        this.owner = signers[0];


        // Get the collector contract for signing transaction with collector key
        this.collectorContract = this.CommanderToken.connect(signers[1]);

        // Mint an initial set of NFTs from this collection
        this.initialMintCount = 3;
        this.initialMint = [];
        for (let i = 1; i <= this.initialMintCount; i++) { // tokenId to start at 1
            await this.collectorContract["mint(address,uint256)"](this.contractOwner, i);
            this.initialMint.push(i.toString());
        }

        // Randomly set defaultTransferable
        this.defaultTransferable = Math.random() < 0.5 ? false : true;
        this.collectorContract["setDefaultTransferable(bool)"](this.defaultTransferable);

        // Randomly set defaultBurnable
        this.defaultBurnable = Math.random() < 0.5 ? false : true;
        this.collectorContract["setDefaultBurnable(bool)"](this.defaultBurnable);
    });

    // Test cases
    it('Creates a Commander Token with a name', async function () {
        expect(await this.CommanderToken.name()).to.exist;
        expect(await this.CommanderToken.name()).to.equal(TokenName);
    });

    it('Creates a Commander Token with a symbol', async function () {
        expect(await this.CommanderToken.symbol()).to.exist;
        expect(await this.CommanderToken.symbol()).to.equal(TokenSymbol);
    });

    it('Mints initial set of NFTs from collection to contractOwner', async function () {
        for (let i = 0; i < this.initialMint.length; i++) {
            expect(await this.CommanderToken.ownerOf(this.initialMint[i])).to.equal(this.contractOwner);
        }
    });

    it('Is able to query the NFT balances of an address', async function () {
        expect(await this.CommanderToken["balanceOf(address)"](this.contractOwner)).to.equal(this.initialMint.length);
    });

    it('Is able to mint new NFTs to the collection to collector', async function () {
        let tokenId = (this.initialMint.length + 1).toString();
        await this.CommanderToken["mint(address,uint256)"](this.collector, tokenId);
        expect(await this.CommanderToken.ownerOf(tokenId)).to.equal(this.collector);
    });

    it('Is able to make NFTs transferable and check for transferability', async function () {
        let n = Math.floor(Math.random() * this.initialMint.length) + 1;

        // Change default transferability of one of the NFTs
        await this.CommanderToken.connect(this.owner).setTransferable(n, !this.defaultTransferable);

        // Check for transferability
        for (let i = 1; i <= this.initialMint.length; i++) {
            expect(await this.CommanderToken.isTransferable(i)).to.equal(i == n ? !this.defaultTransferable : this.defaultTransferable);
        }
    });

    it('Is able to make NFTs burnable and check for burnability', async function () {
        let n = Math.floor(Math.random() * this.initialMint.length) + 1;

        // Change default burnability of one of the NFTs
        await this.CommanderToken.connect(this.owner).setBurnable(n, !this.defaultBurnable);

        // Check for burnability
        for (let i = 1; i <= this.initialMint.length; i++) {
            expect(await this.CommanderToken.isBurnable(i)).to.equal(i == n ? !this.defaultBurnable : this.defaultBurnable);
        }
    });

    // it('Emits a transfer event for newly minted NFTs', async function () {
    //     let tokenId = (this.initialMint.length + 1).toString();
    //     await expect(this.CommanderToken.mintCollectionNFT(this.contractOwner, tokenId))
    //         .to.emit(this.CommanderToken, "Transfer")
    //         .withArgs("0x0000000000000000000000000000000000000000", this.contractOwner, tokenId); //NFTs are minted from zero address
    // });

    // it('Is able to transfer NFTs to another wallet when called by owner', async function () {
    //     let tokenId = this.initialMint[0].toString();
    //     await this.CommanderToken["safeTransferFrom(address,address,uint256)"](this.contractOwner, this.collector, tokenId);
    //     expect(await this.CommanderToken.ownerOf(tokenId)).to.equal(this.collector);
    // });

    // it('Emits a Transfer event when transferring a NFT', async function () {
    //     let tokenId = this.initialMint[0].toString();
    //     await expect(this.CommanderToken["safeTransferFrom(address,address,uint256)"](this.contractOwner, this.collector, tokenId))
    //         .to.emit(this.CommanderToken, "Transfer")
    //         .withArgs(this.contractOwner, this.collector, tokenId);
    // });

    // it('Approves an operator wallet to spend owner NFT', async function () {
    //     let tokenId = this.initialMint[0].toString();
    //     await this.CommanderToken.approve(this.collector, tokenId);
    //     expect(await this.CommanderToken.getApproved(tokenId)).to.equal(this.collector);
    // });

    // it('Emits an Approval event when an operator is approved to spend a NFT', async function () {
    //     let tokenId = this.initialMint[0].toString();
    //     await expect(this.CommanderToken.approve(this.collector, tokenId))
    //         .to.emit(this.CommanderToken, "Approval")
    //         .withArgs(this.contractOwner, this.collector, tokenId);
    // });

    // it('Allows operator to transfer NFT on behalf of owner', async function () {
    //     let tokenId = this.initialMint[0].toString();
    //     await this.CommanderToken.approve(this.collector, tokenId);
    //     // Using the collector contract which has the collector's key
    //     await this.collectorContract["safeTransferFrom(address,address,uint256)"](this.contractOwner, this.collector, tokenId);
    //     expect(await this.CommanderToken.ownerOf(tokenId)).to.equal(this.collector);
    // });

    // it('Approves an operator to spend all of an owner\'s NFTs', async function () {
    //     await this.CommanderToken.setApprovalForAll(this.collector, true);
    //     expect(await this.CommanderToken.isApprovedForAll(this.contractOwner, this.collector)).to.equal(true);
    // });

    // it('Emits an ApprovalForAll event when an operator is approved to spend all NFTs', async function () {
    //     let isApproved = true
    //     await expect(this.CommanderToken.setApprovalForAll(this.collector, isApproved))
    //         .to.emit(this.CommanderToken, "ApprovalForAll")
    //         .withArgs(this.contractOwner, this.collector, isApproved);
    // });

    // it('Removes an operator from spending all of owner\'s NFTs', async function () {
    //     // Approve all NFTs first
    //     await this.CommanderToken.setApprovalForAll(this.collector, true);
    //     // Remove approval privileges
    //     await this.CommanderToken.setApprovalForAll(this.collector, false);
    //     expect(await this.CommanderToken.isApprovedForAll(this.contractOwner, this.collector)).to.equal(false);
    // });

    // it('Allows operator to transfer all NFTs on behalf of owner', async function () {
    //     await this.CommanderToken.setApprovalForAll(this.collector, true);
    //     for (let i = 0; i < this.initialMint.length; i++) {
    //         await this.collectorContract["safeTransferFrom(address,address,uint256)"](this.contractOwner, this.collector, this.initialMint[i]);
    //     }
    //     expect(await this.CommanderToken.balanceOf(this.collector)).to.equal(this.initialMint.length.toString());
    // });

    // it('Only allows contractOwner to mint NFTs', async function () {
    //     await expect(this.collectorContract.mintCollectionNFT(this.collector, "100")).to.be.reverted;
    // });

});
