# Self-Grading Rubric for CKA Exercises

Use this rubric to evaluate your work on each exercise. This helps you identify gaps before attempting mock exams.

## Grading Scale

| Score | Interpretation | Action |
|-------|-----------------|--------|
| **9-10** | ✓ Mastered | Move to next exercise |
| **7-8** | ✓ Competent | Review gotchas, move on |
| **5-6** | ⚠ Partial | Reattempt exercise, watch for mistakes |
| **3-4** | ✗ Weak | Study hints, reattempt with guidance |
| **0-2** | ✗ Failed | Start over, read full solution first |

---

## Exercise-by-Exercise Rubric

### Exercise 01 — Pod Basics

**9-10 (Mastered):**
- [ ] Pod runs immediately after `kubectl apply`
- [ ] Can list, describe, and exec into pod
- [ ] Multi-line command in pod works (pipes, redirects)
- [ ] Can delete and recreate pod in < 2 minutes
- [ ] Understand why imperative vs declarative matters

**7-8 (Competent):**
- [ ] Pod runs but took experimenting with YAML
- [ ] Basic kubectl commands work (get, describe, exec)
- [ ] Can write simple pod manifest from scratch
- [ ] Minor hesitation on describe output interpretation

**5-6 (Partial):**
- [ ] Pod created but took multiple attempts
- [ ] Basic kubectl commands work but slow
- [ ] Needed hints for multi-line commands
- [ ] Confused about pod restart policies

**Below 5:** Rework the exercise, review the hints section.

---

### Exercise 02 — Multi-Container Pod

**9-10 (Mastered):**
- [ ] Sidecar and app container both running
- [ ] Can exec into each container independently
- [ ] Understand shared volume mounting and data flow
- [ ] Know when to use initContainers vs sidecars
- [ ] Can debug pod state with describe/logs

**7-8 (Competent):**
- [ ] Both containers running, volumes mounted correctly
- [ ] Exec works but needed to look up syntax
- [ ] Volumes share data as expected
- [ ] One container took a couple tries

**5-6 (Partial):**
- [ ] Both containers eventually got running
- [ ] Volume sharing worked but took debugging
- [ ] Uncertain about shared vs init containers
- [ ] Described pod but missed key details

**Below 5:** Review volumes and multi-container concepts, re-read the solution.

---

### Exercise 03 — ConfigMap & Secret

**9-10 (Mastered):**
- [ ] ConfigMap created and mounted as volume + env var
- [ ] Secret mounted with correct file permissions
- [ ] Pod reads both ConfigMap and Secret successfully
- [ ] Understand difference between mount styles (env vs volume)
- [ ] Can encode/decode Secret YAML by inspection

**7-8 (Competent):**
- [ ] ConfigMap and Secret both accessible from pod
- [ ] Mounted correctly but needed reference
- [ ] Basic encoding/decoding understood
- [ ] One of env-var or volume mount took tinkering

**5-6 (Partial):**
- [ ] Pod references both ConfigMap and Secret
- [ ] Data accessible but mounting style confused
- [ ] Debugging took multiple attempts
- [ ] Unsure about pod-restart on ConfigMap change

**Below 5:** Study the hints, re-run with solutions open.

---

### Exercise 04 — RBAC

**9-10 (Mastered):**
- [ ] ServiceAccount, Role, RoleBinding all created
- [ ] `k auth can-i` returns "yes" and "no" correctly
- [ ] ClusterRole/ClusterRoleBinding works for cluster-scoped resources
- [ ] Understand namespace scoping (Role vs ClusterRole)
- [ ] Can explain RBAC decision flow

**7-8 (Competent):**
- [ ] All RBAC resources created and functional
- [ ] `auth can-i` queries mostly correct
- [ ] Understand namespace vs cluster scope
- [ ] One binding type took troubleshooting

**5-6 (Partial):**
- [ ] RBAC resources created but didn't verify thoroughly
- [ ] `auth can-i` queries partially correct
- [ ] Confused about scope or needed hints
- [ ] Didn't understand why/when to use ClusterRole

**Below 5:** RBAC is heavily tested. Re-read the entire exercise and solutions.

---

### Exercise 05 — NetworkPolicy

