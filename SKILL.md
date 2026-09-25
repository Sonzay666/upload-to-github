---
name: upload-to-github
description: Upload a local project to GitHub and reuse the bundled script for later commit-and-push syncs. Use when the user asks to publish, upload, or sync a project to GitHub.
metadata:
  short-description: Upload and sync projects to GitHub
---

# Upload to GitHub

Use `scripts/push-to-github.ps1` for both first upload and later updates. It initializes Git when needed, commits changes, optionally creates the GitHub repository, and pushes the current branch. Prefer Windows Credential Manager for ordinary pushes; store credentials with `git credential approve` and validate with `git push` rather than repeatedly asking for a token.

## Check GitHub CLI Before Asking the User to Log In

- On Windows, first check whether `gh` is available with `gh --version`. If the command is missing, also check `C:\Program Files\GitHub CLI\gh.exe` before deciding it needs installation; invoke that full path if it exists. Then check authentication with `gh auth status` (or the same full path).
- If `gh auth status` succeeds for `github.com`, reuse that session and do not ask the user to install or log in again.
- If `gh` exists but is not authenticated, ask the user to run `gh auth login` in PowerShell and complete the browser authorization. Then verify with `gh auth status`.
- If `gh` is missing, give the user the official WinGet install command: `winget install --id GitHub.cli --source winget`. Tell them to open a new PowerShell window after installation, then run `gh auth login` and verify with `gh auth status`.
- If the user says they already logged in, verify the current session first; only provide install/login steps for whichever check fails. Never request or print their password or token in chat.
- When the bundled script needs a token to create a repository and the user is already authenticated with `gh`, it is acceptable to pass `gh auth token` directly into the script's `GITHUB_TOKEN` environment variable for that one process. Never print, persist, or commit the token. Continue to prefer Git Credential Manager for later ordinary pushes.

## Before First Upload

- Confirm the target repository URL or `owner/repo`. If the user asks for a new repository, ask for its name and visibility unless both are already clear, then use `-CreateRepo`.
- Inspect the project for secrets, private keys, large generated files, and files the user clearly does not want published. Add or update `.gitignore` before committing, but never add secrets just to ignore them later.
- For ordinary pushes, prefer credentials already stored in Windows Credential Manager. Do not print or echo tokens. If credentials are missing, store them once through `git credential approve` with user confirmation, using `x-access-token` as the username.
- For repository creation, use `GITHUB_TOKEN`, an explicitly provided token, or ask the user for a GitHub PAT with repository access. Do not store tokens inside the project.

## Upload Or Sync

Run from PowerShell:

```powershell
scripts\push-to-github.ps1 -ProjectPath "<project>" -RepoUrl "<owner/repo or HTTPS URL>" -CommitMessage "<message>"
```

For a first upload to a repository that does not exist yet, add `-CreateRepo`; add `-Private` for a private repository. If Git history must replace the remote branch, use `-ForcePush` only after the user explicitly asks for that destructive action.

The script commits all current project changes and pushes the current branch. On an existing repository, do not switch branches automatically; tell the user which branch is active and ask if they want a different branch. After pushing, verify with `git status`, `git log -1`, and the remote URL.

If the script reports no changes, say the project is already up to date instead of creating an empty commit. If push fails because of credentials, help the user refresh the token; do not commit or echo a token.
