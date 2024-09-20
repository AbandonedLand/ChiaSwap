# ChiaSwap
Chia Swap is a concentrated liquidity program that uses the UniSwap V3 formula for concentrated Liquidy.


# Concentrated Liquidity
Concentrated liquidity can be provided between two prices.  The upper and lower price.   For example, if you want to trade between the ranges of 12.50 - 15.50 and the current price is  13.4.


# How to use

## Step 1 - Create Config
This config will set an upper price per xch at $15.50, a Lower price per xch of 12.50 and the starting price of 14.10.   
This will use the Base Wrapped USDC coin and we are starting with 100 XCH as liquidity.
There will be 100 steps between the highest price and lowest price. 

**Note: This config is created once, even if the current price changes, this is data is used for the formula for the concentrated liquidity.  Do not keep changing this based on the current price.**

```PowerShell
 New-ChiaSwapConfig -UpperPrice 15.50 -LowerPrice 12.50 -StartingPrice 14.10 -FeePercent 0.008 -CatCoin wUSDC.b -StartingXch 100 -Steps 100 -Force
```

## Step 2 - Grab your new Config
This step creates the liquidity data needed for trading.
```PowerShell
$Config = Get-ChiaSwapConfig 
```

## Step 3 - (Optional) Determine how much XCH/CAT you need to provide liquidity.
```PowerShell
Get-LiquidityRequirements $Config

CatToken        : wUSDC.b
CatCoinRequired : 1782.574
XchRequired     : 100

```

## Step 4 - Determine how to split your coins.
 - Build your trading table
 ```PowerShell
 $Table = Build-TickTable -Config $Config
 $Quotes = $quotes = Build-QuotesforCurrentXCH -CurrentXch ($Config.StartingXCH*1000000000000)  -Table $table -QuoteDepth 5

 $Quotes | Format-Table

 type amm_offered_amount  fee offered_amount requested_amount amm_price_per_xch final_price_per_xch
---- ------------------  --- -------------- ---------------- ----------------- -------------------
sell              33.05 0.23           2.34            33.28             14.11               14.20
sell              33.12 0.23           2.34            33.35             14.14               14.24
sell              33.19 0.23           2.34            33.42             14.17               14.27
sell              33.26 0.23           2.34            33.49             14.20               14.30
sell              33.33 0.23           2.34            33.57             14.23               14.33
buy               32.97 0.23          32.74             2.34             14.08               13.98
buy               32.90 0.23          32.67             2.34             14.05               13.95
buy               32.83 0.23          32.60             2.34             14.02               13.92
buy               32.76 0.23          32.53             2.34             13.98               13.89
buy               32.69 0.23          32.46             2.34             13.95               13.86
 ```

This gives you an idea of what your trades will look like.  You'll want to split up your XCH into 2.35 size coins.  You'll want to split your wUSDC.b coints into ~33 USDC coins.  For ease of use, I might suggest going even smaller, like 1/3 the size of the required coins.  Something like 1.25xch & 10USD sized coins for this example. 

## Step 5 - Split Coins
Split your coins from the data above. This helps with offer creation.  You'll need at least the same number of available coins as you have put in your quote depth. But more coins is better in this case.

Find XCH Coin ID
```PowerShell
chia wallet coins list -i 1

Coin ID: 0x93d10a7e8837c8572b2941736b2b9a8887ad2698b5e4ca701d7d971ef39f3b01                                                      Address: xch1cpnahpdtqdu7k9cvprc6c0ug7apaz0dk7hw0nl5enfw0mnhvnc5sbbvn Amount: 100  (100000000000000 mojo), Confirmed in block: 5901656
```
You'll copy the coin id to do the split.  For ease of demonstration we'll split 100 XCH into 200 0.5 XCH coins.
```PowerShell
chia wallet coins split -i 1 -n 200 -a 0.5 -t 0x93d10a7e8837c8572b2941736b2b9a8887ad2698b5e4ca701d7d971ef39f3b01  
```

Repeat this process for your CAT coin.   
Details can be found here: (https://docs.chia.net/wallet-cli/#coins)

## Step 6 - Run the AMM
Run Start-TradingBot with a Config and QuoteDepth.

> [!WARNING]  
> This script reads your total XCH to determin how to price your next sale.  Only run 1 trading bot per  PC/Wallet/VM.  If you have extra XCH in your wallet, the pricing infrormation will be incorrect.  

> [!CAUTION]
> The only coins in the wallet should consist of the trading pair you wish to trade.  Only 1 Trading Pair per PC/Wallet/VM.

```PowerShell
Start-TradingBot -Config $Config -QuoteDepth 20
```