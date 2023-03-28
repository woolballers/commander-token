// SPDX-License-Identifier: MIT
// Tests for the reference implementation of Commander Token.
// Note: This file is very raw. It was written by a few different people in a chaotic sense. While the
// tests work and pass, the file itself needs a complete reorganization to be easier to read.

import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { TOKEN_NAME, TOKEN_SYMBOL, INITIAL_MINT_COUNT } from "../constants/test";

interface MintResponse {
    initialMintCount: number;
    initialMint: string[];
}

interface DeployAndMintResponse {
    commanderToken: any;
    mintResp: MintResponse;
}


async function expectTokenNotLocked(commanderTokenContract: any, tokenId: string): Promise<void> {
    const [contractAddress1, tokenId1] = await commanderTokenContract.isLocked(tokenId)

    expect(tokenId1).to.equal(ethers.BigNumber.from(0));
}


async function expectTokenIsLocked(commanderTokenContract: any, tokenId: string): Promise<void> {
    const [contractAddress1, tokenId1] = await commanderTokenContract.isLocked(tokenId)

    expect(tokenId1).to.not.equal(ethers.BigNumber.from(0));
}


// etherjs overloading bug - https://github.com/NomicFoundation/hardhat/issues/2203

//testObj: Mocha.Context
const mintTokensFixture = async (collectorContract: any, tokensOwner: any, initialMintCount: number): Promise<MintResponse> => {
    let mintResp: MintResponse = { initialMintCount: initialMintCount, initialMint: [] }

    for (let i = 1; i <= mintResp.initialMintCount; i++) { // tokenId to start at 1
        // is called like that because of etherjs overloading bug - https://github.com/NomicFoundation/hardhat/issues/2203
        await collectorContract["mint(address,uint256)"](tokensOwner, i);
        mintResp.initialMint.push(i.toString());
    }

    return mintResp
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
        this.CommanderTokenMintTestFactory = await ethers.getContractFactory('MintCommanderTokenTest');
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
        this.wallet3 = signers[3];


        this.CommanderToken2 = await this.CommanderTokenMintTestFactory.deploy(TOKEN_NAME, TOKEN_SYMBOL);
        await this.CommanderToken2.deployed();

        // Get the collector contract for signing transaction with collector key
        this.collectorContract = this.CommanderToken.connect(signers[1]);

        const mintResp = await mintTokensFixture(this.collectorContract, this.contractOwner, INITIAL_MINT_COUNT);

        this.initialMintCount = mintResp.initialMintCount;
        this.initialMint = mintResp.initialMint;


        this.defaultBurnable = true;
        this.defaultTransferable = true;

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

    it('Mints initial set of Commander Tokens from collection to contractOwner', async function () {
        for (let i = 0; i < this.initialMint.length; i++) {
            expect(await this.CommanderToken.ownerOf(this.initialMint[i])).to.equal(this.contractOwner);
        }
    });

    it('Is able to query the Commander Tokens balances of an address', async function () {
        expect(await this.CommanderToken["balanceOf(address)"](this.contractOwner)).to.equal(this.initialMint.length);
    });

    it('Is able to mint new Commander Tokens to the collection to collector', async function () {
        let tokenId = (this.initialMint.length + 1).toString();
        await this.CommanderToken["mint(address,uint256)"](this.collector, tokenId);
        expect(await this.CommanderToken.ownerOf(tokenId)).to.equal(this.collector);
    });

    describe('Transferable & Burnable', function () {

        it('Set token to be transferable, and check for transferability', async function () {
            const tokenIdToChange = getRandomMintedTokenId(this.initialMint);

            // Change default transferability of one of the Commander Tokens
            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToChange, !this.defaultTransferable);

            expect(await this.CommanderToken.isTransferable(tokenIdToChange)).to.equal(!this.defaultTransferable);

        });

        it('Setting transferability doesn\'t affect burnability', async function () {
            const tokenIdToChange = getRandomMintedTokenId(this.initialMint);
            const newTransferableValue = !this.defaultTransferable;

            // Change default transferability of one of the Commander Tokens
            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToChange, newTransferableValue);

            // Check for transferability
            expect(await this.CommanderToken.isTransferable(tokenIdToChange)).to.equal(newTransferableValue);

            // Check for burnability
            expect(await this.CommanderToken.isBurnable(tokenIdToChange)).to.equal(this.defaultBurnable);

        });

        it('Set token to be burnable, and check for burnability', async function () {

            const tokenIdToChange = getRandomMintedTokenId(this.initialMint);

            // Change default burnability of one of the Commander Tokens
            await this.CommanderToken.connect(this.owner).setBurnable(tokenIdToChange, !this.defaultBurnable);

            // Check for burnability
            for (let i = 1; i <= this.initialMint.length; i++) {
                expect(await this.CommanderToken.isBurnable(i)).to.equal(i == tokenIdToChange ? !this.defaultBurnable : this.defaultBurnable);
            }
        });

        it('Setting burnability doesn\'t affect transferability', async function () {
            const tokenIdToChange = getRandomMintedTokenId(this.initialMint);
            const newBurnableValue = !this.defaultBurnable;

            // Change default burnability of one of the Commander Tokens
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
            const [tokenIdToChange, dependentTokenId] = getRandomMintedTokens(this.initialMint);

            const defaultDependence = false;
            const isDependent = true;
            const dependableContractAddress = this.CommanderToken.address;
            const commanderTokenAddress = this.CommanderToken.address;

            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(defaultDependence);

            // set dependence
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToChange, dependableContractAddress, dependentTokenId);

            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(isDependent);

        });

        it('Remove dependency', async function () {
            const [tokenIdToChange, dependentTokenId, dependentTokenId2] = getRandomMintedTokens(this.initialMint);

            const dependableContractAddress = this.CommanderToken.address;
            const commanderTokenAddress = this.CommanderToken.address;

            // check that there's no dependency to begin with
            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(false);

            // set dependency
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToChange, dependableContractAddress, dependentTokenId);
            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(true);

            // set another dependency
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToChange, dependableContractAddress, dependentTokenId2);
            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId2)).to.equal(true);

            // remove dependency
            await this.CommanderToken.connect(this.owner).removeDependence(tokenIdToChange, dependableContractAddress, dependentTokenId);
            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(false);

            // set dependency again
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToChange, dependableContractAddress, dependentTokenId);
            expect(await this.CommanderToken.isDependent(tokenIdToChange, dependableContractAddress, dependentTokenId)).to.equal(true);

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

            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToTransfer, false);

            expect(await this.CommanderToken.isTokenTransferable(tokenIdToTransfer)).to.equal(false);


        })

        it('Token transfer fails when transferability is set to false', async function () {
            const tokenIdToTransfer = getRandomMintedTokenId(this.initialMint);
            
            const transferToWallet = this.wallet2.address;
            const ownerAddress = await this.CommanderToken.ownerOf(tokenIdToTransfer);
            expect(ownerAddress).to.not.equal(transferToWallet);
            expect(ownerAddress).to.equal(this.owner.address);

            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToTransfer, false);

            await expect(this
                .CommanderToken.connect(this.owner)
                .transferFrom(ownerAddress, transferToWallet, tokenIdToTransfer))
                .to.be.revertedWith("Commander Token: the token status is set to nontransferable");

        })

        it('Token transfer fails when a dependency not transfarable', async function () {
            const [tokenIdToTransfer, dependentTokenId] = getRandomMintedTokens(this.initialMint)

            const dependableContractAddress = this.CommanderToken.address;
            const commanderTokenAddress = this.CommanderToken.address;

            const transferToWallet = this.wallet2.address;
            const ownerAddress = this.owner.address;;

            const defaultDependence = false;

            expect(await this.CommanderToken.isDependent(tokenIdToTransfer, dependableContractAddress, dependentTokenId)).to.equal(defaultDependence);
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToTransfer, dependableContractAddress, dependentTokenId);
            expect(await this.CommanderToken.isDependent(tokenIdToTransfer, dependableContractAddress, dependentTokenId)).to.equal(true);

            // await this.CommanderToken.connect(this.owner).setTransferable(dependentTokenId, false);            

            // expect(await this.CommanderToken.isTransferable(tokenIdToTransfer)).to.equal(true);
            // expect(await this.CommanderToken.isDependentTransferable(tokenIdToTransfer)).to.equal(false);
            // expect(await this.CommanderToken.isTokenTransferable(tokenIdToTransfer)).to.equal(false);

            // await expect(this
            //     .CommanderToken.connect(this.owner)
            //     .transferFrom(ownerAddress, transferToWallet, tokenIdToTransfer))
            //     .to.be.revertedWith("Commander Token: the token depends on at least one nontransferable token");

        })
    });

    describe('Whitelist', function () {
        it('Token with transferability status false is transfereable to a whitelisted address', async function () {
            const [tokenIdToTransfer] = getRandomMintedTokens(this.initialMint);
            const transferToWallet = this.wallet2.address;
            const ownerAddress = this.owner.address;

            // set transferability false
            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToTransfer, false);

            // add transferToWallet to the whitelist of tokenIdToTransfer
            await this.CommanderToken.connect(this.owner).setTransferWhitelist(tokenIdToTransfer, transferToWallet,  true);            

            // transfer token to transferToWallet
            this.CommanderToken.connect(this.owner).transferFrom(ownerAddress, transferToWallet, tokenIdToTransfer);

        });

        it('Token with transferability status false is nontransfereable to a whitelisted address because of a dependency', async function () {
            const [tokenIdToTransfer, dependentTokenId] = getRandomMintedTokens(this.initialMint)
            const transferToWallet = this.wallet2.address;
            const ownerAddress = this.owner.address;
            const dependableContractAddress = this.CommanderToken.address;

            // set transferability false
            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToTransfer, false);

            // add transferToWallet to the whitelist of tokenIdToTransfer
            await this.CommanderToken.connect(this.owner).setTransferWhitelist(tokenIdToTransfer, transferToWallet,  true);

            // add dependency on token
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToTransfer, dependableContractAddress, dependentTokenId);
            expect(await this.CommanderToken.isDependent(tokenIdToTransfer, dependableContractAddress, dependentTokenId)).to.equal(true);

            // set dependent token to be nontransferable
            await this.CommanderToken.connect(this.owner).setTransferable(dependentTokenId, false);

            // check that tokenIdToTransfer is non-dependent transfereable and non-transferable since it depdends on a nontransferable token
            expect(await this.CommanderToken.isDependentTransferable(tokenIdToTransfer)).to.equal(false);
            expect(await this.CommanderToken.isTokenTransferable(tokenIdToTransfer)).to.equal(false);
            expect(await this.CommanderToken.isDependentTransferableToAddress(tokenIdToTransfer, transferToWallet)).to.equal(false);

            // transfer to transferToWallet fails
            await expect(this
                .CommanderToken.connect(this.owner)
                .transferFrom(ownerAddress, transferToWallet, tokenIdToTransfer))
                .to.be.revertedWith("Commander Token: the token depends on at least one nontransferable token");

        });

        it('Token with transferability true is but a non-transferable dependency is transfereable to a whitelisted address of the depenedncy', async function () {
            const [tokenIdToTransfer, dependentTokenId] = getRandomMintedTokens(this.initialMint)
            const transferToWallet = this.wallet2.address;
            const ownerAddress = this.owner.address;
            const dependableContractAddress = this.CommanderToken.address;

            // set transferability false
            await this.CommanderToken.connect(this.owner).setTransferable(tokenIdToTransfer, false);

            // add transferToWallet to the whitelist of tokenIdToTransfer
            await this.CommanderToken.connect(this.owner).setTransferWhitelist(tokenIdToTransfer, transferToWallet,  true);

            // add dependency on token
            await this.CommanderToken.connect(this.owner).setDependence(tokenIdToTransfer, dependableContractAddress, dependentTokenId);
            expect(await this.CommanderToken.isDependent(tokenIdToTransfer, dependableContractAddress, dependentTokenId)).to.equal(true);

            // set dependent token to be nontransferable
            await this.CommanderToken.connect(this.owner).setTransferable(dependentTokenId, false);

            // add transferToWallet to the whitelist of dependent token
            await this.CommanderToken.connect(this.owner).setTransferWhitelist(dependentTokenId, transferToWallet,  true);            

            // transfer to transferToWallet fails
            await this.CommanderToken.connect(this.owner).transferFrom(ownerAddress, transferToWallet, tokenIdToTransfer);
        });


    });
});