#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'Sources/CLIBSTool'

try {
    $manifestPath = Join-Path $root 'build-info.json'
    if (!(Test-Path -LiteralPath $manifestPath)) {
        throw 'Missing build-info.json. Run Utils/UpdateTool.ps1 first.'
    }
    $info = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($info.schemaVersion -ne 1) { throw 'Unsupported build-info.json format.' }
    $exe = Join-Path $root 'CLIBSTool.exe'
    if (!(Test-Path -LiteralPath $exe)) { throw 'CLIBSTool.exe is missing.' }
    if ((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne $info.sha256) {
        throw 'CLIBSTool.exe does not match its recorded SHA256 hash.'
    }

    # Read the gitlink without requiring the submodule to be initialized.
    $entry = & git -C $root ls-files --stage -- Sources/CLIBSTool
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the submodule gitlink.' }
    if ($entry -notmatch '^160000 ([0-9a-f]{40,64}) 0\s') {
        throw 'Sources/CLIBSTool must be a submodule without merge conflicts.'
    }
    $pinnedCommit = $Matches[1]
    if ($info.commit -ne $pinnedCommit) {
        throw 'The executable does not match the staged submodule commit. Rebuild or stage the updated submodule.'
    }
    if (Test-Path -LiteralPath (Join-Path $source '.git')) {
        $headCommit = & git -C $source rev-parse HEAD
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read submodule HEAD.' }
        if ($info.commit -ne $headCommit) { throw 'The executable is older than or different from the checked-out submodule. Run UpdateTool.ps1.' }
        $dirty = & git -C $source status --porcelain --untracked-files=all
        if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect submodule changes.' }
        if ($dirty) { throw 'The submodule has uncommitted changes.' }
    }
    Write-Host "OK: CLIBSTool.exe matches submodule commit $($info.commit) and its SHA256 hash."
    exit 0
}
catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
