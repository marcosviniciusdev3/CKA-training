# CKA Advanced Exercise: Taints & Tolerations on AKS

**Environment:** 2-node-pool AKS cluster (`systempool` + `devpool`)
**Focus:** `kubectl taint`, toleration YAML, effects (`NoSchedule` / `PreferNoSchedule` / `NoExecute`), `tolerationSeconds`, `Exists` vs `Equal`, DaemonSets, and one real AKS gotcha that trips people up in practice.

Attempt each task cold before reading its **Verify** block. Solutions are at the bottom — don't peek early.

---

## 0. Fix and apply the Terraform

Your original file had a duplicated/corrupted resource block and a stray `=`. It also mixed AKS's **Automatic** provisioning mode (`node_provisioning_profile { default_node_pools = "Auto" }`) with manually-defined pools, which is contradictory — Automatic mode manages node pools for you and doesn't expect a hand-rolled `devpool` alongside it. I removed that block. I also turned on `only_critical_addons_enabled` on the system pool — this is the standard AKS practice of tainting the system pool so only critical system pods land there, and it becomes relevant in Task 1.

```hcl
resource "azurerm_kubernetes_cluster" "aks_cluster01" {
  name                = "aks-cluster01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-cluster01"

  default_node_pool {
    name                          = "systempool"
    node_count                    = 1
    vm_size                       = "Standard_B2s"
    os_sku                        = "Ubuntu"
    only_critical_addons_enabled  = true
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "devpool" {
  name                  = "devpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster01.id
  vm_size               = "Standard_B2s"
  node_count            = 1
  os_sku                = "Ubuntu"

  node_labels = {
    environment = "development"
  }
}
```

Apply it, then pull credentials:

```bash
terraform apply
az aks get-credentials --resource-group <your-rg> --name aks-cluster01 --overwrite-existing
kubectl get nodes -o wide
```

---

## Task 1 — Read the taints that are already there

Before adding anything, inspect what's on each node.

```bash
kubectl describe node <systempool-node> | grep -A2 Taints
kubectl describe node <devpool-node> | grep -A2 Taints
```

**Question to answer for yourself:** which node currently rejects ordinary pods, and why? (`only_critical_addons_enabled` is your clue.)

**Verify:** the systempool node should show `CriticalAddonsOnly=true:NoSchedule`. The devpool node should show `<none>`.

---

## Task 2 — Taint devpool and watch scheduling fail

Imperatively taint the devpool node so only pods that explicitly tolerate it can land there:

```bash
kubectl taint nodes <devpool-node> dedicated=devteam:NoSchedule
```

Now deploy a plain nginx deployment with **no tolerations**:

```bash
kubectl create deployment frontend --image=nginx --replicas=2
kubectl get pods -o wide
```

**Question:** where do the pods go?

**Verify:** they should stay `Pending`. Run `kubectl describe pod <pod>` and read the Events — you'll see something like `0/2 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 1 node(s) had untolerated taint {dedicated: devteam}`. With this Terraform setup, **every node** now rejects untolerated pods — a realistic scenario you'll hit on the exam when a cluster's taints are misconfigured.

---

## Task 3 — Fix it with a toleration

Edit the deployment (or `kubectl patch`) to add a toleration for `dedicated=devteam:NoSchedule`, matching with `Equal`:

```yaml
tolerations:
- key: "dedicated"
  operator: "Equal"
  value: "devteam"
  effect: "NoSchedule"
```

**Verify:** `kubectl get pods -o wide` — pods should now schedule onto the devpool node (a toleration lets them land there; it does **not** force them there — note this distinction, it's a common exam trap. Nothing stopped them from landing on systempool too, except that systempool's taint is still untolerated).

---

## Task 4 — PreferNoSchedule (the soft effect)

Add a second, soft taint to devpool:

```bash
kubectl taint nodes <devpool-node> environment=nonprod:PreferNoSchedule
```

Scale `frontend` up by a couple replicas without adding a toleration for this new taint.