**9-10 (Mastered):**
- [ ] All ingress/egress rules work correctly
- [ ] Cross-pod traffic blocked/allowed as expected
- [ ] DNS egress maintained
- [ ] Understand that ingress + egress both needed
- [ ] Label selectors applied perfectly

**7-8 (Competent):**
- [ ] NetworkPolicies created and mostly function
- [ ] One traffic direction took debugging
- [ ] Label matching mostly correct
- [ ] DNS egress understood after hints

**5-6 (Partial):**
- [ ] Policies created but complex interactions unclear
- [ ] Had to test extensively to verify correctness
- [ ] Forgot DNS egress initially
- [ ] Label selector mistakes found during testing

**Below 5:** NetworkPolicy is exam-critical. Study labels, ingress/egress carefully.

---

### Exercise 06 — Deployment Rollout & Rollback

**9-10 (Mastered):**
- [ ] Deployment rolls out successfully
- [ ] `kubectl rollout history` shows revisions
- [ ] `kubectl rollout undo` restores prior version
- [ ] RollingUpdate strategy understood
- [ ] Can trace changes through generation/revision

**7-8 (Competent):**
- [ ] Rollout and rollback work
- [ ] History and undo commands used correctly
- [ ] Minor confusion about revision history
- [ ] One strategy option took clarification

**5-6 (Partial):**
- [ ] Rollout works but slow to verify
- [ ] Rollback works but unclear on mechanics
- [ ] Generation/revision concept fuzzy
- [ ] Needed to review strategy options

**Below 5:** Review rolling updates, revisions, and rollback mechanics.

---

### Exercise 07 — StatefulSet

**9-10 (Mastered):**
- [ ] StatefulSet creates ordered, stable pod names
- [ ] Persistent storage retained after pod restart
- [ ] Pod scaled up/down in order
- [ ] Understand StatefulSet identity guarantees
- [ ] Can predict pod naming scheme

**7-8 (Competent):**
- [ ] StatefulSet running, pods stable
- [ ] Storage persisted with restarts
- [ ] Understand ordered startup but slow to predict names
- [ ] One scaling scenario took thinking

**5-6 (Partial):**
- [ ] StatefulSet created but identity guarantees unclear
- [ ] Storage works but unsure about replicas impact
- [ ] Pod naming confused with Deployment
- [ ] Needed hints on scaling behavior

**Below 5:** StatefulSet concepts are important. Re-study identity and ordering.

---

### Exercise 08 — Node Drain & Cordon

**9-10 (Mastered):**
- [ ] `kubectl cordon` prevents new pods
- [ ] `kubectl drain` evicts existing pods
- [ ] PodDisruptionBudget respected
- [ ] Node marked Unschedulable/SchedulingDisabled
- [ ] Understand cluster upgrade workflow

**7-8 (Competent):**
- [ ] Drain and cordon work correctly
- [ ] Pods evicted as expected
- [ ] Understand Unschedulable state
- [ ] Missed PodDisruptionBudget interaction

**5-6 (Partial):**
- [ ] Commands work but output interpretation fuzzy
- [ ] Unsure about eviction vs deletion
- [ ] Didn't verify node state after drain
- [ ] PodDisruptionBudget unfamiliar

**Below 5:** Review node lifecycle and eviction policies.

---

### Exercise 09 — kubeadm Cluster Upgrade

**9-10 (Mastered):**
- [ ] Upgrade follows kubeadm steps exactly
- [ ] Control plane upgraded before worker nodes
- [ ] Version skew limits understood (n, n-1, n-2)
- [ ] `kubeadm upgrade plan` output interpreted correctly
- [ ] Can explain why upgrade order matters

**7-8 (Competent):**
- [ ] Upgrade succeeds with reference
- [ ] Understand upgrade sequence
- [ ] Version compatibility mostly clear
- [ ] One step needed re-reading docs

**5-6 (Partial):**
- [ ] Upgrade completed but didn't fully verify
- [ ] Confused about version compatibility
- [ ] Missed upgrade plan/apply distinction
- [ ] Worker node upgrade took trial-and-error

**Below 5:** Cluster upgrades are complex and exam-critical. Study step-by-step carefully.

---

### Exercise 10 — Static Pod

