


function New-ChiaSwapConfig {
    <#
    .SYNOPSIS
        Set all the paramaters needed for calculating Concentrated Liquidity.
    .DESCRIPTION
        Creates a file needed for calculating concentrated liquidity.
    .PARAMETER UpperPrice
        The high range of the concentrated liquidity in USD format.  
        For example: 16.00 
    .PARAMETER LowerPrice
        The low range of the concentrated liquidity in USD format.
        For example: 12.00
    .PARAMETER StartingPrice
        The starting price for this concentrated liquidity program.
        For example: 14.00
    .PARAMETER FeePercent
        The fee you wish to collect on each trade.  The fee is input as a decimal.
        For example: 0.007 would be 0.7%
    .PARAMETER FileName 
        Default config.json
        The file name and location to save the file.  The default FileName is config.json
        For example: ./config.json
    .PARAMETER Force
        Overwrites the config file.
    .PARAMETER CatCoin
        Stable coin used in trading between XCH / CatCoin
    .PARAMETER Steps
        Default 100
        The number of trades required to go from the lower liquidity price to upper liquidity price.  
        Steps are used to create a table of offers/request offers.
    .PARAMETER StartingXch
        The Starting XCH used in the calculations
    .PARAMETER StartingCatCoin
        Starting amount of CatCoins.
    #>
    param (
        [Parameter(Mandatory=$true)]
        $UpperPrice,
        [Parameter(Mandatory=$true)]
        $LowerPrice,
        [Parameter(Mandatory=$true)]
        $StartingPrice,
        [Parameter(Mandatory=$true)]
        $FeePercent,
        [Parameter(Mandatory=$true)]
        [ValidateSet("wUSDC","wUSDC.b","wUSDT","SBX","DBX","HOA","wmilliETH","wmilliETH.b")]
        $CatCoin,
        [parameter(Mandatory=$true,
            ParameterSetName="XCH")]
        $StartingXch,
        [parameter(Mandatory=$true,
            ParameterSetName="Stable")]
        $StartingCatCoin,
        $Steps,
        $FileName,
        [switch]$Force
    )


    if(-not $Steps){
        $Steps = 100
    }

    # Creates a default filename of config.json if not set.
    if(-not $FileName){
        $FileName = "config.json"
    }

    # Set the stable coin asset id based on $CatCoin input
    $CatCoinAssetId = switch ($CatCoin){
        "wUSDC" {"bbb51b246fbec1da1305be31dcf17151ccd0b8231a1ec306d7ce9f5b8c742b9e"}
        "wUSDC.b" {"fa4a180ac326e67ea289b869e3448256f6af05721f7cf934cb9901baa6b7a99d"}
        "wUSDT" {"634f9f0de1a6c39a2189948b8e61b6852fbf774f73b0e36e143e841c49a0798c"}
        "SBX" {"a628c1c2c6fcb74d53746157e438e108eab5c0bb3e5c80ff9b1910b3e4832913"}
        "wmilliETH" {"4cb15a8ecc85068fb1f98c09a5e489d1ad61b2af79690ce00f9fc4803c8b597f"}
        "wmilliETH.b" {"f322a205c034fe28681829fa5a2e483ac421f0952eb1292945c8db06e0a471a6"}
        "DBX" {"db1a9020d48d9d4ad22631b66ab4b9ebd3637ef7758ad38881348c5d24c38f20"}
    }
    


    # Validating prices are input properly ($LowerPrice < $StartingPrice < $UpperPrice)
    if(($LowerPrice -lt $StartingPrice) -and ($StartingPrice -lt $UpperPrice)){
         # Create file if no file exists, or overwrite if force is used.
        if((-not (Test-Path -Path $FileName)) -or $Force.IsPresent){
            $Config = @{
                UpperPrice = $UpperPrice
                LowerPrice = $LowerPrice
                StartingPrice = $StartingPrice
                FeePercent = $FeePercent
                Steps = $Steps
                CatCoinAssetId = $CatCoinAssetId
                
            } 
            if($StartingXch -gt 0){
                $Config.Add("StartingXch",$StartingXch)
                
            }
            if($StartingCatCoin -gt 0){
                $Config.Add("StartingCatCoin",$StartingCatCoin)
                
            }
            
            $Config | ConvertTo-Json -Depth 20 | Out-File -FilePath $FileName
            Write-Information "Created file $FileName"
        } else {
            Write-Error "File exists.  Use -Force to overwrite the file."
        }
    } else {
        Write-Error "Please make sure LowerPrice($LowerPrice) < StartingPrice($StartingPrice) < UpperPrice($UpperPrice).  Please correct the pricing and try again."
    }
}

