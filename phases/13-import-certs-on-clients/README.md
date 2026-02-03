# Phase 13: Bootstrap Certificate Deployment

**Phase Name:** `13-import-certs-on-clients`
**Purpose:** Deploy certificates to bootstrap-critical bare metal devices
**Scope:** Mac Mini M4 Pro workstation + Proxmox hosts (echo and zero)

---

## Overview

Phase 13 completes the bootstrap process by deploying certificates to the bare metal infrastructure required for Terraform and Ansible to function. This phase achieves the **"Terraform-ready" state** - the final goal of the bootstrap process.

### What Gets Deployed

| Device | Certificate Type | Purpose |
|--------|-----------------|---------|
| **Mac Mini M4 Pro** | Root CA + Intermediate CA | Trust Proxmox web UI (HTTPS without warnings) |
| **Proxmox Node Echo** | Server certificate + private key | Terraform provider HTTPS API access |
| **Proxmox Node Zero** | Server certificate + private key | Terraform provider HTTPS API access |

### What Does NOT Get Deployed

The following devices are **NOT** in bootstrap scope and are managed by the Infrastructure repository:

- ❌ **VMs** (semaphore-ui, gitlab, postgresql) - Provisioned by Terraform, configured by Ansible
- ❌ **Network appliances** (UDM Pro, UNAS Pro) - Optional, managed by Infrastructure repo
- ❌ **Network printers** (HP OfficeJet) - Optional, managed by Infrastructure repo
- ❌ **Raspberry Pi** - Optional, not required for bootstrap

See `FusionCloudX Infrastructure/ansible/playbooks/optional/deploy-device-certificates.yml` for optional device deployment.

---

## Prerequisites

### Phase Dependencies

Phase 13 requires successful completion of:
- **Phase 00:** Precheck (installs yq for YAML parsing)
- **Phase 04:** Certificate Authority Bootstrap (generates PKI and stores in 1Password)

### Tool Requirements

| Tool | Purpose | Install Command |
|------|---------|-----------------|
| `yq` | YAML config parsing | Installed by Phase 00 |
| `op` | 1Password CLI | `brew install 1password-cli` |
| `security` | macOS keychain management | Built-in (macOS only) |
| `ssh` | Proxmox remote access | Built-in |
| `scp` | Certificate file transfer | Built-in |

### Network Requirements

- **SSH access** to Proxmox hosts (192.168.40.49 and 192.168.40.206)
- **SSH keys** configured for passwordless authentication
- **Network connectivity** to Proxmox management IPs

---

## Configuration

### Bootstrap Devices Configuration

**File:** `config/bootstrap-devices.yaml`

```yaml
bootstrap_devices:
  workstation:
    name: "Mac Mini M4 Pro"
    type: "macos-workstation"
    deployment_method: "security-cli"
    certs_needed:
      - "root-ca.pem"
      - "intermediate-ca.pem"
    onepassword_vault: "FusionCloudX"

  proxmox_hosts:
    - name: "Proxmox Node Echo"
      hostname: "echo"
      ip: "192.168.40.49"
      ssh_user: "root"
      type: "proxmox-host"
      deployment_method: "ssh-pvenode"
      onepassword_item: "FusionCloudX Server Certificate"

    - name: "Proxmox Node Zero"
      hostname: "zero"
      ip: "192.168.40.206"
      ssh_user: "root"
      type: "proxmox-host"
      deployment_method: "ssh-pvenode"
      onepassword_item: "FusionCloudX Server Certificate"
```

---

## Deployment Process

### Step 1: Workstation CA Deployment (macOS)

**Deployment Method:** `security-cli`

1. Downloads Root CA and Intermediate CA from 1Password
2. Imports Root CA to macOS System Keychain:
   ```bash
   sudo security add-trusted-cert -d -r trustRoot \
     -k /Library/Keychains/System.keychain root-ca.pem
   ```
3. Imports Intermediate CA to macOS System Keychain:
   ```bash
   sudo security add-trusted-cert -d -r trustAsRoot \
     -k /Library/Keychains/System.keychain intermediate-ca.pem
   ```