**9-10 (Mastered):**
- [ ] Pod appears in `kubectl get pods` within 3 seconds
- [ ] Understand that kubelet manages static pods
- [ ] Cannot delete via kubectl (correctly tries and fails)
- [ ] Pod name includes node name suffix
- [ ] Know kubectl delete recreates; must delete manifest

**7-8 (Competent):**
- [ ] Static pod working
- [ ] Understand kubelet ownership
- [ ] Deletion attempt made correctly
- [ ] Minor confusion on pod naming

**5-6 (Partial):**
- [ ] Pod created but took debugging
- [ ] Tried to delete via kubectl multiple times
- [ ] Wasn't sure about pod name format
- [ ] Manifest placement took trial

**Below 5:** Understand that static pods are kubelet-managed, not API-server-managed.

---

### Exercise 11 — Troubleshoot Cluster

**9-10 (Mastered):**
- [ ] Found all issues in < 15 minutes
- [ ] Understood root cause for each issue
- [ ] Can read logs, events, and describe output efficiently
- [ ] Know where control plane logs live
- [ ] Understand etcd and API server logs

**7-8 (Competent):**
- [ ] Found most issues with brief debugging
- [ ] Log reading effective
- [ ] Small hesitation on one scenario
- [ ] Understand logging locations mostly

**5-6 (Partial):**
- [ ] Found some issues, others took help
- [ ] Log reading slow or incomplete
- [ ] One scenario's root cause unclear
- [ ] Didn't check all usual suspect files

**Below 5:** Troubleshooting is 12% of exam. Practice log reading systematically.

---

### Exercise 12 — Storage: PV, PVC, StorageClass ⭐ IMPORTANT

**9-10 (Mastered):**
- [ ] PVC immediately shows "Bound" status
- [ ] Pod consuming PVC runs immediately
- [ ] Understand that Pod Pending = PVC not Bound or storage unready
- [ ] StorageClass names must match exactly
- [ ] Reclaim policy (Retain vs Delete) tested and verified
- [ ] Know that pod-PVC-namespace mismatch breaks the pod

**7-8 (Competent):**
- [ ] PVC and Pod eventually work
- [ ] Understand binding and reclaim
- [ ] Namespace scoping mostly clear
- [ ] One or two attempts needed

**5-6 (Partial):**
- [ ] Got it working but trial-and-error
- [ ] Didn't understand why Pod was Pending
- [ ] StorageClass name matching frustrating
- [ ] Didn't verify Pod lifecycle fully

**Below 5:** Storage is 10% of exam. Re-do this exercise, understand PVC Pending = Pod Pending.

---

### Exercise 13 — Helm Install & Upgrade

**9-10 (Mastered):**
- [ ] Helm chart installed and resources created
- [ ] Values override works correctly
- [ ] Understand helm upgrade adds/modifies resources
- [ ] Can inspect installed resources with helm get
- [ ] Know difference between rollback and upgrade

**7-8 (Competent):**
- [ ] Helm chart works with reference
- [ ] Install and upgrade succeed
- [ ] Minor confusion on values syntax
- [ ] Understand basic helm workflow

**5-6 (Partial):**
- [ ] Helm commands work but slowly
- [ ] Values override took debugging
- [ ] Unclear on helm vs kubectl for updates
- [ ] Didn't fully verify resource state

**Below 5:** Review helm templating and values override syntax.

---

### Exercise 14 — Kustomize Overlays

**9-10 (Mastered):**
- [ ] Overlays apply patches correctly
- [ ] Base resources inherited and modified
- [ ] `kubectl kustomize` output verified before apply
- [ ] Understand 3-way merge and strategic merge patches
- [ ] Can predict final YAML from base + overlay

**7-8 (Competent):**
- [ ] Kustomize works with some trial
- [ ] Patches applied mostly correctly
- [ ] Understand base and overlay concept
- [ ] One patch type needed clarification

**5-6 (Partial):**
- [ ] Kustomize output looked right but unsure
- [ ] Patches partially worked
- [ ] Didn't fully understand patch syntax
- [ ] Verification step incomplete

**Below 5:** Review kustomization.yaml syntax and patch strategies.

---

### Exercise 15 — Gateway API (v1beta1 Concepts)

**9-10 (Mastered):**
- [ ] Gateway and HTTPRoute created and functional
- [ ] Traffic routes to services as configured
- [ ] Understand Gateway vs Route hierarchy
- [ ] Know difference from Ingress (v1 vs v1beta1)
- [ ] Gateway listeners configured correctly

