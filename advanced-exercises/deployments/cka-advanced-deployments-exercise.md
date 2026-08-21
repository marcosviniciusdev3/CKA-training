# CKA Advanced Exercise: Zero-Downtime Deployment, Troubleshooting, and Scheduling Constraints

**Environment:** Any standard Kubernetes cluster (Minikube, KIND, AKS, or bare-metal).
**Focus:** Advanced Deployments, Rolling Update strategies (`maxSurge` / `maxUnavailable`), InitContainers with network checks, Liveness/Readiness probes troubleshooting, ResourceQuotas interactions with rollouts, ServiceAccounts, Pod Anti-Affinity, and Rollout Tracking (`kubernetes.io/change-cause` annotation).

Attempt each task cold before reading its **Verify** block. Solutions are at the bottom — don't peek early.

---

## The Scenario

The finance team is deploying a critical microservice called `payment-gateway` into the `finance-prod` namespace. The deployment must meet the following strict production criteria:
1. **Security**: Run under a dedicated ServiceAccount.
2. **High Availability**: Run with 3 replicas, and ensure zero-downtime updates.
3. **Resilience**: Ensure that pods are distributed across nodes as a best effort (soft anti-affinity) to avoid single points of failure.
4. **Startup Checks**: Wait for the database (`db-service` on port `5432`) to be available before the application container starts.
5. **Health Monitoring**: Monitor both readiness and liveness of the application container.
6. **Resource Isolation**: Operate within a strict ResourceQuota set on the namespace.

A junior administrator attempted to deploy this but the rollout is completely stuck, and several configurations are misaligned. You have been brought in to fix the configuration, debug the environment, and successfully perform a zero-downtime rolling update.

---

## 0. Setup the Initial Environment

Apply the following manifest to set up the namespace, ResourceQuota, and ServiceAccount. Save it as `setup.yaml` and apply it:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: finance-prod
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: finance-quota
  namespace: finance-prod
spec:
  hard:
    pods: "5"
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1000m"
    limits.memory: "1024Mi"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: processor-sa
  namespace: finance-prod
