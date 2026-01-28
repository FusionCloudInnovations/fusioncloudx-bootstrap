# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FusionCloudX Bootstrap is a disaster recovery and infrastructure provisioning orchestration framework. It bootstraps Windows/WSL and Linux environments with networking, PKI/certificate authority, SSH keys, Terraform infrastructure, and Ansible provisioning through a multi-phase execution system.

## Architecture

### Entry Points
- `bootstrap.sh` - Linux/WSL entry point with error trapping and phase orchestration
- `bootstrap.ps1` - Windows PowerShell entry point with WinGet and WSL2 management

### Core Structure
```
modules/           # Shared bash libraries (logging, state, 1password, notifications)
phases/            # Modular bootstrap steps (00-precheck through 99-notify)
config/            # Configuration (bootstrap.yaml is the main config source)
terraform/         # Infrastructure as Code (modules: network, vm)
ansible/           # Configuration management (roles: common, users, dotfiles)
state/             # Runtime state tracking (ran_phases.txt)
logs/              # Execution logs with auto-rotation
```

### Phase System
Phases are numbered directories containing `run.sh` scripts executed sequentially:
- `00-precheck` - OS/shell/clock validation
- `01-wsl-init` - WSL initialization
- `02-tools` - Package installation (git, terraform, yq, ansible, jq)
- `03-network-checks` - Connectivity validation
- `04-cert-authority-bootstrap` - PKI setup with 1Password integration
- `05-15` - SSH, VM, Terraform, Ansible, verification phases (partially implemented)
- `99-notify` - Slack notifications

State tracking prevents re-running completed phases via `state/ran_phases.txt`.

## Bootstrap Scope and Boundaries

### What Bootstrap Does

**Purpose:** Disaster recovery - bootstrap from zero to "Terraform-ready" state

**Scope:** Bare metal resources only
- Mac Mini M4 Pro workstation (CA certificate trust)
- Proxmox hosts (echo, zero) - server certificates for HTTPS API

**End Goal:** Terraform and Ansible can successfully connect to infrastructure

**Bootstrap completes when:**
- ✅ Workstation can access Proxmox web UI with secure padlock
- ✅ Terraform provider can connect to Proxmox HTTPS API
- ✅ SSH keys configured for Proxmox and future VMs
- ✅ PKI established and certificates stored in 1Password

### What Bootstrap Does NOT Do

**Out of Scope:** Operational infrastructure management

Bootstrap does **NOT** handle:
- ❌ **VMs** - Provisioned by `FusionCloudX Infrastructure` Terraform
- ❌ **VM Configuration** - Managed by `FusionCloudX Infrastructure` Ansible
- ❌ **Network Devices** - Optional, managed by Infrastructure optional playbooks
- ❌ **Ongoing Operations** - Managed by Infrastructure Control Plane (Semaphore UI)

### Repository Integration

**This Repository (fusioncloudx-bootstrap):**
- Phase 04: Generate PKI, store certificates in 1Password
- Phase 13: Deploy certificates to bare metal (Mac Mini + Proxmox)
- One-time execution during disaster recovery

**Infrastructure Repository (FusionCloudX Infrastructure):**
- Terraform: Provision VMs (semaphore-ui, gitlab, postgresql)
- Ansible: Configure VMs, deploy certificates to VMs
- Control Plane: Semaphore UI orchestrates ongoing operations
- Optional: Deploy certificates to network devices

**Decision Tree: Should this be in Bootstrap?**
- Is it bare metal? → Bootstrap
- Is it required for Terraform/Ansible to function? → Bootstrap
- Is it a VM or service? → Infrastructure
- Is it optional (printer, network device)? → Infrastructure (optional playbook)

See `config/bootstrap-devices.yaml` for bootstrap-scoped device inventory.

## Running the Bootstrap

```bash
# Full bootstrap
bash bootstrap.sh

# Debug mode
DEBUG=1 bash bootstrap.sh

# Clean start (ignore previous state)
WSL_CLEAN_RUN=true bash bootstrap.sh

# Run specific phases only
PHASES="00-precheck 02-tools" bash bootstrap.sh

# Run single phase directly
bash phases/04-cert-authority-bootstrap/run.sh
```

## Key Environment Variables

- `OP_SERVICE_ACCOUNT_TOKEN` - 1Password CLI authentication (required for phase 04+)
- `DEBUG=1` - Enable verbose logging
- `WSL_CLEAN_RUN=true` - Force fresh start, ignore state
- `PHASES` - Space-separated list of phases to run

Configuration is loaded from `config/bootstrap.yaml` and converted to shell environment variables.

## Module Patterns

When creating new phases or modifying existing ones:

```bash
PHASE_NAME="XX-phase-name"
source modules/logging.sh
source modules/state.sh

log_phase "$PHASE_NAME" "start" "emoji" "description"
# Phase logic here
```

Key functions:
- `log_info`, `log_success`, `log_warn`, `log_error`, `log_debug` - Logging
- `mark_phase_as_run`, `phase_already_run` - State tracking
- `check_op_vault_access` - 1Password validation

## Commit Conventions

This project uses Conventional Commits with Gitmoji:

```bash
feat(scope): description emoji
fix(scope): description emoji
refactor(scope): description emoji
```

Common scopes: `bootstrap`, `cert`, `wsl`, `tools`, `network`, `terraform`, `ansible`, `modules`, `logging`, `1password`

Breaking changes: Use `!` after scope (e.g., `feat(cert)!: description`)
