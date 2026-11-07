$ErrorActionPreference = 'Stop'

Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force build | Out-Null

    $sources = @(
        'rtl/message_parser.sv'
        'rtl/order_store.sv'
        'rtl/order_manager.sv'
        'rtl/bbo_engine.sv'
        'rtl/market_top.sv'
        'tb/tb_market_top.sv'
    )

   & 'iverilog.exe' -g2012 -Wall -s tb_market_top `
    -o build/market_top_test @sources

    if ($LASTEXITCODE -ne 0) {
        throw 'Compilation failed.'
    }

    & 'vvp.exe' build/market_top_test

    if ($LASTEXITCODE -ne 0) {
        throw 'Simulation failed.'
    }

    Write-Host 'Market engine integration tests passed.'
}
finally {
    Pop-Location
}
