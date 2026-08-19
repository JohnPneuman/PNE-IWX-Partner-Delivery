[CmdletBinding()]
param(
    [string] $RepositoryRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

$script:FailureCount = 0
$script:WarningCount = 0

function Write-CheckResult {
    param(
        [ValidateSet('PASS', 'WARN', 'FAIL', 'INFO')]
        [string] $Status,
        [string] $Message
    )

    if ($Status -eq 'FAIL') {
        $script:FailureCount++
    }
    elseif ($Status -eq 'WARN') {
        $script:WarningCount++
    }

    Write-Host ("[{0}] {1}" -f $Status, $Message)
}

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
        return $null
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $locationOutput = @(& $codeCommand.Source --locate-extension ms-dynamics-smb.al 2>$null)
    $ErrorActionPreference = $previousErrorActionPreference
    return ($locationOutput | Where-Object {
            $_ -and (Test-Path -LiteralPath $_ -PathType Container)
        } | Select-Object -Last 1)
}

function Find-AlCompiler {
    param([string] $ExtensionPath)

    $candidates = @(
        (Join-Path $ExtensionPath 'bin\win32\alc.exe'),
        (Join-Path $ExtensionPath 'bin\linux\alc'),
        (Join-Path $ExtensionPath 'bin\darwin\alc')
    )

    return ($candidates | Where-Object {
            Test-Path -LiteralPath $_ -PathType Leaf
        } | Select-Object -First 1)
}

function Find-AlTool {
    param([string] $ExtensionPath)

    $candidates = @(
        (Join-Path $ExtensionPath 'bin\win32\altool.exe'),
        (Join-Path $ExtensionPath 'bin\linux\altool'),
        (Join-Path $ExtensionPath 'bin\darwin\altool')
    )

    return ($candidates | Where-Object {
            Test-Path -LiteralPath $_ -PathType Leaf
        } | Select-Object -First 1)
}

function Get-SymbolPackageManifests {
    param(
        [string] $PackageCachePath,
        [string] $AlToolPath
    )

    $results = @()
    foreach ($package in @(Get-ChildItem -LiteralPath $PackageCachePath -Filter '*.app' -File)) {
        $manifestOutput = @(& $AlToolPath GetPackageManifest $package.FullName 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-CheckResult FAIL "Cannot read symbol package manifest: $($package.Name)."
            continue
        }

        try {
            $packageManifest = ($manifestOutput -join [Environment]::NewLine) | ConvertFrom-Json
        }
        catch {
            Write-CheckResult FAIL "Invalid package manifest JSON for $($package.Name): $($_.Exception.Message)"
            continue
        }

        $results += [pscustomobject]@{
            File = $package
            Manifest = $packageManifest
        }
    }

    return @($results)
}

