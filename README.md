# Codespaces AI Agents

Public explainer: [https://rifaterdemsahin.github.io/codespaces-ai-agents/](https://rifaterdemsahin.github.io/codespaces-ai-agents/)

Test from an iPhone 14 Pro Max (Safari): [iphone.html](https://rifaterdemsahin.github.io/codespaces-ai-agents/iphone.html)

Open this repo in **GitHub Codespaces**. The container installs:

- **Grok Build** (`grok`) — xAI, subscription login
- **Antigravity CLI** (`agy`) — Google, URL login
- **Azure CLI** (`az`) — device-code login to Key Vault `dp-kv-deliverypilot`
- **GitHub CLI** (`gh`)

A **$4 GitHub Pro** plan on a **personal** account covers the **machine** (included Codespaces hours). Use **SuperGrok / X Premium+** and **Google** for the agents. See [SUBSCRIPTION.md](SUBSCRIPTION.md).

---

## 0. Prerequisites

1. A **personal** GitHub account (Free or Pro). Organization/Team plans do **not** include a Codespaces quota.
2. For Grok: SuperGrok or X Premium+ on the X / Grok account you will sign in with.
3. For Antigravity: the Google account that has Antigravity access.
4. For Key Vault (optional secrets): Azure access to `dp-kv-deliverypilot` as `info@deliverypilot.net` (or another user with get/list on that vault).

---

## 1. Open a Codespace

Repo is already on GitHub: [rifaterdemsahin/codespaces-ai-agents](https://github.com/rifaterdemsahin/codespaces-ai-agents).

1. Open the repo on GitHub.
2. **Code** → **Codespaces** → **Create codespace on main**.
3. Pick **2-core** if asked.
4. Wait for the build. `.devcontainer/post-create.sh` installs `grok` and `agy`.

### From a phone

iPhone 14 Pro Max, step by step: [iphone.html](https://rifaterdemsahin.github.io/codespaces-ai-agents/iphone.html).

Short version: Safari (not the GitHub app) → Request Desktop Website → **Code → Codespaces**. Device-code logins open in a second Safari tab on the same phone.

---

## 2. Cap spend so you cannot go over $4

1. GitHub → **Settings** → **Billing** → budgets / Codespaces spending limit.
2. Set extra Codespaces spend to **$0**.
3. With $0 extra, Codespaces **stops** when included hours or storage run out.

### Included hours (personal accounts only)

| Plan | Core-hours / month | Storage | ~2-core wall time |
|---|---|---|---|
| GitHub Free | 120 | 15 GB-month | ~60 hours |
| GitHub Pro ($4) | 180 | 20 GB-month | ~90 hours |

4-core burns the quota twice as fast. Stay on **2-core**.

---

## 3. Authenticate with your subscriptions (no API keys)

Full detail: [SUBSCRIPTION.md](SUBSCRIPTION.md).

```bash
# Do not set XAI_API_KEY — that switches you to pay-per-token.
unset XAI_API_KEY

grok login --device-auth
agy
```

Approve the printed URL/code on your phone. Then:

```bash
grok --version
grok models
agy --version
```

---

## 4. Optional: Azure Key Vault

The vault already exists. Do **not** create a new one.

```bash
az login --use-device-code
./scripts/kv-env.sh status          # names and lengths only
./scripts/kv-env.sh write           # .env without XAI_API_KEY
./scripts/kv-env.sh write --include-xai   # also XAI_API_KEY (pay-per-token)
set -a && source .env && set +a
```

`.env` is gitignored. Default `write` leaves Grok on subscription billing.

---

## 5. Use them

```bash
grok
agy

grok --mode plan
grok -p "Explain this repo"
```

---

## 6. Stay inside included hours

1. **2-core** only.
2. **Stop** the codespace when you leave.
3. Delete unused codespaces (storage still counts while they exist).
4. Keep one codespace.

All-day daily use will exceed ~90 hours on Pro. Evenings/weekends from a phone is the intended fit.

---

## 7. Daily loop

1. github.com → repo → **Codespaces** → Resume.
2. Terminal → `grok` and/or `agy`.
3. Commit and push.
4. **Stop** the codespace.

---

## Repo layout

```
.devcontainer/
  devcontainer.json
  post-create.sh
.github/workflows/
  ci.yml
  pages.yml
scripts/
  kv-env.sh
  smoke-test.sh
.gitignore
.env.example
AGENTS.md
README.md
SUBSCRIPTION.md
index.html
```

After you change `.devcontainer/*`: Command Palette → **Codespaces: Rebuild Container**.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `grok` / `agy` not found | New terminal, or `export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"`. Rebuild if install failed. |
| Grok wants a browser | `grok login --device-auth` (do not set `XAI_API_KEY`). |
| Codespaces blocked | Hours/storage used up, or $0 spend cap. Check Billing. |
| No free hours on an org repo | Put this repo under your **personal** account. |
| Quota disappearing fast | Recreate on **2-core**. |
| Azure CLI asks for a browser | `az login --use-device-code` or `./scripts/kv-env.sh login`. |

---

## License

You own this starter. Use it however you want.