**7-8 (Competent):**
- [ ] Gateway API resources working
- [ ] Routes functional with reference
- [ ] Understand basic routing
- [ ] Minor confusion on listener config

**5-6 (Partial):**
- [ ] Resources created but unsure if correct
- [ ] Traffic flow took debugging
- [ ] Gateway API purposes unclear
- [ ] Didn't fully understand resource relationships

**Below 5:** Gateway API is newer; review CRD structure and routing concepts.

---

### Exercise 16 — Horizontal Pod Autoscaler ⭐ IMPORTANT

**9-10 (Mastered):**
- [ ] HPA created with correct `target.type: Utilization`
- [ ] Pod has `resources.requests.cpu` set (or <unknown> will appear)
- [ ] Load increases pod count; decrease reduces count
- [ ] Understand scale-down delay (5 min default)
- [ ] Can verify target.type and averageUtilization in YAML

**7-8 (Competent):**
- [ ] HPA works and scales pods
- [ ] Understand CPU-based scaling
- [ ] Resource requests understood after reference
- [ ] Scale-down timing caught your attention

**5-6 (Partial):**
- [ ] HPA created but metrics showed <unknown>
- [ ] Forgot resource requests
- [ ] Scaling worked but verification incomplete
- [ ] Didn't check HPA YAML structure

**Below 5:** HPA is exam-critical. Study target.type=Utilization requirement specifically.

---

### Exercise 17 — kubectl debug

**9-10 (Mastered):**
- [ ] `kubectl debug` creates ephemeral container correctly
- [ ] Can run troubleshooting tools inside target pod
- [ ] Understand ephemeral vs permanent containers
- [ ] Exit cleanly without leaving container
- [ ] Know when kubectl debug is better than exec

**7-8 (Competent):**
- [ ] kubectl debug works after reference
- [ ] Ephemeral container concept understood
- [ ] Troubleshooting commands functional
- [ ] Minor hesitation on cleanup

**5-6 (Partial):**
- [ ] kubectl debug command worked but felt awkward
- [ ] Unsure about ephemeral container benefits
- [ ] Didn't know you could use different image
- [ ] Questioned if necessary vs kubectl exec

**Below 5:** Review kubectl debug syntax and ephemeral container use cases.

---

### Exercise 18 — CRI-dockerd Setup

**9-10 (Mastered):**
- [ ] CRI-dockerd installed and verified
- [ ] Kubelet points to CRI-dockerd socket correctly
- [ ] Pods run under CRI-dockerd runtime
- [ ] Understand kubelet → CRI → dockerd flow
- [ ] Can verify with `crictl ps`

**7-8 (Competent):**
- [ ] CRI-dockerd setup works
- [ ] Pods running on correct runtime
- [ ] Kubelet config update done correctly
- [ ] One configuration step needed re-reading

**5-6 (Partial):**
- [ ] CRI-dockerd installed but verification lacking
- [ ] Kubelet config change wasn't verified
- [ ] Unclear how CRI differs from containerd
- [ ] Didn't check pod runtime

**Below 5:** Review CRI socket configuration and kubelet startup flags.

---

### Exercise 19 — Ingress (Classic)

**9-10 (Mastered):**
- [ ] Ingress routes traffic to correct service
- [ ] Host-based and path-based rules work
- [ ] Can test with `curl -H "Host:..."` or /etc/hosts
- [ ] Understand Ingress → Service → Pod flow
- [ ] Know difference between Ingress Controller and Ingress resource

**7-8 (Competent):**
- [ ] Ingress working with minor debugging
- [ ] Routing rules functional
- [ ] Path and host routing mostly understood
- [ ] One routing scenario needed verification

**5-6 (Partial):**
- [ ] Ingress created but routing took work
- [ ] Host/path rules confused initially
- [ ] Verification commands not well understood
- [ ] Didn't test with curl fully

**Below 5:** Review Ingress path types (Prefix vs Exact) and rule ordering.

---

### Exercise 20 — Pod Security Standards

