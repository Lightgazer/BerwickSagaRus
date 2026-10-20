#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'Sources/CLIBSTool'
$output = $root
$temporary = $null

function Get-CleanCommit {
    $commit = & git -C $source rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read submodule HEAD.' }
    $dirty = & git -C $source status --porcelain --untracked-files=all
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect submodule changes.' }
    if ($dirty) { throw 'Commit or stash submodule changes before building.' }
    return $commit
}

try {
    if (!(Test-Path -LiteralPath (Join-Path $source '.git'))) {
        throw 'Initialize the submodule first: git submodule update --init --recursive'
    }
    $commit = Get-CleanCommit
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('CLIBSTool-linux-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporary | Out-Null
    $publish = Join-Path $temporary 'publish'
    & dotnet publish (Join-Path $source 'CLIBSTool.csproj') `
        --configuration Release --runtime linux-x64 --self-contained true `
        --output $publish --artifacts-path (Join-Path $temporary 'artifacts') `
        -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:DebugType=None -p:DebugSymbols=false -p:ContinuousIntegrationBuild=true `
        "-p:SourceRevisionId=$commit"
    if ($LASTEXITCODE -ne 0) { throw 'Linux publish failed; the previous output has not been replaced.' }
    if ((Get-CleanCommit) -ne $commit) { throw 'The submodule changed during the build. Run the build again.' }
    $binary = Join-Path $publish 'CLIBSTool'
    if (!(Test-Path -LiteralPath $binary)) { throw 'Publish did not produce CLIBSTool.' }
    $extra = @(Get-ChildItem -LiteralPath $publish -Force | Where-Object Name -ne 'CLIBSTool')
    if ($extra.Count) { throw 'Expected a single executable; publish produced additional files.' }
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    Copy-Item -LiteralPath $binary -Destination (Join-Path $output 'CLIBSTool') -Force
    Write-Host "Built Linux x64 executable from $commit at $output/CLIBSTool."
    Write-Host 'On Linux, run from the repository root: chmod +x CLIBSTool; ./CLIBSTool Help'
}
catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
finally {
    if ($temporary -and (Test-Path -LiteralPath $temporary)) {
        $resolved = [IO.Path]::GetFullPath($temporary)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
        if ((Split-Path -Parent $resolved) -eq $tempRoot -and
            (Split-Path -Leaf $resolved) -match '^CLIBSTool-linux-[0-9a-f]{32}$') {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
