# Tool utilities

To run `CLIBSTool.exe`, install [.NET 8 Runtime](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) (choose **.NET Runtime → Windows → x64**). Run the tool from the repository root.

To rebuild, install Git and the .NET 8 SDK or newer, then run from the repository root:

```powershell
git submodule update --init --recursive
.\Utils\UpdateTool.ps1
git add Sources/CLIBSTool CLIBSTool.exe build-info.json
.\Utils\CheckTool.ps1
```

`UpdateTool.ps1` builds the current clean submodule commit. `CheckTool.ps1` verifies the commit and executable hash. Commit the submodule, executable and `build-info.json` together.

Optional Linux x64 build (PowerShell, also works from Windows):

```powershell
pwsh -File ./Utils/BuildLinux.ps1
```

Produces a self-contained single executable at `CLIBSTool` in the repository root, ignored by Git. No .NET runtime installation is needed. On Linux, make it executable with `chmod +x CLIBSTool` and run it from the repository root. Linux execution has not been tested; image/font operations use `System.Drawing.Common` and may need native dependencies such as `libgdiplus`.
