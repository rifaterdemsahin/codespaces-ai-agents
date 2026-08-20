# Agent instructions

This workspace is a Codespaces starter for terminal agents:

- Grok Build (`grok`)
- Antigravity (`agy`)

Optional secrets come from Azure Key Vault `dp-kv-deliverypilot` via `./scripts/kv-env.sh`.

## Rules

- Stay in the project directory unless asked to clone another repo.
- Prefer small, reviewable diffs.
- Do not commit secrets, `.env`, API keys, or the `grok-idle` private key / WhatsApp zip. Export that key with `./scripts/export-grok-idle-key.sh` into `~/Downloads` and follow `ops-whatsapp-key.html`.
- Default billing is subscription login (`grok login --device-auth`, `agy` Google URL). Do not set `XAI_API_KEY` unless the user asks for vault `--include-xai`.
- Do not create a new Key Vault. Use `dp-kv-deliverypilot`.
- Do not run destructive git commands (`reset --hard`, force-push) unless the user asks.
- Ask before changing billing-related or production infrastructure.

## Codespace constraints

- Default machine is 2-core. Avoid heavy parallel builds.
- Stop long-running servers when they are not needed.

## Docs site

GitHub Pages HTML lives next to `nav.js`. If you change how the environment works, update those pages and `tests/test_system.py`.
