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
describe('LockedToken', function () {
    before(async function () {
        this.CommanderTokenMintTestFactory = await ethers.getContractFactory('MintLockedTokenTest');
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


        this.defaultBurnable = false;
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


    });

    describe('Locks', function () {

        it('Lock works', async function () {
            const [lockedTokenId, lockedByTokenId] = getRandomMintedTokens(this.initialMint)

            const lockedByTokenContractAddress = this.CommanderToken.address;


            await expectTokenNotLocked(this.CommanderToken, lockedTokenId);

            await this.CommanderToken.connect(this.owner).lock(lockedTokenId, lockedByTokenContractAddress, lockedByTokenId);

            const [contractAddress2, tokenId2] = await this.CommanderToken.isLocked(lockedTokenId)

            expect(contractAddress2).to.equal(lockedByTokenContractAddress);

            expect(tokenId2).to.equal(lockedByTokenId);
        });

        it('Lock doesnt work when 2 different owners', async function () {
            const [lockedTokenId, lockedByTokenId] = getRandomMintedTokens(this.initialMint)

            const lockedByTokenContractAddress = this.CommanderToken.address;
            const newOwner = this.wallet2.address;

            const ownerAddress = await this.CommanderToken.ownerOf(lockedByTokenId);
            expect(ownerAddress).to.not.equal(newOwner);
            expect(ownerAddress).to.equal(this.owner.address);

            await this.CommanderToken.connect(this.owner).transferFrom(ownerAddress, newOwner, lockedByTokenId);

            const newOwnerAddress = await this.CommanderToken.ownerOf(lockedByTokenId);

            expect(newOwnerAddress).to.equal(newOwner);

            // lock

            await expectTokenNotLocked(this.CommanderToken, lockedTokenId)

            expect(this.CommanderToken.connect(this.owner).lock(lockedTokenId, lockedByTokenContractAddress, lockedByTokenId)).to.be.revertedWith("CommanderToken: not sameOwner")


        });

        it('Lock a=>b, a not transfarable by owner only by contract b', async function () {

        });
    });

});