#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'Sources/CLIBSTool'
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
    $entry = & git -C $root ls-files --stage -- Sources/CLIBSTool
    if ($LASTEXITCODE -ne 0 -or $entry -notmatch '^160000 ([0-9a-f]{40,64}) 0\s') {
        throw 'Sources/CLIBSTool must be a submodule without merge conflicts.'
    }
    $pinnedCommit = $Matches[1]
    $commit = Get-CleanCommit
    $sdk = & dotnet --version
    if ($LASTEXITCODE -ne 0) { throw 'A .NET SDK supporting net8.0 is required.' }
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('CLIBSTool-publish-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporary | Out-Null
    $publish = Join-Path $temporary 'publish'

    # Keep intermediate build files out of the source tree and avoid stale output.
    & dotnet publish (Join-Path $source 'CLIBSTool.csproj') `
        --configuration Release --runtime win-x64 --self-contained false `
        --output $publish --artifacts-path (Join-Path $temporary 'artifacts') `
        -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:DebugType=None -p:DebugSymbols=false -p:ContinuousIntegrationBuild=true `
        "-p:SourceRevisionId=$commit"
    if ($LASTEXITCODE -ne 0) { throw 'Publish failed; the existing executable has not been replaced.' }
    if ((Get-CleanCommit) -ne $commit) { throw 'The submodule changed during the build. Run the update again.' }
    $builtExe = Join-Path $publish 'CLIBSTool.exe'
    if (!(Test-Path -LiteralPath $builtExe)) { throw 'Publish did not produce CLIBSTool.exe.' }
    $extra = @(Get-ChildItem -LiteralPath $publish -Force | Where-Object Name -ne 'CLIBSTool.exe')
    if ($extra.Count) { throw 'Publish produced additional files. Review deployment before replacing the executable.' }

    Push-Location $root
    try {
        & $builtExe Help
        if ($LASTEXITCODE -ne 0) { throw 'The published executable failed its Help smoke test.' }
    }
    finally { Pop-Location }

    $info = [ordered]@{
        schemaVersion = 1
        commit = $commit
        sha256 = (Get-FileHash -LiteralPath $builtExe -Algorithm SHA256).Hash
        sdk = $sdk
        runtime = 'win-x64'
        configuration = 'Release'
        selfContained = $false
        builtAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    $manifest = Join-Path $temporary 'build-info.json'
    $info | ConvertTo-Json | Set-Content -LiteralPath $manifest -Encoding UTF8
    Copy-Item -LiteralPath $builtExe -Destination (Join-Path $root 'CLIBSTool.exe') -Force
    Copy-Item -LiteralPath $manifest -Destination (Join-Path $root 'build-info.json') -Force
    Write-Host "Updated CLIBSTool.exe from $commit."
    if ($pinnedCommit -ne $commit) {
        Write-Host 'Stage Sources/CLIBSTool with the executable and build-info.json before running CheckTool.ps1.'
    }
    Write-Host 'Commit Sources/CLIBSTool, CLIBSTool.exe and build-info.json together.'
}
catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
finally {
    if ($temporary -and (Test-Path -LiteralPath $temporary)) {
        $resolved = [IO.Path]::GetFullPath($temporary)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolved) -match '^CLIBSTool-publish-[0-9a-f]{32}$') {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
