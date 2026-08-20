# Use your subscriptions (no API keys)

This Codespace is set up for **subscription login**, not pay-per-token API keys.

| Tool | Subscription you already pay for | How you log in from Codespaces |
|---|---|---|
| Grok Build (`grok`) | SuperGrok or X Premium+ | `grok login --device-auth` |
| Antigravity (`agy`) | Google account (Antigravity / Gemini access) | `agy` prints a login URL |

GitHub Pro ($4) only pays for the **virtual machine**. Your xAI and Google subscriptions pay for the **models**.

---

## Why device login (not an API key)

Codespaces has no usable desktop browser for the normal “open grok.com” flow.

`grok login --device-auth` prints a short code and a URL. You approve it on your **phone or laptop** while signed into the same X / Grok account that has SuperGrok or X Premium+. After that, `grok` uses your subscription quota.

Do **not** set `XAI_API_KEY` if you want subscription billing. An API key overrides subscription login and is charged per token.

---

## Grok — first login

In the Codespace terminal:

```bash
grok login --device-auth
```

1. The CLI prints a URL and a code.
2. On your phone, open the URL while logged into X / grok.com with the subscribed account.
3. Enter or confirm the code.
4. Return to the Codespace.

Check:

```bash
grok --version
grok models
```

`grok models` succeeding means the subscription session is valid.

Then:

```bash
cd /workspaces/codespaces-ai-agents   # or your project folder
grok
```

Login is stored under `~/.grok/` **inside this codespace**. It is not on your phone.

### If login expires

Tokens eventually expire. Run again:

```bash
grok login --device-auth
```

### If you rebuilt or created a new codespace

You must log in again. Subscription is tied to that machine’s `~/.grok` folder, not to GitHub.

### If it still asks for an API key

```bash
unset XAI_API_KEY
# Also delete a Codespaces secret named XAI_API_KEY if you added one earlier
grok login --device-auth
```

---

## Antigravity — first login

```bash
agy
```

1. On SSH / Codespaces it prints a Google authorization URL.
2. Open that URL on your phone.
3. Sign in with the Google account that has Antigravity access.
4. Return to the terminal.

Check:

```bash
agy --version
```

Then run `agy` in your project folder.

If you get signed out:

```bash
agy
# or, if the CLI supports it:
# /logout   (inside the TUI) then run agy again
```

---

## Phone workflow

1. Open the repo on github.com → **Code** → **Codespaces** → Resume or Create (**2-core**).
2. Open the terminal.
3. First time only: `grok login --device-auth`, then `agy` (Google URL).
4. After that: `grok` or `agy`.
5. **Stop** the codespace when you finish so GitHub hours are not wasted.

---

## What each bill covers

| You pay | Covers | Does not cover |
|---|---|---|
| GitHub Pro ~$4 | Codespace VM (included hours) | Grok or Gemini tokens |
| SuperGrok / X Premium+ | `grok` agent usage via subscription | The GitHub VM |
| Google / Antigravity access | `agy` agent usage | The GitHub VM |

You should **not** need console.x.ai or an `xai-...` key for this setup.

---

## Optional — Azure Key Vault (other tools, or Grok pay-per-token)

Vault: `dp-kv-deliverypilot`. Device login from Codespaces:

```bash
az login --use-device-code
./scripts/kv-env.sh status
./scripts/kv-env.sh write                 # Anthropic / OpenAI / Gemini / OpenRouter / fal
./scripts/kv-env.sh write --include-xai   # also XAI_API_KEY — overrides subscription billing
```

`.env` is gitignored. Do not paste vault values into GitHub secrets unless you intentionally want pay-per-token Grok.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Grok opens a browser that never loads | Use `grok login --device-auth`, not plain `grok login`. |
| Grok says to set `XAI_API_KEY` | Unset the variable and remove any Codespaces secret with that name. |
| Login worked, new codespace forgot it | Device login is per codespace. Run `--device-auth` again. |
| Account has no SuperGrok / Premium+ | Subscription login will fail or be limited until that account is upgraded. |
| Wrong Google account | Sign out of Google in the phone browser, then open the `agy` URL again. |
