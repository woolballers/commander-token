<p align="center">
    <img alt="CommanderToken" title="CommanderToken" src="https://raw.githubusercontent.com/woolballers/commander-token-contracts/main/docs/images/commandertoken.png" width="500">
</p>

# CommanderToken

## What is Commander Token?
Commander Token are two token standards enhancing ERC721 with refined control options for transfering or burning tokens. 

The first standard, the eponymous Commander Token, is an ERC727 token with partial transferability and burnability. Commander Token standard allow any behaviour from full transferability (regular ERC721), non-transferability (Soulbound Tokens),  or anything in between, including transferability controlled by a community (community bounded tokens), or transferability that changes with time. The same goes for burnability.

The second standard, Locked Tokens, basically binds Tokens together. If a group of tokens, that belong to the same owner, are locked together, it means that they will always be transferred together. As long as the locking exists, the owner can't transfer any of the tokens separately.

We describe below more in details what each of these standards mean, and how their mechanism works.

Commander Token was created for [Woolball project](https://woolball.xyz), but is independent of the project and can be used for many other use cases, see Motivation below.

## Who needs it?

[Woolball](https://woolball.xyz) is an ID system where IDs can create links to one another. For Wooolball links to be meaningfull commitments, they need to be able to impose limitations on the ID that created the link. Commander Tokens are used for that.  

Commander Tokens enable easy creation of Soulbound tokens. i.e., tokens that cannot be transferred. They even make it easy to create Soulbound tokens that are attached to a name (like, to a Woolball ID). Furthen extensions of Soulbound tokens can also be implemented using Commander Tokens, such as community controlled tokens, I.e., a community can recover them and decide to transfer them to another wallet. 

Locked tokens are created for collection of tokens, where we want all the collection to always have the same owner. An example is a classic name system, with domains and subsomains. Each domain and each subdomain is represented by an a token. If we lock all the subdomain to the domain, then each time the domain is transferred, so do all of its subdomains.

## Mechanism description
In what follows we discuss for brevity only the transferability mechanism of Commander Token, but mean the Burnability mechanism as well.

### Commander Token
There are two mechanisms to control transferability of a Commander Token.

The first is a simple `setTransferable` function, that marks the token as transferable or not. In our reference implementation this function is called by the owner of the token, but more elaborate implenetations, giving control to someone else, a community or even a smart contrat, are possible

The second mechanism is "dependence". It is a more sophisticated one. Using this mechanism, the owner of a token can set the token to depend on another token, possibly from another contract. Once a token depends on another token, it is transferable only if the other token is transferable as well. A token can be dependent on many different other tokens, in which case it is transferable only if they are all transferable as well.

Dependence can be remove by the owner of the token only if the token it depends on is transferable. Otherwise, to remove a dependency, a call from the contract of the token we depend on is needed.


### Locked Token
Locked Tokens, allows automatically transfer of tokens. 

If tokens A and B have the same owner, and token A is locked to token B, then every time that Token B is transfered, so does Token A, and the only way to transfer Token A, as long as the locking is in place, is transferring Token B.

## Interface
Interface is the list of public and external functions the contract provides.

### Commander Token
The full interface in solidity is in the file `ICommanderToken.sol`.

#### Manage dependencies
Sets dependence of one token (called Solider Token or ST) on another token (called Commander Token or CT). 
     
The dependency means that if CT is not transferable or burnable, then so does tokenId.

Dependency can remove either by the owner of tokenId (in case CTId is both transferable or burnable), or by the a transaction from contract CTContractAddress.
```
function setDependence(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

function setDependenceUnsafe(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

function removeDependence(uint256 tokenId, address CTContractAddress, uint256 CTId) external;

function isDependent(uint256 tokenId, address CTContractAddress, uint256 CTId) external view returns (bool);
```

#### Manage transferability and burnability
These functions are for managing the effect of dependence of tokens. If a token is untransferable, then all the tokens depending on it are untransferable as well. If a token is unburnable, then all the tokens depending on it are unburnable as well.

```
    function setTransferable(uint256 tokenId, bool transferable) external;
    function setBurnable(uint256 tokenId, bool burnable) external;
```

#### Check transferability and burnability
The following functions set and check the transferable and burnable properties of the token.

```
function setTransferable(uint256 tokenId, bool transferable) external;
function setBurnable(uint256 tokenId, bool burnable) external;

function isTransferable(uint256 tokenId) external view returns (bool);
function isBurnable(uint256 tokenId) external view returns (bool);
```

The following functions check if all the dependencies of a token are transferable/burnable.

```
<b>isDependentTransferable</b>(tokenId) external view returns (bool);
<b>isDependentBurnable</b>(tokenId) external view returns (bool);
```

Finally, the following functions check if the token can be transfered/burned, i.e., it is a combination of the previous two methods.

```
<b>isTokenTransferable</b>(tokenID) external view returns (bool);
<b>isTokenBurnable</b>(tokenID) external view returns (bool);
```

#### Whitelist mechanism
The whitelist mechanism allows selective transferability, meaning that even if a token is nontransferable in general, it can still be transferable to a specific list of tokens.

The following functions are provided.

<pre>
<b>setTransferWhitelist</b>(tokenId, whitelistAddress, isWhitelisted)

<b>isTransferableToAddress</b>(tokenId, transferToAddress) returns (bool);

<b>isDependentTransferableToAddress</b>(tokenId, transferToAddress) returns (bool);

<b>isTokenTransferableToAddress</b>(tokenId, transferToAddress) returns (bool);
</pre>



### Locked Token
The full interface in solidity is in the file `ILockedToken.sol`.

Locks a Solider Token (ST) to a Commander Token (CT). Both tokens must have the same owner.

The ST transfer and burn functions can't be called by its owner as long as the locking is in place.

If the CT is transferred or burned, it also transfers or burns the ST.

If the ST is untransferable or unburnable, then a call to the transfer or burn function of the CT unlocks the ST.

<pre>
<b>lock</b>(tokenId, CTContract, CTId)

<b>unlock</b>(tokenId)

<b>isLocked</b>(tokenId) returns (address, uint256);

</pre>


## Implementation
This repository includes a reference implementation of Commander Token and Locked Tokens.

All the functions are virtual and can be overridden in case you need to extend the functionality.

## State of development
Commander Token and Locked Tokens are work in progress. The functionality is fully implemented, and there are tests for all the functions, but the code was not audited, and is dangerous to use on live blockchains at the moment.
