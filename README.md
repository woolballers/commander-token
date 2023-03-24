<h1 align="center"> Commander Token and Locked Token </h1> <br>
<p align="center">
    <img alt="CommanderToken" title="CommanderToken" src="https://raw.githubusercontent.com/woolballers/commander-token-contracts/main/docs/images/commandertoken.png" width="500">
</p>

<p align="center">
  ERC721 extensions for complex control of transferability and burnability of tokens
</p>

## Table of contents
* [What is Commander Token?](#what-is-commander-token)
* [Who needs it?](#who-needs-it)
* [Mechanism description](#mechanism-description)
* [Interface](#interface)
* [Implementation](#implementation)
* [State of development](#state-of-development)
* [Getting involved](#getting-involved)
* [License](#license)
* [Credits and references](#credits-and-references)

## What is Commander Token?
"Commander Token" are two token standards enhancing ERC721 with refined control options for transferring or burning tokens.

The first standard, the eponymous Commander Token, is an ERC721 token with partial transferability and burnability. The Commander Token standard allows any behavior from full transferability (regular ERC721), non-transferability (Soulbound Tokens), or anything in between, including transferability controlled by a community (community-bounded tokens), or transferability that changes with time. The same goes for burnability.

The second standard, Locked Tokens, basically binds Tokens together. If a group of tokens, that belong to the same owner, are locked together, it means that they will always be transferred together. As long as the locking exists, the owner can't transfer any of the tokens separately.

We describe below more in detail what each of these standards means, and how their mechanism works.

Commander Token was created for [Woolball project](https://woolball.xyz), but is independent of the project and can be used for many other use cases, see Motivation below.


## Who needs it?
Commander Tokens enable the easy creation of Soulbound tokens. i.e., tokens that cannot be transferred. They even make it easy to create Soulbound tokens that are attached to a name. Further extensions of Soulbound tokens can also be implemented using Commander Tokens, such as community-controlled tokens, I.e., a community can recover them and decide to transfer them to another wallet. 

[Woolball](https://woolball.xyz) is an ID system where IDs can create links to one another. For Wooolball links to be meaningful commitments, they need to be able to impose limitations on the ID that created the link. Commander Tokens are used for that.  

Locked tokens are created for a collection of tokens, where we want all the collection to always have the same owner. An example is a classic name system, with domains and subsomains. Each domain and each subdomain is represented by a token. If we lock all the subdomains to the domain, then each time the domain is transferred, so do all of its subdomains.

## Mechanism description
In what follows we discuss for brevity only the "transferability mechanism" of Commander Token but mean the "burnability mechanism" as well.

### Commander Token
There are two mechanisms to control the transferability of a Commander Token.

The first is a simple `setTransferable` function, that marks the token as transferable or not. In our reference implementation this function is called by the owner of the token, but more elaborate implementations, giving control to someone else, a community, or even a smart contract, are possible

The second mechanism is "dependence". It is a more sophisticated one. Using this mechanism, the owner of a token can set the token to depend on another token, possibly from another contract. Once a token depends on another token, it is transferable only if the other token is transferable as well. A token can be dependent on many different other tokens, in which case it is transferable only if they are all transferable as well.

Dependence can be removed by the owner of the token only if the token it depends on is transferable. Otherwise, to remove a dependency, a call from the contract of the token we depend on is needed.

### Locked Token
Locked Tokens enable the automatic transfer of tokens. 

If token A is locked to B, then:
1. A cannot be transferred or burned unless B is transferred or burned, and, 
2. every transfer of B, also transfers A.

Locking is possible if and only if both tokens have the same owner.

## Interface
An interface is the list of public and external functions the contract provides.

### Commander Token
The full interface in solidity is in the file `ICommanderToken.sol`.

#### Manage dependencies
Sets dependence of one token (called tokenId in most functions) on another token (called Commander Token or CT). 
     
The dependency means that if CT is not transferable or burnable, then so does tokenId.

Dependency can remove either by the owner of tokenId (in case CTId is both transferable or burnable), or by the transaction from contract CTContractAddress.

<pre>
    <b>setDependence</b>(tokenId, CTContractAddress, CTId) external;

    <b>setDependenceUnsafe</b>(tokenId, CTContractAddress, CTId) external;

    <b>removeDependence</b>(tokenId, CTContractAddress, CTId) external;

    <b>isDependent</b>(tokenId, CTContractAddress, CTId) external view returns (bool);
</pre>

#### Manage transferability and burnability
These functions are for managing the effect of the dependence on tokens. If a token is untransferable, then all the tokens depending on it are untransferable as well. If a token is unburnable, then all the tokens depending on it are unburnable as well.

<pre>
    <b>setTransferable</b>(tokenId, transferable) external;
    <b>setBurnable</b>(uint256 tokenId, burnable) external;
</pre>

#### Check transferability and burnability
The following functions set and check the transferable and burnable properties of the token.

<pre>
    <b>setTransferable</b>(tokenId, transferable) external;
    <b>setBurnable</b>(tokenId, bool burnable) external;

    <b>isTransferable</b>(tokenId) external view returns (bool);
    <b>isBurnable</b>(tokenId) external view returns (bool);
</pre>

The following functions check if all the dependencies of a token are transferable/burnable.

<pre>
    <b>isDependentTransferable</b>(tokenId) external view returns (bool);
    <b>isDependentBurnable</b>(tokenId) external view returns (bool);
</pre>

Finally, the following functions check if the token can be transferred/burned, i.e., it is a combination of the previous two methods.

<pre>
    <b>isTokenTransferable</b>(tokenID) external view returns (bool);
    <b>isTokenBurnable</b>(tokenID) external view returns (bool);
</pre>

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

<pre>
    <b>lock</b>(tokenId, CTContract, CTId)

    <b>unlock</b>(tokenId)

    <b>isLocked</b>(tokenId) returns (address, uint256);
</pre>

## Implementation
This repository includes a reference implementation of Commander Token and Locked Tokens.

All the functions are virtual and can be overridden in case you need to extend the functionality.

## State of development
Commander Token and Locked Tokens are both a work in progress. The functionality is fully implemented, and there are tests for all the functions, but the code was not audited and is dangerous to use on live blockchains at the moment.

## Getting involved
Commander Token and Locked Token are part of [Woolball](https://woolball.xyz) project, come to [Woolball Discord](discord.gg/SbekPPeCxj) to be involved in Commander Token.


## License
The code in this repository is published under MIT license. The content in this repository is published under CC-BY-SA 3.0 license.


## Credits and references
Commander Token and Locked Tokens were created by the Woollball team, led by [Tomer Leicht](https://github.com/tomlightning) and [Eyal Ron](https://github.com/eyalron33).