**9-10 (Mastered):**
- [ ] PSS policy applied to namespace correctly
- [ ] Restricted policy enforced (blocks privileged, hostPath, etc.)
- [ ] Pod violations caught and understood
- [ ] Understand enforce vs audit vs warn modes
- [ ] Can modify pod to pass restricted policy

**7-8 (Competent):**
- [ ] PSS policy applied correctly
- [ ] Violations caught and understood
- [ ] Enforce/audit modes mostly clear
- [ ] Minor confusion on specific violations

**5-6 (Partial):**
- [ ] PSS policy applied but mechanism unclear
- [ ] Didn't fully understand which rules violated
- [ ] Enforce vs audit modes fuzzy
- [ ] Didn't attempt pod repair

**Below 5:** Review Pod Security Standards admission and violation rules.

---

### Exercise 21 — Jobs & CronJobs

**9-10 (Mastered):**
- [ ] Job completes successfully and pods removed
- [ ] CronJob triggers on schedule reliably
- [ ] Understand Job restart policy and backoffLimit
- [ ] Can read CronJob execution history
- [ ] Understand TTL and cleanup mechanics

**7-8 (Competent):**
- [ ] Job and CronJob functional
- [ ] Understand execution and completion
- [ ] Schedule syntax mostly clear
- [ ] One restart behavior took clarification

**5-6 (Partial):**
- [ ] Job and CronJob work after debugging
- [ ] Completion verification incomplete
- [ ] Restart policy confused
- [ ] Didn't check execution history

**Below 5:** Review Job completion, backoff, and CronJob schedule format.

---

### Exercise 22 — PriorityClass

**9-10 (Mastered):**
- [ ] PriorityClass created with correct global name
- [ ] Pod assigned PriorityClass and scheduled first
- [ ] Lower-priority pod can be preempted
- [ ] Understand preemption behavior
- [ ] Know default priority (0)

**7-8 (Competent):**
- [ ] PriorityClass works and scheduling affected
- [ ] Preemption observed or understood
- [ ] Global name understood
- [ ] One priority concept took rethinking

**5-6 (Partial):**
- [ ] PriorityClass created but preemption unclear
- [ ] Scheduling behavior took observation
- [ ] Global name requirement confused initially
- [ ] Didn't fully verify priority effect

**Below 5:** Review PriorityClass global scope and preemption mechanics.

---

### Exercise 23 — Resource Requests & Limits

**9-10 (Mastered):**
- [ ] Requests affect scheduling (pod Pending if unmet)
- [ ] Limits affect eviction (pod OOMKilled if exceeded)
- [ ] QoS classes understood (Guaranteed, Burstable, BestEffort)
- [ ] Understand CPU throttling vs memory pressure
- [ ] Can predict QoS class from request/limit config

**7-8 (Competent):**
- [ ] Requests and limits work correctly
- [ ] Scheduling and eviction behavior verified
- [ ] QoS classes mostly understood
- [ ] One request/limit scenario took thought

**5-6 (Partial):**
- [ ] Requests and limits set but behavior unclear
- [ ] Confused scheduling vs eviction
- [ ] QoS classes not well understood
- [ ] Didn't test edge cases

**Below 5:** Review QoS classes and resource behavior carefully.

---

### Exercise 25 — Storage: WaitForFirstConsumer

**9-10 (Mastered):**
- [ ] PVC stays Pending until Pod references it
- [ ] Storage bound only after Pod scheduled
- [ ] Understand node affinity is preserved
- [ ] Can explain WFFC use case (storage locality)
- [ ] Pod immediately Ready after binding

**7-8 (Competent):**
- [ ] WFFC behavior observed correctly
- [ ] PVC stays Pending as expected
- [ ] Pod Ready after binding
- [ ] Use case mostly understood

**5-6 (Partial):**
- [ ] WFFC created but timing behavior unclear
- [ ] Didn't fully understand Pending-then-Bound sequence
- [ ] Use case fuzzy
- [ ] Verification incomplete

**Below 5:** Storage is 10% of exam. WFFC is important detail.

---

### Exercise 28 — Complex NetworkPolicy ⭐ IMPORTANT

**9-10 (Mastered):**
- [ ] Multi-namespace policies work correctly
- [ ] Cross-namespace ServiceSelector applied
- [ ] Ingress + egress both required for bidirectional
- [ ] DNS egress allowed from all namespaces
- [ ] Understand CNI enforcement variation
- [ ] Label matching case-sensitive and exact