function Convert-AssetIdToWalletId{
    <#
    .SYNOPSIS
        Get the local chia wallet ID from an Asset id.
    .DESCRIPTION
        Calls an RPC endpoint get_wallets and tries to find the wallet id from the asset id.
    .PARAMETER AssetId
        Asset ID of the CAT to add to the chia wallet.  AssetId list can be found here: https://dexie.space/assets
    .EXAMPLE
        Convert-AssetIdToWalletId -AssetId 634f9f0de1a6c39a2189948b8e61b6852fbf774f73b0e36e143e841c49a0798c

        6
    
    #>
    param(
        $AssetId
    )

    # Adding 00 to end of AssetID this is needed to find it in the chia wallet rpc.
    $AssetId = -join($AssetId,'00')

    try{
        $ChiaWallets = (chia rpc wallet get_wallets | ConvertFrom-Json ).wallets
    } catch {
        Write-Error "Could not use the Chia RPC to get wallet information.  Please make sure you have Chia Installed and running."
    }

    $WalletId = $ChiaWallets | Where-Object {$_.data -eq $AssetId}
    if($WalletId){
        $WalletId.id
    } else {
        Write-Error "AssetID $AssetID was not found.  Please add it with the Import-ChiaAssetId function to add the asset to your chia wallet."
    }
}

function Import-ChiaAssetId{
    <#
    .SYNOPSIS 
        Adds AssetId to the chia application.
    .DESCRIPTION
        Uses the Chia RPC to add an existing wallet using the AssetId
    .PARAMETER AssetId
        Asset ID of the CAT to add to the chia wallet.  AssetId list can be found here: https://dexie.space/assets
    .PARAMETER Name
        Name to display in the gui.
    .EXAMPLE 
        Import-ChiaAssetId -AssetId 634f9f0de1a6c39a2189948b8e61b6852fbf774f73b0e36e143e841c49a0798c -Name wUSDT

        asset_id                                                         success type wallet_id
        --------                                                         ------- ---- ---------
        634f9f0de1a6c39a2189948b8e61b6852fbf774f73b0e36e143e841c49a0798c    True    6         6
    
    #>
    param(
        [Parameter(Mandatory=$true)]
        $AssetId,
        [Parameter(Mandatory=$true)]
        $Name
    )
    $json = @{
        wallet_type = "cat_wallet"
        mode = "existing"
        name = $Name
        asset_id = $AssetId
    } | ConvertTo-Json

    try{
        chia rpc wallet create_new_wallet $json | ConvertFrom-Json
    } catch {
        Write-Error "Could not add the asset to the chia wallet."
    }
}

function Get-ChiaSwapConfig {
    <#
    .SYNOPSIS 
        Read the data from the conig file.
    .DESCRIPTION
        Read the config file data and convert it from JSON.
    .PARAMETER FileName
        File name for config file.
    .EXAMPLE
        Get-ChiaSwapConfig
        
        CurrentPrice LowerPrice FeePercent UpperPrice
        ------------ ---------- ---------- ----------
           13.00      12.00       0.01      15.00
    .EXAMPLE
        Get-ChiaSwapConfig -FileName config.json

        CurrentPrice LowerPrice FeePercent UpperPrice
        ------------ ---------- ---------- ----------
           13.00      12.00       0.01      15.00
    #>
    param(
        $FileName
    )

    if(-not $FileName){
        $FileName = "config.json"
    }

    if(Test-Path -Path $FileName){
        try{
            $FileData = Get-Content -Path $FileName | ConvertFrom-Json
  
        } catch {
            Write-Host -ForegroundColor Red "$FileName is not a json file"
        } 
        
    } else {
        Write-Error "File not found."
    }
    
    if($FileData.LowerPrice -and $FileData.UpperPrice -and $FileData.CatCoinAssetId -and $FileData.StartingPrice -and $FileData.Steps -and $FileData.FeePercent){
        if($FileData.StartingCatCoin -gt 0){
            $FileData | Add-Member -MemberType NoteProperty -Name 'Liquidity' -Value (Get-LiquidityFromCatCoin -CatCoinAmount $FileData.StartingCatCoin -Config $FileData)
        }
        if($FileData.StartingXch -gt 0){
            $FileData | Add-Member -MemberType NoteProperty -Name 'Liquidity' -Value (Get-LiquidityFromXch -XchAmount $FileData.StartingXch -Config $FileData)
        }
        $FileData
    } else {
        Write-Error "Invalid config file.  Run New-ChiaSwapConfig to create a new one."
    }
}


