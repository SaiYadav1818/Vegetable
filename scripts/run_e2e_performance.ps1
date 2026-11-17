<#
.SYNOPSIS
FreshBasket End-to-End Performance & Concurrency Verification Script
.DESCRIPTION
Runs the automated end-to-end performance benchmarks, testing store settings, catalog throughput,
checkout concurrency, and measuring response latency percentiles.
#>
param(
    [string]$BaseUrl = "http://localhost:8080",
    [int]$Concurrency = 30
)

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " FreshBasket End-to-End Performance Runner" -ForegroundColor Green
Write-Host " Target URL: $BaseUrl" -ForegroundColor Cyan
Write-Host " Concurrency Level: $Concurrency" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green

python scripts/performance_e2e_runner.py $BaseUrl
