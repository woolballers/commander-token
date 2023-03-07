import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { TOKEN_NAME, TOKEN_SYMBOL, INITIAL_MINT_COUNT } from "../constants/test";

import {
    CommanderTokenV3
} from "../typechain-types";


/*
  const TestNftOwner = {
    nftContract: "0x0000000000000000000000000000000000000000",
    ownerTokenId: 0
}
*/

// etherjs overloading bug - https://github.com/NomicFoundation/hardhat/issues/2203


const mintTokensFixture = async function (testObj: Mocha.Context) {
    testObj.initialMintCount = INITIAL_MINT_COUNT;
    testObj.initialMint = [];
    for (let i = 1; i <= testObj.initialMintCount; i++) { // tokenId to start at 1
        // is called like that because of etherjs overloading bug - https://github.com/NomicFoundation/hardhat/issues/2203
        await testObj.collectorContract["mint(address,uint256)"](testObj.contractOwner, i);
        testObj.initialMint.push(i.toString());
    }
}

const comanderTokenSetBurnableDefaultFixture = async function (testObj: Mocha.Context) {
    // Randomly set defaultBurnable
    testObj.defaultBurnable = Math.random() < 0.5 ? false : true;
    testObj.collectorContract["setDefaultBurnable(bool)"](testObj.defaultBurnable);
}

const comanderTokenSetTransferableDefaultFixture = async function (testObj: Mocha.Context) {
    // Randomly set defaultTransferable
    testObj.defaultTransferable = Math.random() < 0.5 ? false : true;
    testObj.collectorContract["setDefaultTransferable(bool)"](testObj.defaultTransferable);
}

const getRandomMintedTokenId = function (initiallyMinted: string[]): number {
    let n = Math.floor(Math.random() * initiallyMinted.length) + 1;
    return n;
}

const getRandomMintedTokens = function (initiallyMinted: string[]): string[] {
    let shuffled = initiallyMinted
        .map(value => ({ value, sort: Math.random() }))
        .sort((a, b) => a.sort - b.sort)
        .map(({ value }) => value)

    return shuffled;
}