function Convert-XchToMojos{
    param(
        [Parameter(Mandatory=$true)]
        [Decimal]$XchAmount
    )
    [Int64]($XchAmount * 1000000000000)
}

function Convert-CatToMojos{
    param(
        [Parameter(Mandatory=$true)]
        [Decimal]$CatAmount
    )
    [Int64]$CatAmount * 1000

}

function Convert-MojosToCat{
    param(
        [Parameter(Mandatory=$true)]
        [Decimal]$MojoAmount
    )
    [Decimal]::round([Decimal]$MojoAmount / 1000,3)
}

function Convert-MojosToXch{
    param(
        [Parameter(Mandatory=$true)]
        [Decimal]$MojoAmount
    )
    [Decimal]::round([Decimal]$MojoAmount / 1000000000000,12)
}

function ConvertTo-Yr{
    param(
        [Parameter(Mandatory=$true)]
        $Amount
    )
    [Int128]($Amount * 1000000000000)
}

function ConvertFrom-Yr{
    param(
        [Parameter(Mandatory=$true)]
        $Amount
    )
    [Decimal]::round([Decimal]$Amount / 1000000000000,12)
}

function ConvertTo-Xr{
    param(
        [Parameter(Mandatory=$true)]
        $Amount
    )
    [Int64]($Amount * 1000000000000)
}

function ConvertFrom-Xr{
    param(
        [Parameter(Mandatory=$true)]
        $Amount
    )
    [Decimal]::round([Decimal]$Amount / 1000000000000,12)
}


function Get-LiquidityRequirements{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("CatCoin","XCH")]
        $InputType,
        [Parameter(Mandatory=$true)]
        $Amount,
        [Parameter(Mandatory=$true)]
        $Config
    )

    if($InputType -eq "CatCoin"){
        $Data = Get-LiquidityFromCatCoin -CatCoinAmount $Amount -Config $Config
    }
    if($InputType -eq "XCH"){
        $Data = Get-LiquidityFromXch -XchAmount $Amount -Config $Config
    }

    [PSCustomObject]@{
        XchRequired = (ConvertFrom-Xr -Amount $Data.Xr)   
        CatCoinRequired = [Decimal]::round((ConvertFrom-Yr -Amount $Data.Yr),3)
    } | Format-List

}
function Get-LiquidityFromCatCoin{
    <#
    .SYNOPSIS
        Uses the UniSwapV3 formula to figure out what the liquidiy is for the giving config by giving the starting Stable Coin amount in USD.
    .DESCRIPTION
        UniswapV3 formula is (Xv+Xr)(Yv+Yr)=L^2.  The formula is given Yr to determin all other values.
    
    #>
    param(
        [Parameter(Mandatory=$true)]
        $CatCoinAmount,
        [Parameter(Mandatory=$true)]
        $Config
    )

    
    $yr = [Decimal](ConvertTo-Yr -Amount $CatCoinAmount)
    $p = $Config.StartingPrice
    $pb = $Config.UpperPrice
    $pa = $Config.LowerPrice
    $sq_p = [Decimal]::round([math]::sqrt([Decimal]$p),14)
    $sq_pb = [Decimal]::round([math]::sqrt([Decimal]$pb),14)
    $sq_pa = [Decimal]::round([math]::sqrt([Decimal]$pa),14)

    $sq_p
    $sq_pa
    $sq_pb

    $l = $yr/($sq_p-$sq_pa)
    $l2 = [int128]([math]::pow($l,2))
    
    # Virtual Liquidity for Y for Delta Y (yv)
    $yv = [int128]($l*$sq_pa)
    
    # Virtual Liquidity for X for Delta Y (xv)
    $xv = [int128]($l / $sq_pb)
    
    # Real Reserves needed for X in Delta Y (xr)
    $xr = ($l2 / ($yv+$yr))-$xv

    

    $data = [ordered]@{
        p=$p
        pa=$pa
        pb=$pb
        xr=$xr
        xv=$xv
        yr=$yr
        yv=$yv
        l=$l
        l2=$l2

    }

    $data
}