**Verify:** the new pods should still schedule onto devpool (they have nowhere else to go anyway) because `PreferNoSchedule` is advisory, not a hard block — the scheduler avoids the node only when a better option exists. Contrast this with Task 2's `NoSchedule` behavior.

---

## Task 5 — NoExecute and tolerationSeconds

This is the effect most people get wrong on the exam because it acts on *already-running* pods, not just new ones.

```bash
kubectl taint nodes <devpool-node> maintenance=true:NoExecute
```

**Verify immediately:** `kubectl get pods -o wide --watch` — your existing `frontend` pods on devpool (which don't tolerate `maintenance`) should be evicted within seconds.

Now create a single pod that tolerates the eviction but only temporarily:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: temp-worker
spec:
  tolerations:
  - key: "maintenance"
    operator: "Equal"
    value: "true"
    effect: "NoExecute"
    tolerationSeconds: 30
  - key: "dedicated"
    operator: "Equal"
    value: "devteam"
    effect: "NoSchedule"
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
```

**Verify:** the pod schedules and runs, then gets evicted ~30 seconds after it starts (not 30 seconds from taint-time — the countdown starts when the pod is running under the taint). Watch with `kubectl get pod temp-worker -w` and note the timestamp gap between `Running` and `Terminating`.

---

## Task 6 — `Exists` vs `Equal`

Taint devpool again, this time with no value:

```bash
kubectl taint nodes <devpool-node> reserved-for-team:NoSchedule
```

Write a toleration using `operator: Exists` (no `value` field) instead of `Equal`, and explain to yourself why `Equal` would fail here.

**Verify:** a toleration with `operator: Equal` and no `value` is invalid — `Equal` requires matching `value`. `Exists` matches on key alone, ignoring value, so it's the only one that tolerates this taint.

---

## Task 7 — Tolerate everything (the DaemonSet pattern)

Real cluster DaemonSets (like `kube-proxy`) must run on every node regardless of taints. Write a DaemonSet manifest for a dummy log collector (`busybox`, `sleep 3600`) that tolerates **all** taints on **all** nodes, using the "tolerate everything" idiom:

```yaml
tolerations:
- operator: "Exists"
```

**Verify:** `kubectl get pods -o wide -l <your-label>` shows one pod per node, including systempool and the fully-tainted devpool node.

---

## Bonus — the AKS-specific gotcha

Move `devpool`'s taints into Terraform instead of applying them imperatively:

```hcl
node_taints = [
  "dedicated=devteam:NoSchedule"
]
```

Run `terraform plan`.

**What to notice:** changing `node_taints` on an AKS node pool forces a **replacement** of the node pool (`-/+` in the plan), not an in-place update — unlike a plain `kubectl taint`, which is instant but gets silently reconciled away by AKS on the next node pool sync/upgrade if it's not also declared in Terraform. This is the real-world reason production AKS clusters define taints at the node pool level: `kubectl taint` is fine for CKA practice, but it isn't durable on managed node pools.

---

## Cleanup

```bash
kubectl delete deployment frontend
kubectl delete pod temp-worker
kubectl delete daemonset <your-log-collector>
kubectl taint nodes <devpool-node> dedicated- environment- maintenance- reserved-for-team-
```

---

## Solutions reference

| Task | Command/key concept |
|---|---|
| 1 | `only_critical_addons_enabled` → `CriticalAddonsOnly=true:NoSchedule` |
| 2 | `kubectl taint nodes <node> dedicated=devteam:NoSchedule` |
| 3 | `tolerations: [{key: dedicated, operator: Equal, value: devteam, effect: NoSchedule}]` |
| 4 | `PreferNoSchedule` is soft — scheduler avoids but doesn't block |
| 5 | `tolerationSeconds` counts from pod start under the taint, not taint-apply time |
| 6 | `Exists` ignores value; `Equal` requires it |
| 7 | `tolerations: [{operator: Exists}]` tolerates any key/effect |
| Bonus | `node_taints` change on an AKS pool = forced replacement in Terraform |
