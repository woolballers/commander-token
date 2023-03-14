/**
 * @type import('hardhat/config').HardhatUserConfig
 */

import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // // If you want to do some forking, uncomment this
      // forking: {
      //   url: MAINNET_RPC_URL
      // }
    },
    localhost: {},
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer.
    },
    feeCollector: {
      default: 1,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
      	settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        }
      },
    ],
  },
  mocha: {
    timeout: 100000,
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v5",
  },
};