**Result:** Mac can access Proxmox web UI at `https://192.168.40.49:8006` with secure padlock (no warnings)

---

### Step 2: Proxmox Host Certificate Deployment

**Deployment Method:** `ssh-pvenode`

For each Proxmox host (echo and zero):

1. **Retrieve certificates from 1Password:**
   ```bash
   op document get "server-cert.pem" --vault FusionCloudX
   op document get "server-key.pem" --vault FusionCloudX
   ```

2. **Test SSH connectivity:**
   ```bash
   ssh -o ConnectTimeout=5 root@192.168.40.49 "echo 'SSH connection successful'"
   ```

3. **Copy certificate files to Proxmox:**
   ```bash
   scp server-cert.pem server-key.pem root@192.168.40.49:/tmp/
   ```

4. **Apply certificates using pvenode command:**
   ```bash
   ssh root@192.168.40.49 "pvenode cert set /tmp/server-cert.pem /tmp/server-key.pem"
   ```

5. **Restart pveproxy service:**
   ```bash
   ssh root@192.168.40.49 "systemctl restart pveproxy"
   ```

6. **Clean up temporary files:**
   ```bash
   ssh root@192.168.40.49 "rm -f /tmp/server-cert.pem /tmp/server-key.pem"
   ```

**Result:** Proxmox API accessible via HTTPS with trusted certificate (required for Terraform provider)

---

## Verification

### Automatic Verification

Phase 13 includes automatic verification:

1. **Keychain Check (macOS):**
   ```bash
   security find-certificate -c "FusionCloudX" /Library/Keychains/System.keychain
   ```

2. **HTTPS Accessibility Check (Proxmox):**
   ```bash
   curl -s -o /dev/null -w "%{http_code}" https://192.168.40.49:8006
   curl -s -o /dev/null -w "%{http_code}" https://192.168.40.206:8006
   ```

### Manual Verification

**Workstation:**
1. Open **Keychain Access** application
2. Navigate to **System** keychain
3. Search for "FusionCloudX"
4. Verify both Root CA and Intermediate CA are present and trusted

**Proxmox Hosts:**
1. Open browser to `https://192.168.40.49:8006`
2. Verify secure padlock appears (no certificate warnings)
3. Repeat for `https://192.168.40.206:8006`

**Terraform Provider Test:**
```bash
cd "FusionCloudX Infrastructure"
terraform init
terraform plan
```
Should connect to Proxmox API without certificate errors.

---

## Troubleshooting

### Issue: "Failed to import Root CA to System Keychain"

**Cause:** Insufficient administrator privileges

**Solution:**
```bash
# Run bootstrap with sudo
sudo ./bootstrap.sh --phase 13

# Or manually import:
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain /path/to/root-ca.pem
```

---

### Issue: "Cannot connect to Proxmox via SSH"

**Cause:** SSH keys not configured or network unreachable

**Solution 1 - Configure SSH Keys:**
```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "fusioncloudx-bootstrap"

# Copy to Proxmox hosts
ssh-copy-id root@192.168.40.49
ssh-copy-id root@192.168.40.206

# Test connectivity
ssh root@192.168.40.49 "hostname"
```

**Solution 2 - Check Network:**
```bash
# Test network connectivity
ping -c 3 192.168.40.49
ping -c 3 192.168.40.206

# Test SSH port
nc -zv 192.168.40.49 22
nc -zv 192.168.40.206 22
```

---

### Issue: "Failed to retrieve certificates from 1Password"

**Cause:** Phase 04 not completed or 1Password authentication expired

**Solution:**
```bash
# Re-authenticate with 1Password
op signin

# Verify certificates exist in 1Password
op document list --vault FusionCloudX | grep -E "root-ca|intermediate-ca|server-cert|server-key"

# If missing, re-run Phase 04
./bootstrap.sh --phase 04
```

---

### Issue: "pvenode cert set failed"

