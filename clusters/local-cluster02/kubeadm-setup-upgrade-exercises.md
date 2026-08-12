# Prerequisites
Control plane IP: 192.168.0.118
Worker IP: 192.168.0.112

# kubeadm Cluster Setup & Upgrade — Practice Exercises

Covers the **Cluster Architecture, Installation & Configuration** domain of the CKA curriculum. Every exercise is written for a **2-node cluster** — one control-plane node, one worker — matching a typical bare-metal or VM practice setup.

Versions used below: **v1.35** as the starting baseline and **v1.36** as the upgrade target (the two most recently supported minors at the time of writing). New minors ship roughly every 4 months, so before you sit down to practice, run `kubeadm upgrade plan` or check `kubernetes.io/releases` and swap in whatever's current — the *process* below doesn't change version to version, only the numbers do.

## How to use this

- Each exercise has a **scenario**, a numbered **task list**, and a **verify** block you run yourself.
- Solutions are collapsed — attempt the task first, then expand.
- Time-box yourself. The real exam gives ~2 hours for 15-20 tasks across all domains; the boxes here are deliberately tight to build that pacing.
- **Exercise Set 1 wipes your cluster.** If you have work on your current cluster you want to keep (e.g. NetworkPolicy configs), snapshot your VMs first or spin up a fresh pair.

---

## Before You Start

**Assumed environment:** 2 Linux VMs (Ubuntu/Debian-based, so `apt`), reachable over SSH, with sudo, unique hostnames, and outbound internet access for package repos. One will be `control-plane`, the other `worker`.

**A gotcha specific to cloned VMs:** kubeadm's preflight checks require every node to have a unique hostname, MAC address, and `product_uuid`. If you built these two VMs by cloning a template, check this *before* you start:

```bash
# Run on both nodes — outputs must differ between them
cat /sys/class/dmi/id/product_uuid
ip link | grep ether
cat /etc/machine-id
```

If any match, regenerate the machine ID on one node:

```bash
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo systemd-machine-id-setup
```