function Test-ExactProjectNamespace {
    param(
        [System.IO.DirectoryInfo] $Project,
        [string] $ExpectedNamespace,
        [object] $Settings
    )

    if ([string] $Settings.'al.namespaceTemplate' -cne $ExpectedNamespace) {
        Write-CheckResult FAIL "Expected al.namespaceTemplate=$ExpectedNamespace, found $($Settings.'al.namespaceTemplate')."
        return
    }

    $invalidFiles = @()
    $alFiles = @(Get-ChildItem -LiteralPath $Project.FullName -Recurse -Filter '*.al' -File | Where-Object {
            $_.FullName -notmatch '[\\/](\.alpackages|\.build)[\\/]'
        })
    foreach ($alFile in $alFiles) {
        $source = Get-Content -LiteralPath $alFile.FullName -Raw
        $matches = [regex]::Matches($source, '(?m)^\s*namespace\s+([^;]+);\s*$')
        if (($matches.Count -ne 1) -or ($matches[0].Groups[1].Value.Trim() -cne $ExpectedNamespace)) {
            $invalidFiles += $alFile.FullName.Substring($Project.FullName.Length + 1)
        }
    }

    if ($invalidFiles.Count -eq 0) {
        Write-CheckResult PASS "All $($alFiles.Count) AL files use the approved namespace $ExpectedNamespace."
    }
    else {
        Write-CheckResult FAIL "Files with a missing or incorrect namespace: $($invalidFiles -join ', ')."
    }
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
Write-Host "PNE AL development environment check"
Write-Host "Repository: $resolvedRoot"
Write-Host ''

$workspaceFiles = @(Get-ChildItem -LiteralPath $resolvedRoot -Filter '*.code-workspace' -File)
if ($workspaceFiles.Count -eq 1) {
    Write-CheckResult PASS "Workspace found: $($workspaceFiles[0].Name)"
}
elseif ($workspaceFiles.Count -eq 0) {
    Write-CheckResult FAIL 'No .code-workspace file was found.'
}
else {
    Write-CheckResult WARN 'Multiple .code-workspace files were found; onboarding must identify the authoritative workspace.'
}

$projects = @(Get-AlProjects -Root $resolvedRoot)
$approvedNamespaces = @{
    'PNE.FrameSpecification' = 'Pneuman.FrameSpecification'
    'PNE.ProductConfiguratorEnhancements' = 'Pneuman.ProductConfigurator'
}
$expectedProjectNames = @($approvedNamespaces.Keys | Sort-Object)
$actualProjectNames = @($projects.Name | Sort-Object)
if (($projects.Count -eq 2) -and (($actualProjectNames -join '|') -ceq ($expectedProjectNames -join '|'))) {
    Write-CheckResult PASS 'Found the two expected AL projects.'
}
else {
    Write-CheckResult FAIL "Expected AL projects $($expectedProjectNames -join ', '); found $($actualProjectNames -join ', ')."
}

$extensionPath = Find-AlExtension
$compilerPath = $null
$compilerMajor = $null
$alToolPath = $null
if (-not [string]::IsNullOrWhiteSpace([string] $extensionPath)) {
    $extensionManifestPath = Join-Path $extensionPath 'package.json'
    $extensionManifest = Get-Content -LiteralPath $extensionManifestPath -Raw | ConvertFrom-Json
    Write-CheckResult PASS "Official AL Language extension found: $($extensionManifest.publisher).$($extensionManifest.name) $($extensionManifest.version)."
    $compilerPath = Find-AlCompiler -ExtensionPath $extensionPath
    if (-not [string]::IsNullOrWhiteSpace([string] $compilerPath)) {
        $compilerOutput = @(& $compilerPath '/?' 2>&1)
        $versionLine = @($compilerOutput | Where-Object { $_ -match 'AL Compiler version' } | Select-Object -First 1)
        if ($versionLine.Count -gt 0 -and $versionLine[0] -match 'version\s+(\d+)\.') {
            $compilerMajor = [int] $Matches[1]
        }
        Write-CheckResult PASS "AL compiler found: $compilerPath."
        $alToolPath = Find-AlTool -ExtensionPath $extensionPath
        if (-not [string]::IsNullOrWhiteSpace([string] $alToolPath)) {
            Write-CheckResult PASS "Microsoft AL package-manifest tool found: $alToolPath."
        }
        else {
            Write-CheckResult FAIL 'The installed AL Language extension does not contain altool for package-manifest validation.'
        }
    }
    else {
        Write-CheckResult FAIL 'The installed AL Language extension does not contain a supported AL compiler.'
    }
}
else {
    Write-CheckResult FAIL 'Install the official Microsoft extension ms-dynamics-smb.al; nothing was installed automatically.'
}

$requiredAnalyzers = @('${CodeCop}', '${PerTenantExtensionCop}', '${UICop}') | Sort-Object
foreach ($project in $projects) {
    Write-Host ''
    Write-Host "Project: $($project.Name)"

    $manifestPath = Join-Path $project.FullName 'app.json'
    $settingsPath = Join-Path $project.FullName '.vscode\settings.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

    Write-CheckResult PASS "Manifest $($manifest.name) $($manifest.version), runtime $($manifest.runtime), application $($manifest.application)."
    if ($null -ne $compilerMajor -and [int]($manifest.runtime.Split('.')[0]) -gt $compilerMajor) {
        Write-CheckResult FAIL "Runtime $($manifest.runtime) requires a newer compiler than major version $compilerMajor."
    }

    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        Write-CheckResult FAIL 'Missing .vscode/settings.json.'
        continue
    }

    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    if ($settings.'al.enableCodeAnalysis' -eq $true -and $settings.'al.backgroundCodeAnalysis' -eq 'Project') {
        Write-CheckResult PASS 'Full-project background code analysis is enabled.'
    }
    else {
        Write-CheckResult FAIL 'Set al.enableCodeAnalysis=true and al.backgroundCodeAnalysis=Project.'
    }

    $configuredAnalyzers = @($settings.'al.codeAnalyzers') | Sort-Object
    if (($configuredAnalyzers -join '|') -eq ($requiredAnalyzers -join '|')) {
        Write-CheckResult PASS 'CodeCop, UICop, and PerTenantExtensionCop are configured; AppSourceCop is not enabled.'
    }
    else {
        Write-CheckResult FAIL "Unexpected analyzer set: $($configuredAnalyzers -join ', ')."
    }

    if ($approvedNamespaces.ContainsKey($project.Name)) {
        Test-ExactProjectNamespace -Project $project -ExpectedNamespace $approvedNamespaces[$project.Name] -Settings $settings
    }

    $rulesetSetting = [string] $settings.'al.ruleSetPath'
    $rulesetPath = Join-Path $project.FullName $rulesetSetting
    if (Test-Path -LiteralPath $rulesetPath -PathType Leaf) {
        $null = Get-Content -LiteralPath $rulesetPath -Raw | ConvertFrom-Json
        Write-CheckResult PASS "Ruleset is valid JSON: $rulesetSetting."
    }
    else {
        Write-CheckResult FAIL "Ruleset does not exist: $rulesetSetting."
    }

    $packageCacheSetting = [string] $settings.'al.packageCachePath'
    $packageCachePath = Join-Path $project.FullName $packageCacheSetting
    if (-not (Test-Path -LiteralPath $packageCachePath -PathType Container)) {
        Write-CheckResult FAIL "Symbol cache is missing: $packageCacheSetting. Run AL: Download Symbols for this app."
        continue
    }

    if ([string]::IsNullOrWhiteSpace([string] $alToolPath)) {
        Write-CheckResult FAIL 'Package manifests cannot be validated because altool is unavailable.'
        continue
    }

    $symbolPackages = @(Get-SymbolPackageManifests -PackageCachePath $packageCachePath -AlToolPath $alToolPath)
    foreach ($dependency in @($manifest.dependencies)) {
        $dependencyMatch = @($symbolPackages | Where-Object {
                ([string] $_.Manifest.id -ieq [string] $dependency.id) -and
                ([string] $_.Manifest.publisher -ceq [string] $dependency.publisher) -and
                ([string] $_.Manifest.name -ceq [string] $dependency.name) -and
                ([string] $_.Manifest.version -ceq [string] $dependency.version)
            })
        if ($dependencyMatch.Count -gt 0) {
            Write-CheckResult PASS "Dependency manifest verified: $($dependency.publisher) / $($dependency.name) $($dependency.version) / $($dependency.id)."
        }
        else {
            $sameIdPackages = @($symbolPackages | Where-Object {
                    [string] $_.Manifest.id -ieq [string] $dependency.id
                } | ForEach-Object {
                    "$($_.Manifest.publisher) / $($_.Manifest.name) $($_.Manifest.version)"
                })
            $foundDescription = if ($sameIdPackages.Count -gt 0) {
                " Found the same app ID with: $($sameIdPackages -join ', ')."
            }
            else {
                ''
            }
            Write-CheckResult FAIL "Missing exact dependency manifest: $($dependency.publisher) / $($dependency.name) $($dependency.version) / $($dependency.id).$foundDescription Run AL: Download Symbols for this app."
        }
    }

    $requiredMicrosoftSymbols = @(
        [pscustomobject]@{ Id = '8874ed3a-0643-4247-9ced-7a7002f7135d'; Name = 'System' },
        [pscustomobject]@{ Id = '63ca2fa4-4f03-4f2b-a480-172fef340d3f'; Name = 'System Application' },
        [pscustomobject]@{ Id = 'f3552374-a1f2-4356-848e-196002525837'; Name = 'Business Foundation' },
        [pscustomobject]@{ Id = '437dbf0e-84ff-417a-965d-ed2bb9650972'; Name = 'Base Application' },
        [pscustomobject]@{ Id = 'c1335042-3002-4257-bf8a-75c898ccb1b8'; Name = 'Application' }
    )
    $minimumMicrosoftVersion = [version]([string] $manifest.application)
    $missingMicrosoftSymbols = @()
    foreach ($requiredMicrosoftSymbol in $requiredMicrosoftSymbols) {
        $microsoftMatch = @($symbolPackages | Where-Object {
                ([string] $_.Manifest.id -ieq $requiredMicrosoftSymbol.Id) -and
                ([string] $_.Manifest.publisher -ceq 'Microsoft') -and
                ([string] $_.Manifest.name -ceq $requiredMicrosoftSymbol.Name) -and
                ([version]([string] $_.Manifest.version) -ge $minimumMicrosoftVersion)
            })
        if ($microsoftMatch.Count -eq 0) {
            $missingMicrosoftSymbols += "$($requiredMicrosoftSymbol.Name) / $($requiredMicrosoftSymbol.Id) / >= $minimumMicrosoftVersion"
        }
    }
    if ($missingMicrosoftSymbols.Count -eq 0) {
        Write-CheckResult PASS "Required Microsoft package identities are present at versions compatible with application $minimumMicrosoftVersion."
    }
    else {
        Write-CheckResult FAIL "Missing compatible Microsoft package manifests: $($missingMicrosoftSymbols -join ', ')."
    }
}

Write-Host ''
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $gitCommand) {
    Write-CheckResult FAIL 'Git was not found; repository hygiene cannot be verified.'
}
else {
    $trackedFiles = @(& $gitCommand.Source -C $resolvedRoot ls-files)
    $forbiddenTrackedFiles = @($trackedFiles | Where-Object {
            $_ -match '(^|/)(\.alpackages|\.build|\.snapshots)/' -or
            $_ -match '(^|/)\.vscode/(launch|rad)\.json$' -or
            $_ -match '\.app$'
        })
    if ($forbiddenTrackedFiles.Count -eq 0) {
        Write-CheckResult PASS 'No symbols, generated packages, build output, snapshots, launch.json, or rad.json are tracked.'
    }
    else {
        Write-CheckResult FAIL "Forbidden generated or personal files are tracked: $($forbiddenTrackedFiles -join ', ')."
    }
}

Write-CheckResult INFO 'Review the repository before granting VS Code Workspace Trust. Restricted Mode disables or limits tasks, settings, debugging, and extensions.'
Write-Host ''
Write-Host "Setup result: $($script:FailureCount) failure(s), $($script:WarningCount) warning(s)."

if ($script:FailureCount -gt 0) {
    exit 1
}

exit 0
