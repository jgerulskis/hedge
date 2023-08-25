import "@nomicfoundation/hardhat-toolbox";
import '@nomiclabs/hardhat-ethers';
import 'hardhat-dependency-compiler'

import { HardhatUserConfig } from "hardhat/config";
import { lyraContractPaths } from '@lyrafinance/protocol/dist/test/utils/package/index-paths'

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.9',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://optimism-mainnet.infura.io/v3/933fbd4743794cb7830f44fa8d806d23",
        blockNumber: 108200000,
      }
    }
  },
  dependencyCompiler: {
    paths: lyraContractPaths,
  },
};

export default config;
