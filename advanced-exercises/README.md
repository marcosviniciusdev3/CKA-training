# CKA Advanced Exercises

Welcome to the CKA Advanced Exercises section. These exercises are designed to simulate realistic and challenging CKA (Certified Kubernetes Administrator) scenarios that go beyond basic resource creation. They focus heavily on troubleshooting, environment constraints, and complex configurations.

## Exercises

1. **[Deployments: Zero-Downtime, Troubleshooting, and Affinity](file:///var/home/router/Documents/CKA/advanced-exercises/deployments/cka-advanced-deployments-exercise.md)**
   - **Topics:** `RollingUpdate` strategies (`maxSurge` / `maxUnavailable`), InitContainers network checks, Liveness/Readiness probe troubleshooting, `ResourceQuota` interactions during rollouts, `ServiceAccount` configuration, and pod anti-affinity.
   - **Challenge:** Troubleshoot a stuck rollout caused by a failing init container and a misconfigured readiness probe, under a strict resource quota constraint that limits rollouts.

2. **[Taints & Tolerations on AKS](file:///var/home/router/Documents/CKA/advanced-exercises/taints-and-tolerations/cka-taints-tolerations-exercise.md)**
   - **Topics:** `kubectl taint`, toleration configuration, scheduling effects (`NoSchedule` / `PreferNoSchedule` / `NoExecute`), `tolerationSeconds`, and DaemonSet toleration patterns.
   - **Challenge:** Configure and troubleshoot scheduling blocks using various taint effects and study a real-world AKS-specific behavior with node pool taints.

3. **[Secure Multi-Namespace Networking and NetworkPolicies](file:///var/home/router/Documents/CKA/advanced-exercises/networking/cka-networking-exercise.md)**
   - **Topics:** Network policies, default-deny ingress/egress, DNS resolution egress, cross-namespace ingress matching `namespaceSelector` and `podSelector`, CIDR-based egress restrictions, Service port vs. Pod targetPort troubleshooting, and CNI diagnostics.
   - **Challenge:** Implement a secure multi-namespace network policy setup for a three-tier app. Debug DNS resolution issues caused by default-deny rules, avoid the Service port mismatch trap, and verify CNI node state.

## Side Quests (Incident Drills)

1. **[Side Quest 01 — Incident Alpha: The Broken Logistics Pipeline](file:///var/home/router/Documents/CKA/advanced-exercises/sidequests/sidequest-01-logistics-outage/README.md)**
   - **Topics:** Storage PV/PVC binding mismatches, Scheduling with taints/nodeSelectors, Secret key mapping, Liveness Probes, Service selector discovery, and RBAC least-privilege policies.
   - **Challenge:** Step into an active SEV-1 production outage in namespace `incident-logistics`. Multiple interconnected components are failing or crashlooping. Diagnose and repair all layers to achieve a 100% green verification score.

