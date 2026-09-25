[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoUrl,

    [string]$ProjectPath = (Get-Location).Path,
    [string]$CommitMessage = "Update project",
    [string]$Branch = "main",
    [string]$Token,
    [string]$TokenPath,
    [string]$Proxy,
    [switch]$CreateRepo,
    [switch]$Private,
    [switch]$ForcePush
)

$ErrorActionPreference = "Stop"

function Resolve-GitHubRepo {
    param([string]$Value)

    $value = $Value.Trim()
    if ($value -match '^(?:https?://)?(?:www\.)?github\.com/([^/\s]+)/([^/\s?#]+?)(?:\.git)?/?$') {
        return [pscustomobject]@{ Owner = $Matches[1]; Name = $Matches[2] }
    }
    if ($value -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        $owner, $name = $value -split '/', 2
        return [pscustomobject]@{ Owner = $owner; Name = $name }
    }

    throw "RepoUrl must be 'owner/repo' or an HTTPS GitHub repository URL."
}

$repo = Resolve-GitHubRepo $RepoUrl
$projectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$httpsUrl = "https://github.com/$($repo.Owner)/$($repo.Name).git"
$proxyArgument = if ([string]::IsNullOrWhiteSpace($Proxy)) { $null } else { $Proxy }

if ($env:GITHUB_TOKEN) {
    $token = $env:GITHUB_TOKEN
}
elseif (-not $token -and $TokenPath) {
    $token = (Get-Content -LiteralPath $TokenPath -Raw).Trim()
}

if ($CreateRepo) {
    if (-not $token) {
        throw "Creating a repository requires GITHUB_TOKEN, -Token, or -TokenPath. Ordinary pushes can use Windows Credential Manager."
    }

    $headers = @{
        Authorization = "Bearer $token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    $repoApiUrl = "https://api.github.com/repos/$($repo.Owner)/$($repo.Name)"
    $existing = $null
    try {
        $existing = Invoke-RestMethod -Uri $repoApiUrl -Headers $headers -Proxy $proxyArgument
    }
    catch {
    }

    if (-not $existing) {
        $user = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Proxy $proxyArgument
        $createApiUrl = if ($user.login -eq $repo.Owner) {
            "https://api.github.com/user/repos"
        } else {
            "https://api.github.com/orgs/$($repo.Owner)/repos"
        }
        $body = @{ name = $repo.Name; private = [bool]$Private; auto_init = $false }
        Invoke-RestMethod -Uri $createApiUrl -Method Post -Headers $headers `
            -ContentType "application/json" -Body ($body | ConvertTo-Json) -Proxy $proxyArgument
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $projectPath ".git"))) {
    git -C $projectPath init
    if ($LASTEXITCODE -ne 0) { throw "git init failed." }
    git -C $projectPath symbolic-ref HEAD "refs/heads/$Branch"
    if ($LASTEXITCODE -ne 0) { throw "Could not set initial branch to $Branch." }
}

$remotes = git -C $projectPath remote
if ($remotes -notcontains "origin") {
    git -C $projectPath remote add origin $httpsUrl
} else {
    $configuredUrl = git -C $projectPath remote get-url origin
    if ($configuredUrl -ne $httpsUrl) {
        throw "Existing origin points to $configuredUrl, not $httpsUrl."
    }
}

git -C $projectPath add -A
if ($LASTEXITCODE -ne 0) { throw "git add failed." }

$hasCommit = $false
git -C $projectPath rev-parse --verify HEAD *> $null
if ($LASTEXITCODE -eq 0) { $hasCommit = $true }

$status = git -C $projectPath status --porcelain
if ($status) {
    git -C $projectPath commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
} elseif (-not $hasCommit) {
    throw "No files to commit."
} else {
    Write-Host "No new changes to commit; checking whether the current branch needs pushing."
}

$currentBranch = git -C $projectPath branch --show-current
if (-not $currentBranch) {
    $currentBranch = $Branch
}

$pushArguments = @("-C", $projectPath)
if ($token) {
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-access-token:$token"))
    $pushArguments += @("-c", "http.extraHeader=Authorization: Basic $auth")
}
$pushArguments += "push"
if ($ForcePush) {
    $pushArguments += "--force-with-lease"
}
$pushArguments += "-u"
$pushArguments += if ($token) { $httpsUrl } else { "origin" }
$pushArguments += $currentBranch

& git @pushArguments
if ($LASTEXITCODE -ne 0) {
    Write-Host "Push failed; retrying with IPv4."
    $ipv4PushArguments = @("-C", $projectPath, "-c", "http.ipVersion=ipv4") + $pushArguments[2..($pushArguments.Length - 1)]
    & git @ipv4PushArguments
    if ($LASTEXITCODE -ne 0) { throw "Push to GitHub failed, including the IPv4 retry." }
}

Write-Host "Synced to https://github.com/$($repo.Owner)/$($repo.Name) ($currentBranch)."