// Start test block
describe('CommanderToken', function () {
    before(async function () {



        this.CommanderTokenMintTestFactory = await ethers.getContractFactory('MintTest');
    });

    beforeEach(async function () {
        // deploy the contract
        this.CommanderToken = await this.CommanderTokenMintTestFactory.deploy(TOKEN_NAME, TOKEN_SYMBOL);
        await this.CommanderToken.deployed();

        // Get the contractOwner and collector addresses as well as owner account
        const signers = await ethers.getSigners();
        this.contractOwner = signers[0].address;
        this.collector = signers[1].address;
        this.owner = signers[0];
        this.wallet2 = signers[2];


        // Get the collector contract for signing transaction with collector key
        this.collectorContract = this.CommanderToken.connect(signers[1]);

        await mintTokensFixture(this);


        this.defaultBurnable = false;
        this.defaultTransferable = false;



    });

    // Test cases
    it('Creates a Commander Token with a name', async function () {
        expect(await this.CommanderToken.name()).to.exist;
        expect(await this.CommanderToken.name()).to.equal(TOKEN_NAME);
    });

    it('Creates a Commander Token with a symbol', async function () {
        expect(await this.CommanderToken.symbol()).to.exist;
        expect(await this.CommanderToken.symbol()).to.equal(TOKEN_SYMBOL);
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

    describe('Transferable & Burnable', function () {

        it('Is able to make NFTs transferable and check for transferability', async function () {
            const tokenIdToChange = getRandomMintedTokenId(this.initialMint);

            // Change default transferability of one of the NFTs
            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToChange, !this.defaultTransferable);

            expect(await this.CommanderToken.isTransferable(tokenIdToChange)).to.equal(!this.defaultTransferable);

        });

        it('Setting transferability doesn\'t affect burnability', async function () {
            const tokenIdToChange = getRandomMintedTokenId(this.initialMint);
            const newTransferableValue = !this.defaultTransferable;

            // Change default transferability of one of the NFTs
            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToChange, newTransferableValue);

            // Check for transferability
            expect(await this.CommanderToken.isTransferable(tokenIdToChange)).to.equal(newTransferableValue);

            // Check for burnability
            expect(await this.CommanderToken.isBurnable(tokenIdToChange)).to.equal(this.defaultBurnable);

        });

        it('Is able to make NFTs burnable and check for burnability', async function () {

            const tokenIdToChange = getRandomMintedTokenId(this.initialMint);

            // Change default burnability of one of the NFTs
            await this.CommanderToken.connect(this.owner).setBurnable(tokenIdToChange, !this.defaultBurnable);

            // Check for burnability
            for (let i = 1; i <= this.initialMint.length; i++) {
                expect(await this.CommanderToken.isBurnable(i)).to.equal(i == tokenIdToChange ? !this.defaultBurnable : this.defaultBurnable);
            }
        });

        it('Setting burnability doesn\'t affect transferability', async function () {
            const tokenIdToChange = getRandomMintedTokenId(this.initialMint);
            const newBurnableValue = !this.defaultBurnable;

            // Change default burnability of one of the NFTs
            await this.CommanderToken.connect(this.owner).setBurnable(tokenIdToChange, newBurnableValue);

            // Check for burnability
            expect(await this.CommanderToken.isBurnable(tokenIdToChange)).to.equal(newBurnableValue);

            expect(await this.CommanderToken.isTransferable(tokenIdToChange)).to.equal(this.defaultTransferable);

        });

    });

    describe('Dependence', function () {


        it('Default dependence', async function () {

            const [tokenIdToChange, dependentTokenId] = getRandomMintedTokens(this.initialMint)

            const defaultDependence = false;
            const dependableContractAddress = this.CommanderToken.address;

            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(defaultDependence);

        });

        it('Setting dependence', async function () {
            const [tokenIdToChange, dependentTokenId] = getRandomMintedTokens(this.initialMint)

            const defaultDependence = false;
            const isDependent = true;
            const dependableContractAddress = this.CommanderToken.address;

            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(defaultDependence);

            // Change default burnability of one of the NFTs
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToChange, dependableContractAddress, dependentTokenId);


            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(isDependent);


        });

    });


    describe('Transfers', function () {
        it('From wallet to wallet', async function () {
            const tokenIdToTransfer = getRandomMintedTokenId(this.initialMint);
            const transferToWallet = this.wallet2.address;

            const ownerAddress = await this.CommanderToken.ownerOf(tokenIdToTransfer);
            expect(ownerAddress).to.not.equal(transferToWallet);
            expect(ownerAddress).to.equal(this.owner.address);

            await this.CommanderToken.connect(this.owner).transferFrom(ownerAddress, transferToWallet, tokenIdToTransfer);

            const newOwnerAddress = await this.CommanderToken.ownerOf(tokenIdToTransfer);

            expect(newOwnerAddress).to.equal(transferToWallet);


        })


        it('Token not transfarable', async function () {
            const tokenIdToTransfer = getRandomMintedTokenId(this.initialMint);
            const transferToWallet = this.wallet2.address;

            const ownerAddress = await this.CommanderToken.ownerOf(tokenIdToTransfer);
            expect(ownerAddress).to.not.equal(transferToWallet);
            expect(ownerAddress).to.equal(this.owner.address);

            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToTransfer, false);

            expect(await this.CommanderToken.isTokenTranferable(tokenIdToTransfer)).to.equal(false);


        })

        it('Dependency not transfarable', async function () {

            const [tokenIdToChange, dependentTokenId] = getRandomMintedTokens(this.initialMint)

            const defaultDependence = false;
            const isDependent = true;
            const dependableContractAddress = this.CommanderToken.address;

            await this.CommanderToken.connect(this.owner).setTransferable(dependentTokenId, false);


            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(defaultDependence);

            // Change default burnability of one of the NFTs
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToChange, dependableContractAddress, dependentTokenId);


            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(isDependent);



            const transferToWallet = this.wallet2.address;


            expect(await this.CommanderToken.isTokenTranferable(tokenIdToChange)).to.equal(false);



        })



    });

    it('Lock works', async function () {

    });

    it('Lock doesnt work when 2 different owners', async function () {

    });

    it('Lock a=>b, a not transfarable by owner only by contract b', async function () {

    });

    it('Dependant also locks', async function () {

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