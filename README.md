<!-- ABOUT THE PROJECT -->

## About The Project

The goal of ERC721U is to provide a fully compliant implementation of IERC721 with significant gas savings for minting single NFTs. This project and implementation will be updated regularly and will continue to stay up to date with best practices.

The [FrensReasearchGroup](https://twitter.com/FrensRG) team created ERC721U for its sale on TBA. We wanted to create something for collection of smaller size or in other words genesis collection to also leverage from potential gas savings when it comes to minting. And with this ERC implementation all of those collections would potentially be some of the cheapest of the market.

**FrensRG is not liable for any outcomes as a result of using ERC721U.** DYOR.

## Installation

```sh

forge install FrensRG/ERC721U

```

## Contracts

```ml
src
├─extensions  
   └─ Basic
     └─ERC721UBasic_Optimized.sol - This contract doesn't track the    total supply neither the burnt tokens. Use this if you only care about gas savings.
      ├─ test
        └- ERC721UBasic_Optimized.t — Exhaustive Tests
   └─ Optimized
      └─ERC721U_Optimized.sol - This contract is the optimized version of ERC721U. It has everything that ERC721U.sol has but with  gas savings.
      ├─ test
        └- ERC721U_Optimized.t — Exhaustive Tests            
├─ ERC721U — Main contract. Use this contract if you want readability from it.
├─ IERC721U - Contract Interface
test
└- ERC721U.t — Exhaustive Tests
```

<!-- USAGE EXAMPLES -->

## Usage

Once installed, you can use the contracts in the library by importing them:

```solidity
pragma solidity ^0.8.4;

import "ERC721U/src/ERC721U.sol";

contract U.D.O is ERC721U {
    constructor() ERC721U("UDO", "UDO") {}

    function mint() external payable {
        // `_mint`'s now only takes the address argument since `tokenId` will be the uint160 representation of the minting address.
        _mint(msg.sender);
    }
}
```

<!-- CONTRIBUTING -->

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<!-- LICENSE -->

## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<!-- CONTACT -->

## Contact
- 0xRaiden (maintainer) - [@0xRaiden_](https://twitter.com/0xRaiden_)

Project Link: [https://github.com/Raiden1411/ERC721U](https://github.com/Raiden1411/ERC721U)


## Development

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.
