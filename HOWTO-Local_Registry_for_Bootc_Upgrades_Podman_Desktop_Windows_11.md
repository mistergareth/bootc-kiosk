# Step-by-Step Procedure for Setting Up a Local Registry for Bootc Upgrades on Windows with Podman Desktop and VirtualBox VM

This document captures the successful configuration for running a local container registry on Windows 11 using Podman Desktop, enabling atomic upgrades for a CentOS Stream 10 bootc kiosk image in a VirtualBox VM. It includes all key findings, such as the netsh proxy for WSL2 IP forwarding, VirtualBox Bridged Adapter setup, and insecure registry handling. Follow these steps sequentially for a reliable workflow.

## Prerequisites
- Windows 11 with WSL2 enabled (install via `wsl --install` if not already).
- Podman Desktop installed and running (download from podman-desktop.io).
- VirtualBox installed (virtualbox.org).
- A built bootc image (e.g., from your Containerfile, tagged as `localhost:5000/my-kiosk:latest`).
- Your Windows host IP (e.g., 192.168.1.155 — find with `ipconfig`).

## Step 1: Start the Local Registry Container with Persistent Storage
The registry needs a volume to persist pushed images across restarts. Use the official `registry:2` image.

1. Stop and remove any existing registry (if running):
   ```
   podman stop local-registry || true
   podman rm local-registry || true
   podman volume rm registry-data || true
   ```

2. Create the volume and start the registry:
   ```
   podman volume create registry-data
   podman run -d --name local-registry \
     -p 0.0.0.0:5000:5000 \
     -v registry-data:/var/lib/registry:z \
     --privileged \
     registry:2
   ```

3. Wait 30 seconds, then check logs for confirmation:
   ```
   podman logs local-registry
   ```
   - Look for "listening on [::]:5000" (healthy startup).

## Step 2: Get the WSL2 (Podman Machine) IP
Podman Desktop runs in a WSL2 VM, so the registry is bound there. Get its internal IP.

1. Run:
   ```
   podman machine ssh "ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1"
   ```
   - Example output: `172.18.6.44` (your WSL IP — note it down).

## Step 3: Set Up netsh Port Proxy on Windows
Forward traffic from your host's LAN IP (e.g., 192.168.1.155) to the WSL IP on port 5000.

1. Delete any old proxy (if exists):
   ```
   netsh interface portproxy delete v4tov4 listenport=5000 listenaddress=0.0.0.0
   ```

2. Add the new proxy (replace `<WSL_IP>` with your value from Step 2):
   ```
   netsh interface portproxy add v4tov4 listenport=5000 listenaddress=0.0.0.0 connectport=5000 connectaddress=<WSL_IP>
   ```

3. Confirm proxy:
   ```
   netsh interface portproxy show v4tov4
   ```

## Step 4: Add Windows Firewall Rule for Port 5000
Allow inbound traffic on port 5000.

1. Open Windows Defender Firewall > Advanced Settings > Inbound Rules > New Rule.
2. Rule Type: Port.
3. Protocol: TCP, Specific local ports: 5000.
4. Action: Allow the connection.
5. Profile: All (Domain, Private, Public).
6. Name: Podman Local Registry.

## Step 5: Build and Push Your Kiosk Image to the Registry
1. Build (from your Containerfile directory):
   ```
   podman build -t localhost:5000/my-kiosk:latest .
   ```

2. Push (insecure flag for HTTP):
   ```
   podman push --tls-verify=false localhost:5000/my-kiosk:latest
   ```

3. Verify on host:
   ```
   curl -i http://localhost:5000/v2/
   ```
   - Expect 200 OK + Docker-Distribution-Api-Version header + empty body `{}` (curl may warn (52) — normal).

   ```
   curl http://localhost:5000/v2/my-kiosk/tags/list
   ```
   - Expect: `{"name":"my-kiosk","tags":["latest"]}`.

   ```
   curl http://192.168.1.155:5000/v2/my-kiosk/tags/list
   ```
   - Same via netsh proxy.

## Step 6: Configure VirtualBox VM for Bridged Adapter
For the VM to reach the host's LAN IP (192.168.1.155:5000).

