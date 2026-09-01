# CKA Progress Log

| Date | Ex # | Exercise | Domain | Score /10 | Notes |
|---|---|---|---|---|---|
| 2026-07-17 | 15 | Gateway API | Services & Networking | 2 | Typo in image name (nginx1.28), need to review CRD structure and routing concepts |
| 2026-07-18 | 16 | HPA | Workloads & Scheduling | 8 | Troubleshot service selector mismatch and a hidden unicode char in HPA scaleTargetRef.name; scaling worked great |
| 2026-07-19 | 17 | kubectl debug | Troubleshooting | 10 | Created ephemeral container with --target=broken-app and ran node debug session cleanly |
| 2026-07-20 | 18 | CRI-dockerd Setup | Cluster Architecture | 10 | Configured CRI-dockerd on VM master01 (192.168.0.130), verified cri-docker socket, systemd services, and node container runtime docker://29.6.2 |
| 2026-07-20 | 19 | Ingress (Classic) | Services & Networking | 10 | Created exercise-19 namespace, web-app & api-app deployments, ClusterIP services, and app-ingress with prefix rules (/ -> web-service:80, /api -> api-service:8080) |
| 2026-07-21 | 20 | Pod Security Standards | Cluster Architecture | 9 | Configured PSS labels (enforce/baseline/audit) on namespaces; identified audit/warn behavior and fixed audit namespace enforce label mismatch |
| 2026-07-21 | 21 | Jobs & CronJobs | Workloads & Scheduling | 9 | Deployed cleanup-job and hourly-backup. Verified completions, logs, and manual triggers. Fixed yaml namespace, busybox image version, and history limits. |
| 2026-07-21 | 23 | Resource Requests Tuning | Workloads & Scheduling | 10 | Debugged and resolved pending pods by tuning memory and CPU requests based on actual allocatable capacity. |
| 2026-07-21 | 24 | PriorityClass Patch | Workloads & Scheduling | 10 | Created high-priority PriorityClass, deployed critical-app, and patched template with priorityClassName. |
| 2026-07-21 | 25 | Storage WaitForFirstConsumer | Storage | 10 | Created StorageClass with WaitForFirstConsumer, local PV, and PVC; verified PVC remains Pending until Pod is scheduled and binds properly. |

## Domain averages
- Services & Networking: 6.0 / 10
- Workloads & Scheduling: 9.25 / 10
- Troubleshooting: 10.0 / 10
- Cluster Architecture: 9.5 / 10
- Storage: 10.0 / 10

## Mock exams
| Date | Exam | Score /15 | Weak questions |
|---|---|---|---|