**Cause:** Certificate format incorrect or Proxmox service issues

**Solution:**
```bash
# Manually verify certificate format on Proxmox
ssh root@192.168.40.49
openssl x509 -in /tmp/server-cert.pem -text -noout
openssl rsa -in /tmp/server-key.pem -check

# Check Proxmox certificate directory permissions
ls -la /etc/pve/nodes/echo/
ls -la /etc/pve/local/

# Check pveproxy service status
systemctl status pveproxy
journalctl -u pveproxy -n 50
```

---

## Success Criteria

Phase 13 is complete when:

- ✅ **Workstation:** CA certificates installed in macOS System Keychain
- ✅ **Workstation:** Proxmox web UI accessible with secure padlock
- ✅ **Proxmox Echo:** Server certificate deployed and pveproxy restarted
- ✅ **Proxmox Zero:** Server certificate deployed and pveproxy restarted
- ✅ **Verification:** All HTTPS endpoints return 200/401/302 status codes
- ✅ **Terraform:** `terraform init` connects to Proxmox API without certificate errors

**Result:** Bootstrap process complete - **Terraform-ready state achieved** ✓

---

## Next Steps

After Phase 13 completes successfully:

1. **Switch to Infrastructure Repository:**
   ```bash
   cd ~/Developer/Personal/Repositories/FusionCloudX\ Infrastructure
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   terraform plan
   ```

3. **Deploy Infrastructure:**
   ```bash
   # Provision VMs with Terraform
   terraform apply

   # Configure VMs with Ansible
   ansible-playbook ansible/playbooks/site.yml
   ```

4. **Deploy Certificates to VMs** (handled by Infrastructure repo):
   - Ansible `certificates` role automatically deploys CA and server certs to all VMs
   - See `FusionCloudX Infrastructure/ansible/roles/certificates/README.md`

---

## Architecture Notes

### Why Bootstrap Only Handles Bare Metal

**Bootstrap Repository Scope:**
- One-time disaster recovery execution
- Establishes foundation for Terraform/Ansible
- Ends at "Terraform-ready" state
- **Only bare metal devices**

**Infrastructure Repository Scope:**
- Ongoing operations and management
- Provisions VMs via Terraform
- Configures VMs via Ansible
- **All VMs and services**

### Certificate Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│         BOOTSTRAP REPOSITORY (Phase 13)                     │
│                Disaster Recovery                             │
└─────────────────────────────────────────────────────────────┘
         │
         ├─ Phase 04: Generate PKI → Store in 1Password
         │
         └─ Phase 13: Deploy to Bare Metal
                      ├─ Mac Mini: CA trust (Proxmox UI access)
                      └─ Proxmox: Server certs (Terraform HTTPS API)

         ✓ Terraform-ready state achieved

┌─────────────────────────────────────────────────────────────┐
│      INFRASTRUCTURE REPOSITORY (Operations)                 │
│                 Ongoing Management                           │
└─────────────────────────────────────────────────────────────┘
         │
         ├─ Terraform: Provision VMs
         │
         ├─ Ansible certificates role: Deploy certs to VMs
         │            ├─ Install CA to system trust
         │            └─ Deploy server certs to services
         │
         └─ Optional: deploy-device-certificates.yml
                      └─ Network devices (printer, appliances)
```

---

## File References

**Configuration:**
- `config/bootstrap-devices.yaml` - Device inventory for bootstrap scope

**Documentation:**
- `phases/13-import-certs-on-clients/README.md` - This file
- `CLAUDE.md` - Repository-level guidance with bootstrap vs infrastructure boundaries

**Related Infrastructure Files:**
- `FusionCloudX Infrastructure/ansible/roles/certificates/` - VM certificate deployment
- `FusionCloudX Infrastructure/ansible/playbooks/optional/deploy-device-certificates.yml` - Optional devices

---

**Last Updated:** 2026-02-03
**Bootstrap Version:** 1.0
**Phase Status:** Complete implementation with Mac Mini and Proxmox support
