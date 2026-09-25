# Upload to GitHub

A Codex skill for uploading a local project to GitHub and syncing later changes. It uses a small PowerShell script, checks authentication before asking the user to log in, and supports creating private repositories.

## 中文简介

这是一个帮助 Codex 将本地项目上传到 GitHub、并在之后同步更新的技能。它会先检查 GitHub CLI 是否已安装和登录，尽量复用现有登录状态；新建私有仓库时也会提醒检查密钥和本地文件。

## Install

Copy this folder to:

```text
%USERPROFILE%\.codex\skills\upload-to-github
```

Restart or refresh Codex's skill list if needed.

## Requirements

- Git for Windows
- PowerShell
- GitHub CLI (`gh`) is recommended for browser-based sign-in and repository creation

On Windows, install GitHub CLI with:

```powershell
winget install --id GitHub.cli --source winget
```

Open a new PowerShell window after installation. Sign in only if `gh auth status` does not already show an active GitHub.com session:

```powershell
gh auth login
gh auth status
```

## Usage

Sync a project to an existing repository:

```powershell
.\scripts\push-to-github.ps1 -ProjectPath "C:\path\to\project" -RepoUrl "owner/repo" -CommitMessage "Update project"
```

Create a private repository on the first upload:

```powershell
$env:GITHUB_TOKEN = gh auth token
.\scripts\push-to-github.ps1 -ProjectPath "C:\path\to\project" -RepoUrl "owner/repo" -CreateRepo -Private -CommitMessage "Initial upload"
Remove-Item Env:GITHUB_TOKEN
```

For public repositories, omit `-Private`. The script never writes tokens into the project. Prefer Git Credential Manager or `gh auth setup-git` for normal pushes.

## Safety

- Review the project for secrets, credentials, private keys, and files that should stay local before uploading.
- Add local-only files to `.gitignore` before the first commit. Ignoring a secret does not remove it from existing Git history.
- The script does not force-push unless `-ForcePush` is explicitly supplied.
- If an earlier push failed after creating a commit, rerunning the script retries the push without making an empty commit.

## License

MIT. See [LICENSE](LICENSE).
