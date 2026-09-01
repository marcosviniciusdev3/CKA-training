# CKA Exam Domain Coverage Map

This matrix aligns exercises with official CKA exam domains and weighted percentages. Use this to track your preparation coverage.

## Domain Breakdown (100 min total)

| # | Domain | Official Weight | Exercises | Status | Hours | Notes |
|---|--------|-----------------|-----------|--------|-------|-------|
| 1 | **Storage** (10%) | 10 min | 12, 25 | ✓ | 2-3h | PV/PVC, StorageClass, WaitForFirstConsumer |
| 2 | **Troubleshooting & Debugging** (12%) | 12 min | 11, 17, 29, 30 | ✓ | 2-3h | Logs, events, kubectl debug, etcd, API server |
| 3 | **Workloads & Scheduling** (15%) | 15 min | 02, 06, 07, 16, 21, 22, 23 | ✓ | 3-4h | Pods, Deployments, StatefulSets, HPA, Jobs, Priority |
| 4 | **Services & Networking** (13%) | 13 min | 05, 19, 20, 28 | ✓ | 2-3h | NetworkPolicy, Ingress, DNS, Service mesh intro |
| 5 | **Cluster Architecture** (25%) | 25 min | 04, 08, 09, 10, 13, 18, 24, 26, 27, 30, 31 | ✓ | 4-5h | RBAC, kubeadm, upgrades, etcd, authN/Z, CRI, CNI |
| 6 | **Extra/Exam Techniques** | — | 03, 14, 15, 17 | ✓ | 2h | ConfigMap/Secret, Helm, Kustomize, kubectl debug |

**Total Estimated Time: 15-21 hours of hands-on practice**

---

## Exam Readiness Checklist

### ✓ Storage (10 min / 100 min exam)
- [ ] Exercise 12: PV, PVC, StorageClass basics
- [ ] Exercise 25: WaitForFirstConsumer binding
- **Gotchas:** Namespace mismatch, storageClassName exactness, WFFC timing

### ✓ Troubleshooting (12 min / 100 min exam)
- [ ] Exercise 11: Cluster troubleshooting scenarios
- [ ] Exercise 17: kubectl debug usage
- [ ] Exercise 29: etcd endpoint troubleshooting
- [ ] Exercise 30: TLS configuration issues
- **Gotchas:** Log locations, API server audit logs, certificate paths

### ✓ Workloads & Scheduling (15 min / 100 min exam)
- [ ] Exercise 02: Multi-container pods
- [ ] Exercise 06: Deployment rollout/rollback
- [ ] Exercise 07: StatefulSet fundamentals
- [ ] Exercise 16: HPA with metrics-server
- [ ] Exercise 21: Jobs and CronJobs
- [ ] Exercise 22: PriorityClass usage
- [ ] Exercise 23: Resource requests/limits, tuning
- **Gotchas:** HPA target.type vs averageUtilization, initContainers vs sidecar, Pod disruption budgets

### ✓ Services & Networking (13 min / 100 min exam)
- [ ] Exercise 05: NetworkPolicy basics
- [ ] Exercise 19: Ingress configuration
- [ ] Exercise 20: Pod security standards
- [ ] Exercise 28: Multi-namespace NetworkPolicy, CNI awareness
- **Gotchas:** Egress + ingress both required, DNS rules critical, label case-sensitivity, CNI enforcement variation

### ✓ Cluster Architecture (25 min / 100 min exam)
- [ ] Exercise 04: RBAC (Roles, ClusterRoles, bindings)
- [ ] Exercise 08: Node drain/cordon
- [ ] Exercise 09: kubeadm cluster upgrade
- [ ] Exercise 10: Static pods
- [ ] Exercise 13: Helm chart install/upgrade
- [ ] Exercise 18: CRI-dockerd setup
- [ ] Exercise 24: PriorityClass patch
- [ ] Exercise 26: CRI-dockerd alternative setup
- [ ] Exercise 27: CNI Tigera (Calico) install
- [ ] Exercise 30: TLS certificate configuration
- [ ] Exercise 31: ArgoCD GitOps setup
- **Gotchas:** kubelet config is persistent, kubeadm token expiry (24h), RBAC namespace scoping, static pod node name suffix

### Extra Topics (Complementary)
- [ ] Exercise 03: ConfigMap & Secret management
- [ ] Exercise 14: Kustomize overlays
- [ ] Exercise 15: Gateway API (v1_beta1 concepts)
- [ ] Exercise 17: kubectl debug deep dive

---

## Study Path Recommendations

### **Path A: Exam Simulation (Realistic Order)**
Follow official CKA domain weights → mock exams → focus weak areas

1. Start with **Cluster Architecture** (25%) — sets up cluster fundamentals
2. Then **Workloads & Scheduling** (15%) — most frequent exam questions
3. Then **Services & Networking** (13%) — connectivity scenarios
4. Then **Troubleshooting** (12%) — debugging existing clusters
5. Finally **Storage** (10%) — often time-permitting on exams
6. Use mock exams after each domain

### **Path B: Hands-On Learning (Sequential)**
Follow exercises in order with increasing complexity

1. **Basic Concepts:** 01-03 (Pods, multi-container, ConfigMap)
2. **Cluster Setup:** 04, 08-10, 18, 26-27 (RBAC, nodes, kubeadm, CRI, CNI)
3. **Workloads:** 02, 06-07, 21-23 (Deployments, StatefulSets, Jobs, Priority, HPA)
4. **Networking:** 05, 19-20, 28 (Services, Ingress, NetworkPolicy)
5. **Storage:** 12, 25 (PV/PVC, WFFC)
6. **Advanced:** 13-15, 24, 29-31 (Helm, Kustomize, Gateway API, upgrades, troubleshooting)

### **Path C: Targeted Weak Areas**
Use the matrix to focus on your weakest domain(s)

- Weak at **Storage**? → 12 → 25 → mock exams targeting storage questions
- Weak at **RBAC**? → 04 → 09 (kubeadm) → mock exams
- Weak at **Networking**? → 05 → 28 → 19 → 20 → mock exams

---

## Time Budget (100-minute CKA Exam)

| Domain | Exam Time | Exercise Prep | Total |
|--------|-----------|---------------|-------|
| Storage | 10 min | 2-3h | 2.5-3.5h |
| Troubleshooting | 12 min | 2-3h | 2.5-3.5h |
| Workloads | 15 min | 3-4h | 3.5-4.5h |
| Services & Networking | 13 min | 2-3h | 2.5-3.5h |
| Cluster Architecture | 25 min | 4-5h | 4.5-5.5h |
| **TOTAL** | **75 min** | **13-18h** | **15-21h** |

*Note: 25 min buffer for verification commands and reading questions carefully.*

---

## Assessment: Am I Ready?

### 🟢 Green (Exam Ready)
- Completed all exercises ✓
- Passed all mock exams (70%+ score)
- Can complete 2-3 exercises under timed conditions (15 min per exercise)
- Understand all gotchas in "What tripped me up" sections

### 🟡 Yellow (Almost Ready)
- Completed most exercises
- Struggled with 1-2 domains
- Understand concepts but slow on execution
- **Action:** Focus on timed drills, mock exams

### 🔴 Red (Need More Work)
- Incomplete exercises in 2+ domains
- Struggling with RBAC or networking concepts
- Haven't run mock exams yet
- **Action:** Go back to foundational exercises, don't rush to mock exams
