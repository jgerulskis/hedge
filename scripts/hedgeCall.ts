import { ethers } from 'hardhat'
import { MAX_UINT } from '@lyrafinance/protocol/dist/scripts/util/web3utils'
import { impersonateAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";

import { ONE_ETHER } from '../constants/units'
import { ERC_20_ARTIFACT, HEDGE_ARTIFACT } from '../constants/artifacts'
import {
  LYRA_REGISTRY,
  LYRA_OPTION_MARKET,
  SNX_PERPV2_PROXY,
  USDC_ADDRESS,
  SUSD_ADDRESS,
  ACCOUNT_WITH_BALANCE,
} from '../constants/addresses'


// provider
const provider = new ethers.providers.JsonRpcProvider('https://optimism-mainnet.infura.io/v3/933fbd4743794cb7830f44fa8d806d23')

// constants
const AMOUNT_OF_CONTRACTS = ONE_ETHER
const STRIKE_ID = 178

async function main() {
  // 1. create imposter
  await impersonateAccount(ACCOUNT_WITH_BALANCE)
  const impersonatedSigner = await ethers.getSigner(ACCOUNT_WITH_BALANCE)

  // 2. deploy hedge contract
  const hedgeContractFactory = await ethers.getContractFactory(HEDGE_ARTIFACT)
  const hedgeContract = await hedgeContractFactory.connect(impersonatedSigner).deploy(LYRA_REGISTRY, LYRA_OPTION_MARKET, SNX_PERPV2_PROXY, SUSD_ADDRESS)
  await hedgeContract.deployed()

  // 3. approve collateral for hedge contract
  const quoteAsset = await ethers.getContractAt(ERC_20_ARTIFACT, USDC_ADDRESS)
  const amountToApprove =  await hedgeContract.connect(impersonatedSigner).getQuoteAssetAmountFromOptionsAmount(AMOUNT_OF_CONTRACTS, STRIKE_ID)
  await quoteAsset.connect(impersonatedSigner).approve(hedgeContract.address, amountToApprove)
  const snxQuoteAsset = await ethers.getContractAt(ERC_20_ARTIFACT, SUSD_ADDRESS)
  await snxQuoteAsset.connect(impersonatedSigner).approve(hedgeContract.address, MAX_UINT)
  
  // 4. call buyHedgedCall
  await logBalances(ACCOUNT_WITH_BALANCE, `${ACCOUNT_WITH_BALANCE} balance before`)
  const tx = await hedgeContract.connect(impersonatedSigner).buyHedgedCall(STRIKE_ID, AMOUNT_OF_CONTRACTS)
  await tx.wait()
  await logBalances(ACCOUNT_WITH_BALANCE, `${ACCOUNT_WITH_BALANCE} balance after`)

  // @block 108310000 >>> Aug-16-2023 08:46:17 PM +UTC $1,805.68 / ETH 
  // @block 108315823 >>> Aug-17-2023 12:00:23 AM +UTC $1,681.86 / ETH
  await advanceBlocks(5812)
  await hedgeContract.connect(impersonatedSigner).rehedge()
}

async function logBalances(account: string, name: string): Promise<void> {
  try {
    const usdcContract = await ethers.getContractAt(ERC_20_ARTIFACT, USDC_ADDRESS)
    const usdcBalance = await usdcContract.balanceOf(account)
    const susdContract = await ethers.getContractAt(ERC_20_ARTIFACT, SUSD_ADDRESS)
    const susdBalance = await susdContract.balanceOf(account)
    const ethBalance = await provider.getBalance(account)
    console.log(`${name}:\n\t${ethers.utils.formatEther(ethBalance)} ETH\n\t${ethers.utils.formatUnits(usdcBalance, 6)} USDC\n\t${ethers.utils.formatEther(susdBalance)} SUSD`)
  } catch (error) {
    console.log('Error log balances', error)
  }
}

async function advanceBlocks(numBlocks: number): Promise<void> {
  for (let i = 0; i < numBlocks; i++) {
      await ethers.provider.send("evm_mine");
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})