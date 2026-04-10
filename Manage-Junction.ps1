<#
.SYNOPSIS
Creates or removes a junction for the TRP3_CaughtULookin directory.

.DESCRIPTION
This script manages a filesystem junction for the TRP3_CaughtULookin folder.
If run without arguments, it prints usage instructions.

.PARAMETER Action
The requested action: add or remove.

.PARAMETER Target
The destination path for the junction.
If Target is an existing directory, the junction is created inside it using the source folder name.
If Target is a path that does not exist, the script creates a junction at that exact path.

.EXAMPLE
.",\"Manage-Junction.ps1\" -Action add -Target "C:\Games\World of Warcraft\_retail_\Interface\AddOns"

.EXAMPLE
.",\"Manage-Junction.ps1\" -Action remove -Target "C:\Games\World of Warcraft\_retail_\Interface\AddOns\TRP3_CaughtULookin"
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('add', 'remove')]
    [string]$Action,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$Target
)

function Show-Usage {
    Write-Host "Usage: .\Manage-Junction.ps1 -Action <add|remove> -Target <path>"
    Write-Host "       .\Manage-Junction.ps1 add <directory|linkPath>"
    Write-Host "       .\Manage-Junction.ps1 remove <linkPath>"
    Write-Host ''
    Write-Host "Examples:"
    Write-Host "  .\Manage-Junction.ps1 add 'C:\Games\World of Warcraft\_retail_\Interface\AddOns'"
    Write-Host "  .\Manage-Junction.ps1 remove 'C:\Games\World of Warcraft\_retail_\Interface\AddOns\TRP3_CaughtULookin'"
    Write-Host ''
    Write-Host "The source folder is the child folder matching this script folder name if present, otherwise $PSScriptRoot"
}

function Resolve-LinkPath {
    param(
        [string]$Destination
    )

    if (-not $Destination) {
        throw 'Target path is required.'
    }

    $destinationPath = Resolve-Path -Path $Destination -ErrorAction SilentlyContinue
    if ($destinationPath) {
        $destinationPath = $destinationPath.Path
        if ((Get-Item -LiteralPath $destinationPath).PSIsContainer) {
            return Join-Path -Path $destinationPath -ChildPath (Split-Path -Leaf $PSScriptRoot)
        }
    }

    $parentPath = Split-Path -Parent $Destination
    if (-not $parentPath) {
        throw "Cannot determine parent directory for target path: $Destination"
    }

    if (-not (Test-Path -LiteralPath $parentPath)) {
        throw "Parent directory does not exist: $parentPath"
    }

    return $Destination
}

function Get-SourcePath {
    $rootName = Split-Path -Leaf $PSScriptRoot
    $nestedSource = Join-Path -Path $PSScriptRoot -ChildPath $rootName

    if (Test-Path -LiteralPath $nestedSource -PathType Container) {
        return $nestedSource
    }

    return $PSScriptRoot
}

function Is-Junction($path) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    return $item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

function Add-Junction($linkPath, $targetPath) {
    if (Test-Path -LiteralPath $linkPath) {
        if (Is-Junction $linkPath) {
            Write-Host "Junction already exists: $linkPath"
            return
        }
        throw "A file or directory already exists at the junction path: $linkPath"
    }

    New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null
    Write-Host "Created junction: $linkPath -> $targetPath"
}

function Remove-Junction($linkPath) {
    if (-not (Test-Path -LiteralPath $linkPath)) {
        Write-Host "No junction or directory exists at: $linkPath"
        return
    }

    if (-not (Is-Junction $linkPath)) {
        throw "Target path exists but is not a junction: $linkPath"
    }

    Remove-Item -LiteralPath $linkPath -Force
    Write-Host "Removed junction: $linkPath"
}

if (-not $Action -or -not $Target) {
    Show-Usage
    return
}

$sourcePath = Get-SourcePath
$linkPath = Resolve-LinkPath -Destination $Target

try {
    switch ($Action) {
        'add' {
            Add-Junction -linkPath $linkPath -targetPath $sourcePath
        }
        'remove' {
            Remove-Junction -linkPath $linkPath
        }
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