Function Get-LiquidityFromXch{
    param(
        [Parameter(Mandatory=$true)]
        $XchAmount,
        [Parameter(Mandatory=$true)]
        $Config
    )

    $xr = [Decimal](Convert-XchToMojos -XchAmount $XchAmount)
    $p = $Config.StartingPrice
    $pb = $Config.UpperPrice
    $pa = $Config.LowerPrice 
    $sq_p = [Decimal]::round([math]::sqrt($p),14)
    $sq_pb = [Decimal]::round([math]::sqrt($pb),14)
    $sq_pa = [Decimal]::round([math]::sqrt($pa),14)


    $l = $xr / ((1/$sq_p)-(1/$sq_pb))
    $l2 = [int128]([math]::pow($l,2))
    
    # Virtual Liquidity for Y for Delta Y (yv)
    $yv = [int128]($l*$sq_pa)
    
    # Virtual Liquidity for X for Delta Y (xv)
    $xv = [int128]($l / $sq_pb)
    
    $yr = (($l2/($xv+$xr))-$yv)

    $data = [ordered]@{
        p=$p
        pa=$pa
        pb=$pb
        xr=$xr
        xv=$xv
        yr=$yr
        yv=$yv
        l=$l
        l2=$l2

    }

    return $data
}


Function Build-TickTable{
    param(
        [Parameter(Mandatory=$true)]
        $Config
    )
    $Decimals = 1000000000000
    $Liquidity = $Config.Liquidity

    $l2 = $Liquidity.l2
    $xv = $Liquidity.xv
    $yv = $Liquidity.yv
    $num_steps=$Config.Steps
    $max_xch = ([decimal](($Liquidity.l2/($Liquidity.yv))-$Liquidity.xv))
    $max_usd = ([decimal](($Liquidity.l2/($Liquidity.xv))-$Liquidity.yv))

    $max_step_size = [math]::floor($max_xch / $num_steps)

    $xr = 0
    $loop = 0
    [decimal]$yr = $max_usd

    $quotes = @()

    while(($xr+$max_step_size) -lt $max_xch){
        $loop ++
        $start_xr = $xr
        $new_xr = $start_xr + $max_step_size
        $starting_yr = $yr
        [decimal]$new_yr = (($l2/($xv+$new_xr))-($yv))
        
        $row = [PSCustomObject]@{
            loop = $loop
            start = $xr
            yr=$yr
            newyr=$new_yr
            xch_amount = $max_step_size
            usd_amount = ([decimal]::round(($yr - $new_yr)/$decimals,3))
            fee_amount = ([decimal]::round((($yr - $new_yr)/$decimals)*$fee_percent,3))
            
        }
        $quotes += $row
        $yr = $new_yr 
        $xr = $new_xr
        
    }

    return $quotes
}

