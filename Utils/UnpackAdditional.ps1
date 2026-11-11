#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ToolPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'CLIBSTool.exe')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tool = (Resolve-Path -LiteralPath $ToolPath).Path

# Resources already extracted by older versions, but not converted to PNG.
$pictures = @(
    '2962/font1.ar/tex.ttx'
    '2962/font2.ar/tex.ttx'
    '2962/font3.ar/tex.ttx'
    '2962/font4.ar/tex.ttx'
    '2962/font5.ar/tex.ttx'
)

Push-Location $root
try {
    foreach ($picture in $pictures) {
        $inputPath = Join-Path $root "DATA3/$picture"
        $outputPath = Join-Path $root "Pictures/$picture.png"
        if (Test-Path -LiteralPath $outputPath) {
            Write-Host "Skip existing: Pictures/$picture.png"
            continue
        }
        if (!(Test-Path -LiteralPath $inputPath)) {
            Write-Warning "Not extracted: DATA3/$picture"
            continue
        }
        & $tool ConvertImage $inputPath $outputPath
        if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $outputPath)) {
            throw "Conversion failed: $picture. Use a CLIBSTool build with ConvertImage support."
        }
        Write-Host "Created: Pictures/$picture.png"
    }
}
finally {
    Pop-Location
}