(`product_uuid` collisions need a fix at the hypervisor/template level — you can't regenerate that one from inside the guest.)

---

## Exercise Set 1: Bootstrapping a Cluster From Scratch

### Exercise 1.1 — Prepare Both Nodes
**Time box:** 10 min | **Run on:** both nodes

**Scenario:** Fresh VMs, nothing installed. kubeadm's preflight checks will fail without these OS-level prerequisites in place.

**Tasks:**
1. Disable swap, permanently.
2. Load the `overlay` and `br_netfilter` kernel modules and make that persist across reboots.
3. Set the sysctl params kubeadm's preflight check expects, and apply them.

**Verify:**
```bash
free -h                      # Swap: 0B
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
```

<details>
<summary>💡 Solution</summary>

```bash
# 1. Swap off
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 2. Kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

XXXXXXXXXXXXXXXXXXX
# 3. Sysctl params
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

</details>

---

### Exercise 1.2 — Install and Configure containerd
**Time box:** 10 min | **Run on:** both nodes

**Scenario:** You need a CRI-compliant container runtime before kubelet can start anything.

**Tasks:**
1. Install containerd.
2. Generate its default config and switch the cgroup driver to `systemd` (must match kubelet's cgroup driver — mismatches here are a classic cause of a kubelet that won't start).
3. Enable and restart the service.

**Verify:**
```bash
sudo systemctl status containerd --no-pager
sudo crictl info | grep -i cgroup   # may need: sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
```

<details>
<summary>💡 Solution</summary>

```bash
sudo apt-get update
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Flip SystemdCgroup to true
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

</details>

---

### Exercise 1.3 — Install kubeadm, kubelet, and kubectl
**Time box:** 10 min | **Run on:** both nodes

**Scenario:** You'll target the v1.35 release channel. Package builds get patch-bumped often, so don't hardcode a patch version blind — check what's actually available first.

**Tasks:**
1. Add the `pkgs.k8s.io` apt repo scoped to the v1.35 channel.
2. Check available versions with `apt-cache madison kubeadm` before installing.
3. Install `kubelet`, `kubeadm`, `kubectl`, then pin them with `apt-mark hold` so an unrelated `apt upgrade` can't silently move your cluster to a new minor.

**Verify:**
```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold   # should list kubelet, kubeadm, kubectl
```

<details>
<summary>💡 Solution</summary>

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
apt-cache madison kubeadm | head        # pick the version you want; latest is usually fine

sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

</details>

---

### Exercise 1.4 — Initialize the Control Plane
**Time box:** 10 min | **Run on:** control-plane node only

**Scenario:** Time to stand up the control plane. You'll use Calico later, which expects pod CIDR `192.168.0.0/16` by default — match it now so you don't have to edit Calico's manifest afterward.

**Tasks:**
1. Run `kubeadm init` with a pod network CIDR and an explicit advertise address (don't let it guess your node's IP on a multi-homed VM).
2. **Save the `kubeadm join` command it prints** — you need the token and discovery hash later, and tokens expire after 24 hours.
3. Set up `kubectl` access for your regular (non-root) user.

**Verify:**
```bash
kubectl get nodes                  # control-plane node listed, status NotReady (expected — no CNI yet)
kubectl get pods -n kube-system    # coredns pods Pending (expected, same reason)
```

<details>
<summary>💡 Solution</summary>

```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=<CONTROL_PLANE_NODE_IP>

# Copy the "kubeadm join ..." block from the output somewhere safe.

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

</details>

---

### Exercise 1.5 — Install the CNI (Calico)
**Time box:** 5 min | **Run on:** control-plane node

**Scenario:** The control-plane node is stuck `NotReady` until pod networking exists.

**Tasks:**
1. Apply the Calico manifest.
2. Watch the `kube-system` / `calico-system` pods come up.
3. Confirm the control-plane node flips to `Ready`.

**Verify:**
```bash
kubectl get pods -n kube-system -w
kubectl get nodes    # control-plane -> Ready
```

<details>
<summary>💡 Solution</summary>

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/calico.yaml
```

Check the [Calico releases page](https://github.com/projectcalico/calico/releases) for the current tag if `v3.32.1` has moved on by the time you're reading this. Production clusters are steered toward the Tigera-operator install these days, but the single manifest is simpler for practice and avoids an extra feature-gate requirement the newer CRD-based install needs.

</details>

---

### Exercise 1.6 — Join the Worker Node
**Time box:** 10 min | **Run on:** worker node, command from control-plane

**Scenario:** Your join token may already be stale if you took a break between exercises — tokens expire 24 hours after `kubeadm init`.

**Tasks:**
1. From the control-plane, check whether your saved token is still valid; if not, generate a fresh join command.
2. Run the join command on the worker node.
3. Confirm both nodes show `Ready` from the control-plane.

**Verify:**
```bash
kubectl get nodes -o wide
```

<details>
<summary>💡 Solution</summary>

```bash
# On control-plane — list current tokens
kubeadm token list

# If expired or you didn't save it, generate a new one-liner
kubeadm token create --print-join-command

# On the worker — run whatever that printed, as root
sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

</details>

---

### Exercise 1.7 — Full Cluster Health Check
**Time box:** 10 min | **Run on:** control-plane node

**Scenario:** "Both nodes say Ready" isn't the same as "cluster is actually healthy." Build the habit of checking deeper.

**Tasks:**
1. Confirm every `kube-system` pod is `Running`.
2. List the static pod manifests on the control-plane and match them to the running pods.
3. Check API server component health (`kubectl get componentstatuses` is deprecated — use the raw healthz endpoint instead).
4. Check outstanding bootstrap tokens and certificate expiration dates while you're in here.

**Verify:** this exercise *is* the verification — if all four commands come back clean, you're done.

<details>
<summary>💡 Solution</summary>

```bash
kubectl get pods -n kube-system -o wide

ls /etc/kubernetes/manifests/
# etcd.yaml, kube-apiserver.yaml, kube-controller-manager.yaml, kube-scheduler.yaml

kubectl get --raw='/healthz?verbose'

kubectl cluster-info
kubeadm token list
sudo kubeadm certs check-expiration
```

</details>

---

## Exercise Set 2: Upgrading the Cluster with kubeadm

**Rule that governs everything below:** kubeadm only upgrades **one minor version at a time** (v1.35 → v1.36, never v1.35 → v1.37 directly). Skip-version upgrades aren't supported and kubeadm will refuse.

### Exercise 2.1 — Pre-Upgrade Planning and etcd Backup
**Time box:** 10 min | **Run on:** control-plane node

**Scenario:** Before touching anything, you want a rollback point and a clear picture of what's actually available to upgrade to.

**Tasks:**
1. Confirm current versions across the cluster.
2. Take an etcd snapshot — this is your rollback point if the upgrade goes sideways.
3. Run `kubeadm upgrade plan` and read the output: available target version, and any deprecated-API warnings for your workloads.

**Verify:**
```bash
kubectl get nodes -o wide
ls -lh /opt/backups/    # snapshot file exists and is non-zero size
```

<details>
<summary>💡 Solution</summary>

```bash
kubectl get nodes -o wide
kubeadm version

sudo mkdir -p /opt/backups
sudo ETCDCTL_API=3 etcdctl snapshot save /opt/backups/etcd-pre-upgrade.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

sudo kubeadm upgrade plan
```

</details>

---

### Exercise 2.2 — Upgrade the Control Plane Node
**Time box:** 15 min | **Run on:** control-plane node

**Scenario:** Moving from v1.35 to v1.36. The order below matters — `kubeadm` upgrades cluster components before you touch the node's own kubelet.

**Tasks:**
1. Point apt at the v1.36 channel and upgrade the `kubeadm` package specifically (unhold it first, re-hold after).
2. Run `kubeadm upgrade apply` targeting the new version — this rewrites the control-plane static pod manifests and, by default, renews certificates that are close to expiry.
3. Drain the node.
4. Upgrade `kubelet` and `kubectl`, restart the kubelet service.
5. Uncordon.

**Verify:**
```bash
kubectl get nodes                      # control-plane shows new version
kubectl get pods -n kube-system -o wide
```

<details>
<summary>💡 Solution</summary>

```bash
# Point at the new channel
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

# Upgrade kubeadm itself first
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm
sudo apt-mark hold kubeadm

kubeadm version
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.36.2      # use whatever `upgrade plan` showed you

# Drain before touching kubelet
kubectl drain <control-plane-node-name> --ignore-daemonsets

# Upgrade kubelet/kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet kubectl
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

kubectl uncordon <control-plane-node-name>
```

</details>

---

### Exercise 2.3 — Upgrade the Worker Node
**Time box:** 15 min | **Run on:** worker node + control-plane

**Scenario:** Workers use `kubeadm upgrade node` instead of `upgrade apply` — there's no cluster config to rewrite on a node that isn't running the control plane.

**Tasks:**
1. On the worker, point apt at v1.36 and upgrade the `kubeadm` package.
2. Run `kubeadm upgrade node` on the worker.
3. From the control-plane, drain the worker.
4. On the worker, upgrade `kubelet`/`kubectl` and restart kubelet.
5. From the control-plane, uncordon the worker.

**Verify:**
```bash
kubectl get nodes -o wide    # both nodes on v1.36.x
```

<details>
<summary>💡 Solution</summary>

```bash
# --- On the worker ---
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm
sudo apt-mark hold kubeadm

sudo kubeadm upgrade node

# --- Back on the control-plane ---
kubectl drain <worker-node-name> --ignore-daemonsets --delete-emptydir-data

# --- On the worker again ---
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet kubectl
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

# --- Back on the control-plane ---
kubectl uncordon <worker-node-name>
```

</details>

---

### Exercise 2.4 — Verify the Upgrade End-to-End
**Time box:** 5 min | **Run on:** control-plane node

**Tasks:**
1. Confirm both nodes report the new version.
2. Confirm all workloads rescheduled cleanly (nothing stuck `Pending`/`Evicted` from the drains).
3. Re-check certificate expiration — `kubeadm upgrade apply` renews certs close to expiry by default, so dates should have moved out.

**Verify:**
```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -v Running
sudo kubeadm certs check-expiration
```

<details>
<summary>💡 Solution</summary>

If step 2 shows anything other than completed Jobs, investigate with `kubectl describe pod <name>` before moving on — don't just re-run the drain.

</details>

---

### Exercise 2.5 — Bonus: Feel the Version-Skew Guardrail
**Time box:** 5 min

**Scenario:** You've internalized "one minor at a time" as a rule — now watch kubeadm actually enforce it.

**Task:** With `kubeadm` still at v1.36, try pointing `kubeadm upgrade plan` at a hypothetical two-minors-ahead target and read what it tells you. (Don't force it — this is about reading the guardrail, not bypassing it.)

<details>
<summary>💡 Solution</summary>

`kubeadm upgrade plan` will only ever list the next single minor as an available target — it won't offer a two-minor jump at all, which is the guardrail in action. If you manually specify a too-far-ahead version to `kubeadm upgrade apply`, it refuses with a version-skew error rather than proceeding.

</details>

---

## Exercise Set 3: Troubleshooting & Recovery

### Exercise 3.1 — Recover From an Expired Join Token
**Time box:** 5 min | **Run on:** control-plane node

**Scenario:** You need to add a (hypothetical) third node next week, but your original token is long expired.

**Tasks:**
1. List current tokens and confirm none are valid for a new join.
2. Generate a brand-new token and discovery hash in one step.

<details>
<summary>💡 Solution</summary>

```bash
kubeadm token list
kubeadm token create --print-join-command
```

</details>

---

### Exercise 3.2 — Certificate Expiration and Renewal
**Time box:** 10 min | **Run on:** control-plane node

**Scenario:** kubeadm-managed cluster certs are valid for a year by default. Practice the check-and-renew cycle independent of an upgrade.

**Tasks:**
1. Check expiration dates for every cert kubeadm manages.
2. Renew all of them.
3. Restart the control-plane static pods so they actually pick up the new cert files (renewing doesn't force a pod restart on its own — the manifest content doesn't change, so kubelet won't auto-recreate the pod).
4. Confirm the new expiration dates.

<details>
<summary>💡 Solution</summary>

```bash
sudo kubeadm certs check-expiration

sudo kubeadm certs renew all

# Force the static pods to restart and pick up new certs
cd /etc/kubernetes/manifests
sudo mv kube-apiserver.yaml /tmp/ && sleep 5 && sudo mv /tmp/kube-apiserver.yaml .
sudo mv kube-controller-manager.yaml /tmp/ && sleep 5 && sudo mv /tmp/kube-controller-manager.yaml .
sudo mv kube-scheduler.yaml /tmp/ && sleep 5 && sudo mv /tmp/kube-scheduler.yaml .

sudo kubeadm certs check-expiration    # dates should now be ~1 year out
```

</details>

---

### Exercise 3.3 — Diagnose a Node Stuck NotReady
**Time box:** 10 min | **Run on:** worker node, diagnosis from control-plane

**Scenario:** Simulate a failure you'll actually see in the wild: kubelet dies on a node and doesn't come back on its own.

**Tasks:**
1. On the worker, deliberately stop the kubelet service.
2. From the control-plane, notice and investigate the `NotReady` status.
3. SSH to the worker and find the actual root cause using the kubelet's own logs.
4. Fix it and confirm recovery.

<details>
<summary>💡 Solution</summary>

```bash
# On the worker — simulate the failure
sudo systemctl stop kubelet

# From control-plane — notice it
kubectl get nodes
kubectl describe node <worker-node-name>   # check Conditions and Events

# On the worker — find out why
sudo systemctl status kubelet --no-pager
sudo journalctl -u kubelet -n 100 --no-pager

# Fix (in this drill, it's just a manual stop, so):
sudo systemctl start kubelet
sudo systemctl status kubelet --no-pager

# From control-plane — confirm
kubectl get nodes
```

In a real failure, the journalctl output usually points at the actual cause — a cgroup driver mismatch, a stale CNI config, a full disk, or an expired cert are the common ones worth checking for first.

</details>

---

### Exercise 3.4 — Full Control-Plane Reset and Rejoin
**Time box:** 20 min | **Run on:** control-plane node

**Scenario:** The disaster-recovery drill: your control-plane node is unrecoverable and you're rebuilding it from nothing, worker included.

**Tasks:**
1. Tear the control-plane node down with `kubeadm reset`.
2. Clean up the leftover iptables rules and CNI config it doesn't remove on its own.
3. Re-initialize from scratch (reuse the skills from Exercise Set 1).
4. Rejoin the worker with a fresh token.

<details>
<summary>💡 Solution</summary>

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
rm -rf $HOME/.kube/config

# Then repeat Exercises 1.4 -> 1.6: init, install CNI, generate a fresh join
# command, and rejoin the worker (the worker itself doesn't need a reset
# unless it's also being rebuilt).
```

</details>

---

### Exercise 3.5 — Bonus/Conceptual: Joining a Second Control-Plane Node
**Time box:** conceptual, no time box | **Requires:** a 3rd VM (not part of the 2-node assumption above)

**Scenario:** CKA expects you to understand HA control-plane topology even though most practice setups only have room for one control-plane node.

**Task:** Walk through, on paper or on a spare VM if you have one, what changes versus a normal worker join:
- `kubeadm init` needs `--upload-certs` so control-plane certs can be shared to new CP nodes automatically.
- The join command for a new control-plane node adds `--control-plane --certificate-key <key>` on top of the normal token/hash flags.
- A load balancer (or at minimum a shared DNS name) in front of the API servers is required *before* the first `kubeadm init`, passed via `--control-plane-endpoint` — retrofitting this after the fact is painful, so it has to be decided up front.

<details>
<summary>💡 Solution / talk-through</summary>

```bash
# On the FIRST control-plane node, planning for HA from the start:
sudo kubeadm init \
  --control-plane-endpoint="<LB_DNS_NAME>:6443" \
  --upload-certs \
  --pod-network-cidr=192.168.0.0/16

# Join command for additional control-plane nodes looks like:
sudo kubeadm join <LB_DNS_NAME>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
```

`--upload-certs` certificates expire after 2 hours — if you're joining a second control-plane node later, regenerate with `kubeadm certs upload-certs --upload-certs`.

</details>

---

## Capstone: Timed End-to-End Drill

**Time box: 25 minutes, no solutions provided.** This is exam simulation, not a tutorial.

Starting from two fresh VMs (or two reset ones), get to a fully upgraded 2-node cluster:

1. Prep both nodes, install containerd, install kubeadm/kubelet/kubectl at v1.35.
2. Initialize the control plane, install Calico, join the worker.
3. Immediately upgrade the whole cluster to v1.36, control-plane first, then worker.
4. Finish with `kubectl get nodes -o wide` showing both nodes `Ready` on the new version, and `kubectl get pods -A` showing nothing unhealthy.

If you blow past 25 minutes, note *where* the time went — that's the part to drill again on its own before your next full run.

---

## Quick Reference

```bash
# Bootstrap
kubeadm init --pod-network-cidr=<cidr> --apiserver-advertise-address=<ip>
kubeadm token create --print-join-command
kubeadm join <ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Upgrade (control-plane)
kubeadm upgrade plan
kubeadm upgrade apply v<X.Y.Z>
kubeadm upgrade node          # workers and additional CP nodes

# Node drain cycle (either direction of maintenance)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>

# Certs
kubeadm certs check-expiration
kubeadm certs renew all

# Reset
kubeadm reset -f

# etcd
ETCDCTL_API=3 etcdctl snapshot save <path> \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```
