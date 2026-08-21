---
name: start
description: >
  Start or recreate the Azure grok-idle VM and print SSH/Termius connection
  details in the terminal. Use when the user runs /start, says "start the
  server", "bring up grok-idle", "start the Azure VM", or needs the current
  host/user/key for Termius.
user-invocable: true
---

# /start — grok-idle

Start (or recreate after idle-delete) the Azure VM and print connection details.

## Do this

1. From the repo root run:

```bash
./scripts/start-grok-idle.sh
```

2. Paste the script stdout into the reply. That is the connection card.

3. If `az` is not logged in, tell the user to run `az login --use-device-code` as `info@deliverypilot.net` and then re-run `/start`. Do not invent an IP.

## Rules

- Never print, copy, or commit the private key. Only the path (`~/.ssh/grok-idle`) and the public fingerprint.
- Recreate is expected: idle-delete removes the VM after ~20 min with no SSH. `/start` brings it back on the static IP when that IP still exists.
- After recreate, Termius must **Accept** the new host key. User is `azureuser`, key is `grok-idle` imported via `ops-whatsapp-key.html` (Import / Paste — never Export Key).
- Do not `nuke` the resource group. Do not change the $5 budget.
- Costs: `ongoing-costs.html`. The leftover static IP still bills while the VM is gone.

## If the script fails

Show the error. Common cases: VM SKU capacity, `az` not logged in, wrong Azure user. Do not retry a failed `az vm create` in a loop.
