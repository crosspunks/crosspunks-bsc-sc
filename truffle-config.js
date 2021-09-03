// eslint-disable-next-line import/no-extraneous-dependencies
const TestRPC = require('ganache-cli');
const HDWalletProvider = require('@truffle/hdwallet-provider');
const { privKey, BSCSCANAPIKEY } = require('./env.json');

module.exports = {
  networks: {
    development: {
      provider: TestRPC.provider(),
      network_id: '*',
    },
    testnet: {
      provider: () => new HDWalletProvider(privKey, 'https://data-seed-prebsc-1-s3.binance.org:8545'),
      network_id: 97,
      confirmations: 2,
      skipDryRun: true,
      networkCheckTimeout: 500000000,
      timeoutBlocks: 20000,
    },
    bsc: {
      provider: () => new HDWalletProvider(privKey, 'https://bsc-dataseed1.binance.org'),
      network_id: 56,
      confirmations: 2,
      skipDryRun: true,
      gasPrice: 10000000000,
    },
  },
  plugins: ['truffle-plugin-verify', 'solidity-coverage'],
  api_keys: {
    bscscan: BSCSCANAPIKEY,
  },
  compilers: {
    solc: {
      version: '^0.6.12',
      settings: {
        optimizer: {
          enabled: true,
        },
      },
    },
  },
};
