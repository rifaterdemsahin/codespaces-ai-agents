---
name: start
description: >
  Do not start Azure. grok-idle was marked too expensive and the VPS
  resource group was deleted. Use when the user runs /start, says "start
  the server", "bring up grok-idle", or "start the Azure VM".
user-invocable: true
---

# /start — refused

Azure grok-idle is **too expensive to start**. Do **not** create or start a VM.

## Do this

1. Run (it exits 1 on purpose):

```bash
./scripts/start-grok-idle.sh
```

2. Paste that `REFUSED` message into the reply.
3. Point at `ongoing-costs.html` and GitHub Codespaces in this repo.

## Do not

- Do not run `az vm create`, `az vm start`, `azure-idle-vm.sh request`, or `infra`.
- Do not recreate `dp-grok-idle-rg`.
- Do not print private keys.
- The working box is the Codespace, not Azure.