Function Build-QuotesforCurrentXCH{
    param(
        [Parameter(Mandatory=$true)]
        $CurrentXch,
        [Parameter(Mandatory=$true)]
        $Table,
        [int16]$QuoteDepth
    )
    if(-not $QuoteDepth){
        $QuoteDepth = 10
    } 
    $Decimals = 1000000000000
    $sell_table = $Table | Where-Object {$_.start -lt $CurrentXch} | Sort-Object {$_.start} -Descending | Select-Object -First $QuoteDepth
    $buy_table = $Table | Where-Object {$_.start -gt $CurrentXch} | Sort-Object {$_.loop} | Select-Object -First $QuoteDepth

    
    $quotes = @()

    foreach($sell in $sell_table){
        $offered_amount = (($sell.xch_amount-($sell.usd_amount*1000))/$decimals)
        $quote = [pscustomobject]@{
            type = 'sell'
            amm_offered_amount = $sell.usd_amount
            fee = $sell.fee_amount
            offered_amount = $offered_amount
            requested_amount = ($sell.usd_amount+$sell.fee_amount) 
            amm_price_per_xch = [decimal]::round(($sell.usd_amount/($sell.xch_amount/$decimals)),3)
            final_price_per_xch = [decimal]::round((($sell.usd_amount+$sell.fee_amount) / $offered_amount),3)
        }
        $quotes += $quote
    }
    
    foreach($buy in $buy_table){

        $requested_amount = (($buy.xch_amount+($buy.usd_amount*1000))/$decimals)

        $quote = [pscustomobject]@{
            type = 'buy'
            amm_offered_amount = $buy.usd_amount
            fee = $buy.fee_amount
            offered_amount = ($buy.usd_amount - $buy.fee_amount)
            requested_amount = $requested_amount
            amm_price_per_xch = [decimal]::round(($buy.usd_amount / ($buy.xch_amount/$decimals)),3)
            final_price_per_xch = [decimal]::round((($buy.usd_amount - $buy.fee_amount) / $requested_amount),3)
        }
        $quotes += $quote
    }
    
    $quotes

    
}


function Start-TradingBot{
    param(
        [Parameter(Mandatory=$true)]
        $Config,
        [int16]$QuoteDepth
    )
    if(-not $QuoteDepth){
        $QuoteDepth = 10
    } 
    $xch_wallet_id = 1   # default wallet id for xch
    $usd_wallet_id = Convert-AssetIdToWalletId -AssetId $Config.CatCoinAssetId   # my wallet id for wUSDC.b
    $decimals = 1000000000000
    #asset id for CatCoin used - fa4a180ac326e67ea289b869e3448256f6af05721f7cf934cb9901baa6b7a99d is for wUSDC.b
    $cat_name = 'wusdcb'
    $cat_tail = $Config.CatCoinAssetId
    
    $Table = Build-TickTable -Config $Config
    while($true){
        $CurrentXch = Get-XCHBallance
        Write-Host "Current XCH Ballance: $CurrentXch"
        $Quotes = Build-QuotesforCurrentXCH -CurrentXch $CurrentXch -Table $Table -QuoteDepth $QuoteDepth
        New-OffersFromQuotes -Quotes $Quotes
        Start-Sleep 60
    }
}

# Editable Area
# ---------------------------------

$upper_price = 15.5
$lower_price = 12.5
$current_price = 13.549
$fee_percent = 0.007


$starting_xch = 21984425723630
$starting_usd = 180.828

# Wallet ID section
$xch_wallet_id = 1   # default wallet id for xch
$usd_wallet_id = 4   # my wallet id for wUSDC.b

#asset id for CatCoin used - fa4a180ac326e67ea289b869e3448256f6af05721f7cf934cb9901baa6b7a99d is for wUSDC.b
$cat_name = 'wusdcb'
$cat_tail = 'fa4a180ac326e67ea289b869e3448256f6af05721f7cf934cb9901baa6b7a99d'









function Get-XCHBallance{
    $json = @{
        wallet_id = $xch_wallet_id 
    } | ConvertTo-Json
    $starting_xch = (chia rpc wallet get_wallet_balance $json | Convertfrom-json).wallet_balance.confirmed_wallet_balance
    return $starting_xch
}

