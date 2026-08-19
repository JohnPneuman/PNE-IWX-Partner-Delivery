[CmdletBinding()]
param(
    [string] $RepositoryRoot,
    [switch] $SkipSetupCheck
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-AlProjects {
    param([string] $Root)

    $appsPath = Join-Path $Root 'apps'
    if (Test-Path -LiteralPath $appsPath -PathType Container) {
        return @(Get-ChildItem -LiteralPath $appsPath -Directory | Where-Object {
                Test-Path -LiteralPath (Join-Path $_.FullName 'app.json') -PathType Leaf
            })
    }

    return @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object {
            Test-Path -LiteralPath (Join-Path $_.FullName 'app.json') -PathType Leaf
        })
}

function Find-AlExtension {
    $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    if ($null -eq $codeCommand) {
        throw 'VS Code CLI was not found. Install Visual Studio Code and the official ms-dynamics-smb.al extension.'
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $locationOutput = @(& $codeCommand.Source --locate-extension ms-dynamics-smb.al 2>$null)
    $ErrorActionPreference = $previousErrorActionPreference
    $extensionPath = ($locationOutput | Where-Object {
            $_ -and (Test-Path -LiteralPath $_ -PathType Container)
        } | Select-Object -Last 1)
    if ([string]::IsNullOrWhiteSpace([string] $extensionPath)) {
        throw 'The official ms-dynamics-smb.al extension was not found.'
    }

    return $extensionPath
}

function Find-AlCompiler {
    param([string] $ExtensionPath)

    $compilerCandidates = @(
        (Join-Path $ExtensionPath 'bin\win32\alc.exe'),
        (Join-Path $ExtensionPath 'bin\linux\alc'),
        (Join-Path $ExtensionPath 'bin\darwin\alc')
    )
    $compilerPath = ($compilerCandidates | Where-Object {
            Test-Path -LiteralPath $_ -PathType Leaf
        } | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace([string] $compilerPath)) {
        throw 'The AL compiler was not found in the installed AL Language extension.'
    }

    return $compilerPath
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if (-not $SkipSetupCheck) {
    & (Join-Path $scriptDirectory 'Test-AlDevelopmentEnvironment.ps1') -RepositoryRoot $resolvedRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'The AL setup check failed. Resolve the reported prerequisites before validation.'
    }
}

$extensionPath = Find-AlExtension
$compilerPath = Find-AlCompiler -ExtensionPath $extensionPath
$analyzerDirectory = Join-Path $extensionPath 'bin\Analyzers'
$analyzers = @(
    (Join-Path $analyzerDirectory 'Microsoft.Dynamics.Nav.CodeCop.dll'),
    (Join-Path $analyzerDirectory 'Microsoft.Dynamics.Nav.UICop.dll'),
    (Join-Path $analyzerDirectory 'Microsoft.Dynamics.Nav.PerTenantExtensionCop.dll')
) -join ','

$projects = @(Get-AlProjects -Root $resolvedRoot)
$failedProjects = 0

foreach ($project in $projects) {
    $manifest = Get-Content -LiteralPath (Join-Path $project.FullName 'app.json') -Raw | ConvertFrom-Json
    $settings = Get-Content -LiteralPath (Join-Path $project.FullName '.vscode\settings.json') -Raw | ConvertFrom-Json
    $packageCachePath = (Resolve-Path -LiteralPath (Join-Path $project.FullName ([string] $settings.'al.packageCachePath'))).Path
    $rulesetPath = (Resolve-Path -LiteralPath (Join-Path $project.FullName ([string] $settings.'al.ruleSetPath'))).Path
    $outputDirectory = Join-Path $project.FullName '.build'
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force

    $safeName = ([string] $manifest.name) -replace '[^A-Za-z0-9._-]', '-'
    $outputPath = Join-Path $outputDirectory ("{0}-{1}.app" -f $safeName, $manifest.version)
    $diagnosticsPath = Join-Path $outputDirectory 'validation-diagnostics.json'
    $compilerArguments = @(
        "/project:$($project.FullName)",
        "/packagecachepath:$packageCachePath",
        "/analyzer:$analyzers",
        "/ruleset:$rulesetPath",
        '/warnaserror+',
        "/out:$outputPath",
        "/errorlog:$diagnosticsPath",
        '/reportsuppresseddiagnostics',
        '/parallel+'
    )

    Write-Host ''
    Write-Host "Validating $($manifest.name) $($manifest.version)"
    & $compilerPath @compilerArguments
    $compilerExitCode = $LASTEXITCODE
    $projectFailed = $compilerExitCode -ne 0

    if (Test-Path -LiteralPath $diagnosticsPath -PathType Leaf) {
        try {
            $diagnostics = Get-Content -LiteralPath $diagnosticsPath -Raw | ConvertFrom-Json
            $issues = @($diagnostics.issues)
            $errors = @($issues | Where-Object { $_.properties.severity -eq 'Error' }).Count
            $warnings = @($issues | Where-Object { $_.properties.severity -eq 'Warning' }).Count
            $information = @($issues | Where-Object { $_.properties.severity -eq 'Info' }).Count
            Write-Host "Diagnostics: $errors error(s), $warnings warning(s), $information info message(s)."
        }
        catch {
            Write-Host "[FAIL] Diagnostics log is not valid JSON: $($_.Exception.Message)"
            Write-Host "Compiler exit code: $compilerExitCode."
            $projectFailed = $true
        }
    }
    else {
        Write-Host "[FAIL] Diagnostics log was not created: $diagnosticsPath."
        Write-Host "Compiler exit code: $compilerExitCode."
        $projectFailed = $true
    }

    if ($projectFailed) {
        $failedProjects++
        Write-Host "[FAIL] Validation failed for $($manifest.name)."
    }
}

if ($failedProjects -gt 0) {
    throw "$failedProjects AL project(s) failed validation."
}

Write-Host ''
Write-Host "Validation succeeded for $($projects.Count) PTE app(s) with CodeCop, UICop, PerTenantExtensionCop, and warnings as errors."