```

Run:
```bash
kubectl apply -f setup.yaml
```

---

## Task 1 — Draft the Deployment Specification

Create a deployment manifest named `payment-gateway.yaml` with the following requirements:
- **Namespace**: `finance-prod`
- **Name**: `payment-gateway`
- **Replicas**: `3`
- **ServiceAccount**: `processor-sa`
- **Strategy**: `RollingUpdate` with `maxSurge: 1`, `maxUnavailable: 0` (Zero Downtime)
- **Labels** (on deployment and pods): `app: payment-gateway`, `tier: backend`
- **Init Container**:
  - Name: `init-db-ping`
  - Image: `busybox:1.36.1`
  - Command: `["sh", "-c", "until nc -z -w 2 db-service 5432; do echo 'waiting for db-service...'; sleep 2; done"]`
- **Main Container**:
  - Name: `web-app`
  - Image: `nginx:1.25.1-alpine`
  - Ports: containerPort `80`
  - Resource Requests: `cpu: 100m, memory: 128Mi`
  - Resource Limits: `cpu: 200m, memory: 256Mi`
  - Liveness Probe: HTTP GET to `/` on port `80`, `initialDelaySeconds: 5`, `periodSeconds: 10`
  - Readiness Probe: HTTP GET to `/healthz` on port `80`, `initialDelaySeconds: 2`, `periodSeconds: 5`
- **Scheduling Constraints**:
  - Use `preferredDuringSchedulingIgnoredDuringExecution` Pod Anti-Affinity with a weight of `100`.
  - The anti-affinity should target pods with label `app: payment-gateway` using the topology key `kubernetes.io/hostname`.

**Verify:** Apply this file to the cluster:
```bash
kubectl apply -f payment-gateway.yaml
```
Verify the pods are created but are stuck in the `Init` state. Why?
Run:
```bash
kubectl get pods -n finance-prod
kubectl describe pod <pod-name> -n finance-prod
```
You should see that the init container is trying to resolve and connect to `db-service`, which does not exist yet.

---

## Task 2 — Resolve the Database Dependency (InitContainer Troubleshooting)

To satisfy the initContainer, you must deploy a mock database service and container.
- Create a Pod named `db-mock` in the namespace `finance-prod` running `postgres:15-alpine`.
- Define an environment variable for the `db-mock` container: `POSTGRES_PASSWORD=supersecret`.
- Create a Service named `db-service` in the namespace `finance-prod` that forwards port `5432` to the `db-mock` pod's port `5432`.

**Verify:** Apply your database manifests.
Watch the `payment-gateway` pods:
```bash
kubectl get pods -n finance-prod -w
```
You should see the init container finish successfully and the main container `web-app` start.
However, are the pods `Ready`? What status are they showing?

---

## Task 3 — Investigate the Stuck Readiness Probe

Even though the main container has started, the pods are showing `0/1` in the `READY` column.
1. Inspect the pod events to find out why.
2. Read the container logs if necessary.
3. Identify why the readiness probe is failing.

**Verify:** Run:
```bash
kubectl describe pod -n finance-prod | grep -i readiness
```
You should see: `Readiness probe failed: HTTP probe failed with statuscode: 404`.
Since you deployed standard `nginx:1.25.1-alpine`, it does not have a `/healthz` endpoint. It returns `404 Not Found` for that path, which Kubernetes interprets as unready.

---

## Task 4 — Perform a Zero-Downtime Fix and Upgrade

To fix the readiness probe issue, you must update the path to `/` (which returns HTTP `200` on standard Nginx).
At the same time, you are asked to upgrade the container image to `nginx:1.25.2-alpine`.

**Requirements for the upgrade:**
1. The update **must** occur with zero downtime. (Verify your strategy block is correct).
2. The rollout change **must** be recorded. Annotate the deployment with the change cause: `"Fix readiness probe and upgrade to nginx:1.25.2-alpine"`.

**Verify:** Update and apply the deployment. Monitor the rollout status:
```bash
kubectl rollout status deployment/payment-gateway -n finance-prod
```
If configured correctly, the rollout will succeed.
Verify the rollout history:
```bash
kubectl rollout history deployment/payment-gateway -n finance-prod
```
You should see the change cause listed for the latest revision.

---

## Task 5 — Understanding the ResourceQuota Gotcha (Advanced Concept)

Look at the ResourceQuota in the `finance-prod` namespace:
- `requests.memory`: `512Mi`

Our deployment has `3` replicas, each requesting `128Mi` of memory.
1. What is the total memory requested by the deployment at rest? (Answer: `3 * 128Mi = 384Mi`).
2. During the rolling update, what is the peak memory request, and why?
   - With `maxSurge: 1` and `maxUnavailable: 0`, Kubernetes spins up a 4th pod before deleting any old pods.
   - Peak memory requested is `4 * 128Mi = 512Mi`. This exactly matches the resource quota!
3. What would happen if you had set resource requests to `150Mi` per pod?
   - The deployment would run at rest (`3 * 150Mi = 450Mi` < `512Mi`).
   - However, a rolling update would attempt to create a 4th pod (`4 * 150Mi = 600Mi`), which exceeds the ResourceQuota.
   - The rolling update would hang indefinitely because the replica set would be blocked from creating the 4th pod.

**Verify:**
Let's simulate this failure.
Temporarily modify the deployment's memory request to `150Mi` and update the image to `nginx:1.25.3-alpine`. Apply the change and watch the rollout.
```bash
kubectl rollout status deployment/payment-gateway -n finance-prod
```
It will hang!
Run `kubectl get events -n finance-prod --sort-by='.metadata.creationTimestamp'` or `kubectl describe replicaset -n finance-prod` to find the quota validation error.
Once verified, revert the memory request back to `128Mi` (or rollback using `kubectl rollout undo deployment/payment-gateway -n finance-prod`) to restore the healthy state.

---

## Cleanup

To clean up all resources created in this exercise:
```bash
kubectl delete namespace finance-prod
```

---

## Solutions Reference

Here are the complete YAML files and command references to solve this exercise.

### `payment-gateway.yaml` (Initial version with deliberate readiness probe failure)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-gateway
  namespace: finance-prod
  labels:
    app: payment-gateway
    tier: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-gateway
      tier: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: payment-gateway
        tier: backend
    spec:
      serviceAccountName: processor-sa
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - payment-gateway
              topologyKey: kubernetes.io/hostname
      initContainers:
      - name: init-db-ping
        image: busybox:1.36.1
        command: ["sh", "-c", "until nc -z -w 2 db-service 5432; do echo 'waiting for db-service...'; sleep 2; done"]
      containers:
      - name: web-app
        image: nginx:1.25.1-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
```

### `db-setup.yaml` (Solution for Task 2)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-mock
  namespace: finance-prod
  labels:
    app: db-mock
spec:
  containers:
  - name: postgres
    image: postgres:15-alpine
    env:
    - name: POSTGRES_PASSWORD
      value: supersecret
    ports:
    - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: db-service
  namespace: finance-prod
spec:
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: db-mock
```

### Task 4 Solution Commands
To fix the readiness probe, edit `payment-gateway.yaml` and change:
```yaml
        readinessProbe:
          httpGet:
            path: /
            port: 80
```
Also change the image to `nginx:1.25.2-alpine`.

Apply the configuration:
```bash
kubectl apply -f payment-gateway.yaml
```

Annotate the deployment to record the change:
```bash
kubectl annotate deployment payment-gateway -n finance-prod kubernetes.io/change-cause="Fix readiness probe and upgrade to nginx:1.25.2-alpine" --overwrite
```

Monitor rollout:
```bash
kubectl rollout status deployment/payment-gateway -n finance-prod
```

### Task 5 Troubleshooting Reference
When you increased memory to `150Mi` and updated the image, you would see replica set events like:
`FailedCreate | (combined from all replica sets) Error creating: pods "payment-gateway-xxxxx" is forbidden: exceeded quota: finance-quota, requested: requests.memory=150Mi, used: requests.memory=450Mi, limited: requests.memory=512Mi`

To fix/rollback:
```bash
kubectl rollout undo deployment/payment-gateway -n finance-prod
```