Class ChiaOffer{
    [hashtable]$offer
    $coins
    $fee
    $offertext
    $json
    $dexie_response
    $dexie_url 
    $requested_nft_data
    $nft_info
    $max_height
    $max_time
    $validate_only

    ChiaOffer(){
        $this.max_height = 0
        $this.max_time = 0
        $this.fee = 0
        $this.offer = @{}
        $this.validate_only = $false
        $this.dexie_url = "https://dexie.space/v1/offers"
    }

    setTestNet(){
        $this.dexie_url = "https://api-testnet.dexie.space/v1/offers"
    }

    offerednft($nft_id){
        $this.offer.($this.nft_info.launcher_id.substring(2))=-1
    }

    offerednftmg($nft_id){
    
        $uri = -join('https://api.mintgarden.io/nfts/',$nft_id)
        $data = Invoke-RestMethod -Method Get -Uri $uri
        $this.offer.($data.id)=-1
    }

    requestednft($nft_id){
        $this.RPCNFTInfo($nft_id)
        $this.offer.($this.nft_info.launcher_id.substring(2))=1
        $this.BuildDriverDict($this.nft_info)
    }

    requested($wallet_id, $amount){
        $this.offer."$wallet_id"=($amount*1000)
    }

    addBlocks($num){
        $this.max_height = (((chia rpc full_node get_blockchain_state) | convertfrom-json).blockchain_state.peak.height) + $num
    }

    setMaxHeight($num){
        $this.max_height = $num
    }
    

    addTimeInMinutes($min){
        $DateTime = (Get-Date).ToUniversalTime()
        $DateTime = $DateTime.AddMinutes($min)
        $this.max_time = [System.Math]::Truncate((Get-Date -Date $DateTime -UFormat %s))
    }

    requestxch($amount){
        
        $this.offer."1"=([int64]($amount*1000000000000))
        
    }
 

    offerxch($amount){
        
        $this.offer."1"=([int64]($amount*-1000000000000))
        
    }

    offered($wallet_id, $amount){
        $this.offer."$wallet_id"=([int64]($amount*-1000))
    }

    validateonly(){
        $this.validate_only = $true
    }
    
    makejson(){
        if($this.max_time -ne 0){
            $this.json = (
                [ordered]@{
                    "offer"=($this.offer)
                    "fee"=$this.fee
                    "validate_only"=$this.validate_only
                    "reuse_puzhash"=$true
                    "driver_dict"=$this.requested_nft_data
                    "max_time"=$this.max_time
                } | convertto-json -Depth 11)        
        } elseif($this.max_height -ne 0){
            $this.json = (
                [ordered]@{
                    "offer"=($this.offer)
                    "fee"=$this.fee
                    "validate_only"=$this.validate_only
                    "reuse_puzhash"=$true
                    "driver_dict"=$this.requested_nft_data
                    "max_height"=$this.max_height
                } | convertto-json -Depth 11)        
        } else {
            $this.json = (
                [ordered]@{
                    "offer"=($this.offer)
                    "fee"=$this.fee
                    "validate_only"=$this.validate_only
                    "reuse_puzhash"=$true
                    "driver_dict"=$this.requested_nft_data
                } | convertto-json -Depth 11)     
        } 
    } 
    


    createoffer(){
        $this.makejson()
        try{
            $this.offertext = chia rpc wallet create_offer_for_ids $this.json
        } catch {
            Write-Error "Unable to create offer"
        }
        
    }

    createofferwithoutjson(){
        $this.offertext = chia rpc wallet create_offer_for_ids $this.json
    }
    
    postToDexie(){
        if($this.offertext){
            $data = $this.offertext | convertfrom-json
            $body = @{
                "offer" = $data.offer
                "claim_rewards" = $true
            }
            $contentType = 'application/json' 
            $json_offer = $body | convertto-json
            $this.dexie_response = Invoke-WebRequest -Method POST -body $json_offer -Uri $this.dexie_url -ContentType $contentType
        } else {
            Write-Error "No offer available to post to dexie."
        }
        
    }
    

    RPCNFTInfo($nft_id){
        $this.nft_info = (chia rpc wallet nft_get_info ([ordered]@{coin_id=$nft_id} | ConvertTo-Json) | Convertfrom-json).nft_info
    }

    BuildDriverDict($data){
    
        $this.requested_nft_data = [ordered]@{($data.launcher_id.substring(2))=[ordered]@{
                    type='singleton';
                    launcher_id=$data.launcher_id;
                    launcher_ph=$data.launcher_puzhash;
                    also=[ordered]@{
                        type='metadata';
                        metadata=$data.chain_info;
                        updater_hash=$data.updater_puzhash;
                        also=[ordered]@{
                            type='ownership';
                            owner=$data.owner_did;
                            transfer_program=[ordered]@{
                                type='royalty transfer program';
                                launcher_id=$data.launcher_id;
                                royalty_address=$data.royalty_puzzle_hash;
                                royalty_percentage=[string]$data.royalty_percentage
                            }
                        }
                    }
                }
            }
        
    }

}

