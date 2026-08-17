#!/usr/bin/env bash
#
# git + GitHub CLI, and GitHub authentication (PAT or browser OAuth).

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

step "git and GitHub CLI"

apt_install git gh

ok "git $(git --version | awk '{print $3}')"
ok "gh $(gh --version | head -1 | awk '{print $3}')"

# Scopes the maintainer's existing token carries, minus delete_repo.
REQUIRED_SCOPES=(repo read:org gist workflow)

# ---------------------------------------------------------------------------
# Detect existing credentials before prompting for anything.
# ---------------------------------------------------------------------------

step "GitHub authentication"

auth_ok=0
if gh auth status >/dev/null 2>&1; then
  auth_ok=1
fi

if [[ $auth_ok -eq 1 ]]; then
  account="$(gh api user --jq .login 2>/dev/null || echo '?')"
  skip "gh is already authenticated as $account"

  # Already authed, but possibly missing a scope this setup needs.
  scopes="$(gh auth status 2>&1 | sed -n 's/.*Token scopes: //p' | tr -d "'" )"
  missing=()
  for s in "${REQUIRED_SCOPES[@]}"; do
    grep -q "\b$s\b" <<<"$scopes" || missing+=("$s")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "token is missing scope(s): ${missing[*]}"
    warn "add them with: gh auth refresh -h github.com -s $(IFS=,; echo "${missing[*]}")"
  else
    ok "token has all required scopes"
  fi
else
  info "no GitHub credentials found on this machine"

  if ! is_interactive; then
    warn "non-interactive run — skipping GitHub login"
    warn "authenticate later with: ./install.sh git-gh"
    exit 0
  fi

  cat <<'GUIDE'

    ┌─────────────────────────────────────────────────────────────────────┐
    │  GitHub authentication — two options                                │
    ├─────────────────────────────────────────────────────────────────────┤
    │                                                                     │
    │  1. Browser login (recommended)                                     │
    │     gh opens github.com, you click Authorize, done. The token is    │
    │     short-lived, scoped correctly, and stored in your keyring.      │
    │                                                                     │
    │  2. Personal Access Token (PAT)                                     │
    │     Paste a token you create by hand. Use this on a headless box,   │
    │     or when you need a long-lived token.                            │
    │                                                                     │
    └─────────────────────────────────────────────────────────────────────┘

GUIDE

  if confirm "Use browser login? (answer n for the PAT walkthrough)" y; then
    # ----------------------------------------------------------- OAuth ----
    info "launching browser login"
    if gh auth login --hostname github.com --git-protocol https --web \
        --scopes "$(IFS=,; echo "${REQUIRED_SCOPES[*]}")"; then
      ok "authenticated via browser"
    else
      die "browser login failed — re-run: ./install.sh git-gh"
    fi
  else
    # ------------------------------------------------------------- PAT ----
    scope_csv="$(IFS=,; echo "${REQUIRED_SCOPES[*]}")"

    cat <<GUIDE

    ─────────────────────────────────────────────────────────────────────
    Creating a GitHub Personal Access Token — step by step
    ─────────────────────────────────────────────────────────────────────

    STEP 1.  Open the token creation page.

             This link pre-selects the scopes you need:

               https://github.com/settings/tokens/new?scopes=${scope_csv}&description=dotfiles

             Or navigate by hand:
               GitHub → your avatar (top right) → Settings
                      → Developer settings  (bottom of the left sidebar)
                      → Personal access tokens → Tokens (classic)
                      → Generate new token → Generate new token (classic)

    STEP 2.  Name it something you'll recognise later.

               Note:  dotfiles — $(hostname)

    STEP 3.  Set an expiration.

             90 days is a good default. "No expiration" is convenient and
             is also a credential that never stops working if it leaks.

    STEP 4.  Tick these scopes (pre-ticked if you used the link above):

               [x] repo         push/pull private repositories
               [x] read:org     read org membership (gh needs it)
               [x] gist         create gists
               [x] workflow     update GitHub Actions workflow files

    STEP 5.  Click "Generate token" at the bottom of the page.

    STEP 6.  Copy the token immediately.

             It starts with  ghp_  and GitHub shows it exactly once.
             Navigate away and it is gone for good — you'd make a new one.

    STEP 7.  Paste it at the prompt below.

             Nothing will appear as you type or paste. That is intentional.
             gh stores it in your keyring; it is not written to this repo.

    ─────────────────────────────────────────────────────────────────────

GUIDE

    token=""
    for attempt in 1 2 3; do
      read -r -s -p "    Paste your GitHub token (input hidden): " token
      echo
      token="${token//[[:space:]]/}"

      if [[ -z "$token" ]]; then
        warn "nothing pasted (attempt $attempt of 3)"
        continue
      fi
      # ghp_ = classic PAT, github_pat_ = fine-grained, gho_ = OAuth token.
      if [[ ! "$token" =~ ^(ghp_|github_pat_|gho_) ]]; then
        warn "that doesn't look like a GitHub token (expected a ghp_ or github_pat_ prefix)"
        confirm "Try again?" y && continue
      fi

      if gh auth login --hostname github.com --git-protocol https \
           --with-token <<<"$token"; then
        ok "token accepted"
        break
      else
        warn "GitHub rejected that token (attempt $attempt of 3)"
        token=""
      fi
    done

    unset token
    gh auth status >/dev/null 2>&1 || die "authentication failed — re-run: ./install.sh git-gh"
  fi
fi

# ---------------------------------------------------------------------------
# Wire git itself to authenticate through gh.
# ---------------------------------------------------------------------------

step "git credential helper"

# .gitconfig in the git/ stow package already points at gh as the credential
# helper. Running setup-git makes that true even before the config is stowed,
# and is harmless when it is.
if git config --get "credential.https://github.com.helper" | grep -q 'gh auth'; then
  skip "git already authenticates through gh"
else
  gh auth setup-git && ok "git will now authenticate through gh"
fi

# Commits fail outright without an identity, so prompt rather than let the
# first commit blow up.
if ! git config --global user.name >/dev/null 2>&1; then
  if is_interactive; then
    read -r -p "    git user.name: " gname
    [[ -n "$gname" ]] && git config --global user.name "$gname" && ok "user.name set"
  else
    warn "git user.name is unset — commits will fail"
  fi
else
  skip "git user.name ($(git config --global user.name))"
fi

if ! git config --global user.email >/dev/null 2>&1; then
  if is_interactive; then
    read -r -p "    git user.email: " gmail
    [[ -n "$gmail" ]] && git config --global user.email "$gmail" && ok "user.email set"
  else
    warn "git user.email is unset — commits will fail"
  fi
else
  skip "git user.email ($(git config --global user.email))"
fi
