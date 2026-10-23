# Sends the `stock:` numbers from index.html to Snipcart.
#
# Run it when you add Live paintings or restock - NOT after every change to the site.
# It REPLACES the count in Snipcart, so sales Snipcart already counted down would be undone
# if index.html still has the old number. The script shows old -> new and asks before changing anything.
#
# Usage (from the project folder):
#   powershell -ExecutionPolicy Bypass -File stock-worker\set-stock.ps1            # all products with stock:
#   powershell -ExecutionPolicy Bypass -File stock-worker\set-stock.ps1 -Ids 18,21 # only some
#   powershell -ExecutionPolicy Bypass -File stock-worker\set-stock.ps1 -DryRun    # just show what would be sent
#
# Needs "Inventory management" switched ON in Snipcart (Store configurations).

param(
  [string]$Ids,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$api = 'https://app.snipcart.com/api/products'
$productsUrl = 'https://srtortilla.art/products.json'

# 1. Read products that have a stock number from index.html
$html = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\index.html'))
$rx = [regex]"\{ id: (\d+),[^}]*?stock: (\d+),[^}]*?name: '([^']*)'"
$wanted = foreach ($m in $rx.Matches($html)) {
  [pscustomobject]@{ Id = [int]$m.Groups[1].Value; Stock = [int]$m.Groups[2].Value; Name = $m.Groups[3].Value }
}
if ($Ids) {
  $only = $Ids -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ }
  $wanted = $wanted | Where-Object { $only -contains $_.Id }
}
if (-not $wanted) { Write-Host 'No products with a stock number found.'; exit 1 }

if ($DryRun) {
  Write-Host 'Would set:'
  $wanted | ForEach-Object { Write-Host ("  {0,3}  {1,-25} stock {2}" -f $_.Id, $_.Name, $_.Stock) }
  exit 0
}

# 2. Secret key: typed in each time, never saved
$secure = Read-Host 'Paste your Snipcart SECRET API key' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
$headers = @{
  Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${key}:"))
  Accept        = 'application/json'
}

# 3. Make sure Snipcart knows every product (imports names/prices from products.json)
Write-Host "Importing products from $productsUrl ..."
Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json' `
  -Body (@{ fetchUrl = $productsUrl } | ConvertTo-Json) | Out-Null

# 4. Show current -> new and confirm
Write-Host ''
foreach ($p in $wanted) {
  try {
    $current = Invoke-RestMethod -Method Get -Uri "$api/$($p.Id)" -Headers $headers
    $p | Add-Member Current $(if ($null -ne $current.stock) { $current.stock } else { 'not set' })
  } catch {
    $p | Add-Member Current 'not found'
  }
  Write-Host ("  {0,3}  {1,-25} {2,8} -> {3}" -f $p.Id, $p.Name, $p.Current, $p.Stock)
}
Write-Host ''
if ((Read-Host 'Apply these stock numbers? (y/n)') -ne 'y') { Write-Host 'Nothing changed.'; exit 0 }

# 5. Update
foreach ($p in $wanted) {
  $body = @{ inventoryManagementMethod = 'Single'; stock = $p.Stock; allowOutOfStockPurchases = $false } | ConvertTo-Json
  try {
    Invoke-RestMethod -Method Put -Uri "$api/$($p.Id)" -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
    Write-Host "  OK      $($p.Id) $($p.Name): $($p.Stock)"
  } catch {
    Write-Host "  FAILED  $($p.Id) $($p.Name): $($_.Exception.Message)"
  }
}
