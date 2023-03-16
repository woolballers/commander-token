<p align="center">
    <img alt="CommanderToken" title="CommanderToken" src="https://raw.githubusercontent.com/woolballers/commander-token-contracts/main/docs/images/commandertoken.png" width="500">
</p>

# CommanderToken

### What is Commander Token?
Commander Token are two token standards enhancing ERC721 with more complicated transfer and burn behaviours.

The first standard, the eponymous Commander Token, is an ERC7271 token with partial transferability and burnability. By this we mean that in certain situations, Commander Tokens cannot be transferred or burned (but in other situations they can). 

The second standard, Locked Tokens, basically binds Tokens together. If a group of tokens, that belong to the same owner, are locked together, it means that they will always be transferred together. As long as the locking exists, the owner can't transfer any of the tokens separately.

We describe below more in details what each of these standards mean, and how their mechanism works.

Commander Token was created for [Woolball project](https://woolball.xyz), but is independent of the project and can be used for many other use cases, see Motivation below.
