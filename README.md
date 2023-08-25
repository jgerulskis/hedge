# Lyra Test

This project is a test of the Lyra protocol.

## Hedge.sol

buyHedgedCall(strikeId, amount)
1. Buys a long call option with strikeId and amount using Lyra.
2. Transfers margin and then buys a short of delta * (amount of call options) using Synthetix.
3. Transfers Lyra option token and remaining Lyra quote asset (USDC for the script example) to the original sender.

rehedge()
1. Looks at current open position.
2. Compares current short with the the new call option delta.
3. Withdraws or deposits the difference from short position to become delta neutral again.

## Setup
```shell
yarn
npx hardhat node --fork https://optimism-mainnet.infura.io/v3/api_key --fork-block-number 108310000
// new terminal
yarn run deploy:hedge
```

## Todo

1. Give owner of Hedge better control over open positions on Synthetix / Lyra
2. Add tests