1. Shut down the VM completely (Power Off).
2. VM Settings > Network > Adapter 1:
   - Enable Network Adapter: Checked.
   - Attached to: **Bridged Adapter**.
   - Name: Your host's active adapter (e.g., "Wi-Fi").
   - Advanced > Promiscuous Mode: Allow All.
   - **Cable connected**: Checked (critical!).
3. Start the VM.
4. Inside VM: Confirm LAN IP (e.g., 192.168.1.159):
   ```
   ip addr show
   nmcli device status
   ```

5. Test registry from VM:
   ```
   curl http://192.168.1.155:5000/v2/my-kiosk/tags/list
   ```
   - Expect JSON tags.

## Step 7: Configure Insecure Registry in the VM
To allow HTTP pulls.

1. In VM:
   ```
   sudo mkdir -p /etc/containers/registries.conf.d
   sudo tee /etc/containers/registries.conf.d/local.conf <<EOF
   [[registry]]
   location = "192.168.1.155:5000"
   insecure = true
   EOF
   ```

# Updated Step-by-Step Procedure for Local Registry + Bootc Upgrades
*(Including Rollback Verification)*

## Step 8: Perform Bootc Switch, Upgrade, and Rollback Verification in the VM

After completing Steps 1–7 (registry running, netsh proxy set, VM on Bridged Adapter with "Cable connected" checked, insecure registry configured in VM), follow these steps to test upgrades and **verify rollback functionality**.

### 8.1 Initial Upgrade Test
1. In the VM (using your host LAN IP, e.g., 192.168.1.155):
   ```
   sudo bootc switch 192.168.1.155:5000/my-kiosk:latest
   sudo bootc status          # Verify "Queued" shows the new image digest
   sudo bootc upgrade
   sudo reboot
   ```

2. After reboot:
   ```
   sudo bootc status          # "Booted" should now show the new image digest
   ```
   - Confirm your incremental change (e.g., test file, version marker) is present.

### 8.2 Rollback Verification
Bootc always keeps the previous deployment for safe rollback.

1. Trigger rollback:
   ```
   sudo bootc rollback
   sudo bootc status          # "Queued" now shows the previous image
   sudo reboot
   ```

2. After reboot:
   ```
   sudo bootc status          # "Booted" back to previous digest
   ```
   - Verify:
     - New changes from the upgrade are **gone** (immutable /usr reverted).
     - Persistent data in `/etc` and `/var` (e.g., configs, logs) remains unchanged.

### 8.3 Multi-Cycle Test (Recommended)
Repeat the cycle with a new version tag (e.g., :alpha9):

1. On host:
   ```
   podman build -t localhost:5000/my-kiosk:alpha9 .
   podman push --tls-verify=false localhost:5000/my-kiosk:alpha9
   ```

2. In VM:
   ```
   sudo bootc switch 192.168.1.155:5000/my-kiosk:alpha9
   sudo bootc upgrade
   sudo reboot
   # Verify new changes
   sudo bootc rollback
   sudo reboot
   # Verify back to previous state
   ```

### 8.4 Expected bootc status Output Examples

**After upgrade (new image applied):**
```
Booted: 192.168.1.155:5000/my-kiosk:latest@sha256:abc123...
Previous: 192.168.1.155:5000/my-kiosk:latest@sha256:old456...
```

**After rollback:**
```
Booted: 192.168.1.155:5000/my-kiosk:latest@sha256:old456...
Previous: 192.168.1.155:5000/my-kiosk:latest@sha256:abc123...
```

Rollback is atomic and safe — you can always go back to the prior known-good state.

This completes the full local development lifecycle: build → push → switch → upgrade → verify → rollback.

Save this updated document — it now includes the critical rollback verification steps that prove the immutability and reliability of your bootc kiosk image.


## Troubleshooting Tips
- If push fails: Check `podman logs local-registry` for "blob unknown" — re-push with `--all-tags`.
- If VM no IP: Check "Cable connected" box, restart NetworkManager (`sudo systemctl restart NetworkManager`).
- Netsh proxy persists, but check with `netsh interface portproxy show v4tov4`.
- For incremental changes: Build/push new tag (e.g., :v2), switch/upgrade.

This procedure ensures a reproducible local registry for bootc upgrades. Save it as a Markdown file for reference. If issues arise, check logs first.

