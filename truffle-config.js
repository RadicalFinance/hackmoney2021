const HDWalletProvider = require("@truffle/hdwallet-provider");
require('dotenv').config();

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      websockets: true,
      gas: 0x989680
    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(`${process.env.MNEMONIC}`, `wss://rinkeby.infura.io/ws/v3/${process.env.INFURA_ID}`)
      },
      network_id: 4,
      gas: 0x989680,
    },
    kovan: {
      provider: function() {
        return new HDWalletProvider(`${process.env.MNEMONIC}`, `wss://kovan.infura.io/ws/v3/${process.env.INFURA_ID}`)
      },
      network_id: 42,
      gas: 0x989680
    },
    goerli: {
      provider: function() {
        return new HDWalletProvider(`${process.env.MNEMONIC}`, `wss://goerli.infura.io/ws/v3/${process.env.INFURA_ID}`)
      },
      network_id: 5,
      gas: 0x989680
    }
  },
  compilers: {
    solc: {
       version: "0.8.6",
       settings: {
         optimisations: true,
         runs: 200
       }
    }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY
  }
};