**7-8 (Competent):**
- [ ] Policies created and mostly work
- [ ] Cross-namespace mostly understood
- [ ] DNS egress remembered after hints
- [ ] One policy type needed debugging

**5-6 (Partial):**
- [ ] Policies created but mechanism unclear
- [ ] Traffic blocked worked but why
- [ ] Label selector mistakes discovered during testing
- [ ] CNI concepts not encountered

**Below 5:** NetworkPolicy is 13% of exam. Re-study bidirectional requirements and label matching.

---

### Exercise 29 — Troubleshoot etcd Endpoint

**9-10 (Mastered):**
- [ ] Found etcd issues (endpoint health, certs, etc.)
- [ ] Used `etcdctl` correctly with TLS/auth
- [ ] Understand why etcd health matters
- [ ] Know where etcd certs live (/etc/kubernetes/pki/etcd/)
- [ ] Understand backup/restore mechanics

**7-8 (Competent):**
- [ ] Etcd issues found with some trial
- [ ] etcdctl basic commands work
- [ ] TLS setup mostly understood
- [ ] One etcd concept needed clarification

**5-6 (Partial):**
- [ ] Etcd investigation took debugging
- [ ] etcdctl syntax was awkward
- [ ] Certificate locations unclear
- [ ] Didn't fully understand health implications

**Below 5:** Troubleshooting is 12% of exam. Practice etcd troubleshooting commands.

---

### Exercise 30 — TLS Configuration Update

**9-10 (Mastered):**
- [ ] Updated API server certificate correctly
- [ ] Kubelet and API server mutual TLS verified
- [ ] Understand certificate paths and rotation
- [ ] Can check certificate expiration
- [ ] Know certificate formats (PEM, DER)

**7-8 (Competent):**
- [ ] Certificate updated and verified working
- [ ] TLS communication restored
- [ ] Certificate concepts mostly clear
- [ ] One certificate detail took reference

**5-6 (Partial):**
- [ ] Certificate updated but verification incomplete
- [ ] Confused about cert vs key
- [ ] Didn't check certificate validity
- [ ] TLS troubleshooting fuzzy

**Below 5:** Cluster security is 25% of exam. Review certificate structure and paths.

---

### Exercise 31 — ArgoCD GitOps Setup

**9-10 (Mastered):**
- [ ] ArgoCD installed and accessible
- [ ] Application synced from Git repository
- [ ] Understand GitOps principles (Git as source of truth)
- [ ] Can trigger sync and rollback
- [ ] Know ArgoCD Application CRD structure

**7-8 (Competent):**
- [ ] ArgoCD setup works with reference
- [ ] Application syncs correctly
- [ ] GitOps concepts mostly understood
- [ ] One ArgoCD command needed lookup

**5-6 (Partial):**
- [ ] ArgoCD installed but workflow unclear
- [ ] Application config took debugging
- [ ] GitOps benefits not obvious
- [ ] Didn't explore ArgoCD UI fully

**Below 5:** Review ArgoCD Application manifest and sync mechanics.

---

## Overall Exam Readiness Score

Sum your scores for each exercise (max 10 per exercise), then divide by number of exercises:

```
Total Score = (Ex01 + Ex02 + ... + Ex31) / 31
```

| Overall Score | Exam Readiness |
|---------------|----------------|
| **9-10** | 🟢 Ready to test — take mock exams, then real exam |
| **7-8** | 🟡 Good foundation — focus on mock exams, weak areas |
| **5-6** | 🟠 Needs work — complete any <70% exercises, then mock exams |
| **<5** | 🔴 Not ready — rework foundations, gaps too large |

---

## Common Red Flags ⚠️

If you score < 5 on ANY of these exercises, **focus there before mock exams:**

- ✗ Exercise 04 (RBAC) — 25% of exam depends on RBAC
- ✗ Exercise 12 (Storage/PVC) — 10% of exam, PVC behavior misunderstood is critical
- ✗ Exercise 16 (HPA) — target.type confusion common
- ✗ Exercise 28 (NetworkPolicy) — bidirectional requirements confuse many
- ✗ Exercise 09 (kubeadm upgrade) — complex, high exam weight

If stuck on these, spend time on them — don't rush to mock exams.