Function New-OfferFromQuote{
    param(
        $quote
    )
    
    $offer = [ChiaOffer]::new()

    if($quote.type -eq 'buy'){
        $offer.offered($usd_wallet_id,$quote.offered_amount)
        $offer.requestxch($quote.requested_amount)
    }

    if($quote.type -eq 'sell'){
        $offer.offerxch($quote.offered_amount)
        $offer.requested($usd_wallet_id,$quote.requested_amount)
    }

    $offer.createoffer()
    
    $offer.postToDexie()
    
    return $offer

}

Function Show-OfferDetails{
    param(
        $trading_data
    )
    

    if($trading_data.summary.requested.($cat_tail)){
        $requested_coin = $cat_name
        $requested_amount = $trading_data.summary.requested.($cat_tail) / 1000
        $offered_coin = 'xch'
        $offered_amount = $trading_data.summary.offered.xch / 1000000000000
        $trade_id = $trading_data.trade_id
    }

    if($trading_data.summary.requested.xch){
        $requested_coin = 'xch'
        $requested_amount = $trading_data.summary.requested.xch / 1000000000000
        $offered_coin = $cat_name
        $offered_amount = $trading_data.summary.offered.($cat_tail) / 1000
        $trade_id = $trading_data.trade_id
    }



    return  [pscustomobject]@{
        requested_coin = $requested_coin
        requested_amount = $requested_amount
        offered_coin = $offered_coin
        offered_amount = $offered_amount
        trade_id = $trade_id
    }

}




Function Get-AllOffers{
    $Json = @{
        start=0
        end=500
    } | ConvertTo-Json
    $Offers = (chia rpc wallet get_all_offers $Json | convertfrom-json).trade_records
    $Result = @()
    foreach($Offer in $Offers){
        $Result += Show-OfferDetails -trading_data $Offer
    }

    $Result
}



function New-OffersFromQuotes{
    param(
        $Quotes
    )

    $CurrentOffers = Get-AllOffers

    foreach($Quote in $Quotes){
        if($Quote.type -eq "buy"){
            if(-not ($CurrentOffers | Where-Object {$_.offered_amount -eq $Quote.offered_amount})){
                Write-Host "Buying for $($Quote.offered_amount)"
                New-OfferFromQuote -quote $Quote
            }
        }
        if($quote.type -eq "sell"){
            if(-not ($CurrentOffers | Where-Object {$_.requested_amount -eq $Quote.requested_amount}) ){
                Write-Host "Selling for $($Quote.requested_amount)"
                New-OfferFromQuote -quote $Quote
            }
        }
    }
    
}

function Reset-Offers{
    $Offers = Get-AllOffers
    foreach($Offer in $Offers){
        $Json = @{
            trade_id = $Offer.trade_id
            fee = 0
        } | ConvertTo-Json
        (chia rpc wallet cancel_offer $json) | ConvertFrom-Json
    }
}



#$trading_data = Build-TradingGraphFromXCH -starting_xch $starting_xch -current_price $current_price -upper_price $upper_price -lower_price $lower_price


#$table = Build-TickTable -num_steps 100 -trading_data $trading_data
#$current_xch = Get-XCHBallance
#$quotes = Build-QuotesforCurrentXCH -current_xch $current_xch -table $table


new-ChiaSwapConfig -UpperPrice 14.15 -LowerPrice 12.621 -StartingPrice 13.15 -FeePercent 0.006 -CatCoin wUSDC.b -Steps 157 -Force -StartingCatCoin 743.536
#$config = Get-ChiaSwapConfig
#Get-LiquidityRequirements -InputType CatCoin -Amount 743.536 -Config $Config
#$table = Build-TickTable -Config $Config
#$quotes = Build-QuotesforCurrentXCH -CurrentXch (Get-XCHBallance) -Table $table -QuoteDepth 20
#$quotes | ft
#Get-LiquidityRequirements -InputType CatCoin -Amount 743.536 -Config $Config