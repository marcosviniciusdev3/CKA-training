# CKA Advanced Exercise: Secure Multi-Namespace Networking and NetworkPolicies

**Environment:** 2-node local cluster (`localmaster` + `localworker01`) with Calico and Flannel CNIs.
**Focus:** Network policies, default-deny ingress/egress, DNS resolution egress, cross-namespace ingress matching `namespaceSelector` and `podSelector`, CIDR-based egress restrictions, Service port vs. Pod targetPort troubleshooting, and CNI diagnostics.

Attempt each task cold before reading its **Verify** block. Solutions are at the bottom — don't peek early.

---

## The Scenario

An e-commerce platform is deployed on Kubernetes. The platform consists of:
1. **Frontend** application (`frontend`) in the `ecommerce-public` namespace, which needs to be accessible from outside and communicate with the Backend API.
2. **Backend API** application (`backend-api`) in the `ecommerce-internal` namespace. It communicates with the database and an external payment gateway.
3. **Database** (`secure-db`) in the `ecommerce-db` namespace, which holds sensitive transactions.
4. **External Payment Gateway** simulated at the public IP address `8.8.8.8` (representing an external service).

Currently, all namespaces are completely open, meaning any pod can talk to any other pod. The security team requires establishing strict network isolation rules. You must secure this architecture step-by-step using standard Kubernetes `NetworkPolicies`.

---

## 0. Setup the Initial Environment

If you haven't already, apply the setup manifest to create the namespaces, deployments, and services:

```bash
kubectl apply -f setup.yaml
```

Make sure all pods are running across the namespaces:

```bash
kubectl get pods -n ecommerce-public
kubectl get pods -n ecommerce-internal
kubectl get pods -n ecommerce-db
```

---

## Task 1 — Default Deny and CoreDNS Isolation

The security policy dictates that by default, all pods in both `ecommerce-internal` and `ecommerce-db` namespaces reject all ingress and egress traffic, unless explicitly allowed.

1. Write a default-deny ingress and egress NetworkPolicy for the `ecommerce-internal` namespace. Name it `internal-default-deny`.
2. Write a default-deny ingress and egress NetworkPolicy for the `ecommerce-db` namespace. Name it `db-default-deny`.
3. Apply these policies. Observe that doing so immediately breaks CoreDNS resolution for the pods (e.g. testing `nslookup` or `ping` will fail) and explain why.
4. Update the policies (or write helper policies) to explicitly allow egress to the CoreDNS pods (running in the `kube-system` namespace on UDP and TCP port 53).
   - *Hint:* CoreDNS pods typically have the label `k8s-app: kube-dns`.

**Verify:**
Apply the default-deny policies. Confirm that pods can no longer resolve DNS or communicate.
Then, apply the CoreDNS egress rule and verify that DNS resolution (e.g. resolving `kubernetes.default.svc.cluster.local`) works again from a pod in `ecommerce-internal`:

```bash
kubectl exec -it -n ecommerce-internal deploy/backend-api -- nslookup kubernetes.default.svc.cluster.local
```

---

## Task 2 — Secure Database Ingress (Cross-Namespace Rules)

Configure a NetworkPolicy in the `ecommerce-db` namespace named `db-ingress-policy`.

1. The policy must target the database pod `secure-db` (labeled `app: secure-db`).
2. It must allow incoming TCP traffic on port `5432` only.
3. The incoming traffic must be restricted **only** to pods with the label `app: backend-api` that are running in the `ecommerce-internal` namespace.
4. *Important exam catch:* Standard Kubernetes NetworkPolicies combine `namespaceSelector` and `podSelector` under a single list item for an `AND` operation, or separate list items for an `OR` operation. Ensure your policy represents an `AND` operation (i.e. only backend-api pods AND only inside ecommerce-internal namespace).
5. Check if the namespace `ecommerce-internal` has the required labels. If it doesn't, how do you select it? (Hint: Kubernetes auto-labels namespaces with `kubernetes.io/metadata.name: <namespace>`, or you can use custom labels).

**Verify:**
1. Test connectivity from the `backend-api` pod in `ecommerce-internal` to the database:
   ```bash
   kubectl exec -it -n ecommerce-internal deploy/backend-api -- nc -z -v -w 3 db-svc.ecommerce-db.svc.cluster.local 5432
   ```
   This should succeed (`open` or `connection established`).
2. Test connectivity from the `frontend` pod in `ecommerce-public` to the database:
   ```bash
   kubectl exec -it -n ecommerce-public deploy/frontend -- nc -z -v -w 3 db-svc.ecommerce-db.svc.cluster.local 5432
   ```
   This should hang or fail (connection timed out), because the frontend is not allowed to communicate with the DB.

---

## Task 3 — CIDR Egress and Payment Gateway Control

The `backend-api` pods inside the `ecommerce-internal` namespace require access to:
1. CoreDNS in the `kube-system` namespace on UDP/TCP port 53 (already handled or must be included).
2. The Database service in `ecommerce-db` on TCP port 5432.
3. The external payment gateway at the public IP `8.8.8.8` on TCP port `443`.

All other egress traffic (including to other external IPs, or to the `frontend` pod, or to other services in the cluster) must be blocked.

1. Write a NetworkPolicy named `backend-egress-policy` in the `ecommerce-internal` namespace.
2. Target the `backend-api` pods (labeled `app: backend-api`).
3. Explicitly allow egress to the DB pods on port 5432.
4. Explicitly allow egress to the CoreDNS pods on port 53.
5. Explicitly allow egress to `8.8.8.8/32` on port 443 using `ipBlock`.
6. Ensure all other egress is denied.

**Verify:**
1. Test egress to the payment gateway (simulated TCP connect to `8.8.8.8:443`):
   ```bash
   kubectl exec -it -n ecommerce-internal deploy/backend-api -- nc -z -v -w 3 8.8.8.8 443
   ```
   (Note: This might timeout if there's no actual listener on 8.8.8.8:443, but the network layer should attempt the connection. Contrast this with a blocked connection).
2. Test egress to another external IP (e.g. `1.1.1.1` on port 443):
   ```bash
   kubectl exec -it -n ecommerce-internal deploy/backend-api -- nc -z -v -w 3 1.1.1.1 443
   ```
   This must fail immediately or timeout due to the policy block (typically prints `nc: 1.1.1.1 (1.1.1.1:443): Connection timed out` after 3 seconds).

---

## Task 4 — Backend Ingress (The Service Port vs Pod Port Trap)

The frontend pods in `ecommerce-public` namespace need to talk to the backend api Service.
The backend API service `backend-svc` is defined as:
- Service Port: `8080`
- TargetPort (Pod Port): `80`

1. Create a NetworkPolicy named `backend-ingress-policy` in `ecommerce-internal` namespace.
2. Allow ingress from pods in the `ecommerce-public` namespace.
3. Which port should you specify in the NetworkPolicy's `ports` section?
   - *Trap:* NetworkPolicies act at the IP/routing level directly on the Pods. They do not understand Kubernetes Service abstractions. The Service receives traffic on port `8080` and performs DNAT to port `80` on the Pod. Therefore, the NetworkPolicy must allow traffic on the **containerPort (80)**, NOT the Service port (8080).
4. Write and apply this policy.

**Verify:**
Test connectivity from a `frontend` pod to the backend Service:
```bash
kubectl exec -it -n ecommerce-public deploy/frontend -- wget -qO- --timeout=3 http://backend-svc.ecommerce-internal.svc.cluster.local:8080
```
This should succeed and print the default Nginx welcome page.

---

## Task 5 — CNI and Flannel+Calico Diagnosis

Since this cluster uses Flannel for VxLAN encapsulation and Calico for NetworkPolicy enforcement, troubleshoot and check the status of the network components:

1. Query the CNI plugin settings. Where is the active CNI config file located on the nodes?
2. Run a command to list the pod CIDRs allocated to each node in the cluster.
3. Inspect the `calico-node` DaemonSet logs on the worker node to verify it is running correctly and enforcing policies.

**Verify:**
Explain how Calico policies are applied (IPTables/eBPF on the host nodes) and confirm that `calico-node` is actively running.

---

## Cleanup

To clean up the resources created for this exercise:

```bash
kubectl delete ns ecommerce-public ecommerce-internal ecommerce-db
```

---

## Solutions Reference

### Task 1 — Default Deny and CoreDNS Isolation

To implement default-deny ingress and egress, apply the following policies:

`internal-default-deny.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: internal-default-deny
  namespace: ecommerce-internal
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

`db-default-deny.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-default-deny
  namespace: ecommerce-db
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Why does DNS break?**
DNS queries in Kubernetes are resolved by CoreDNS pods. These pods are located in the `kube-system` namespace. By default-denying all egress in our namespaces, pods can no longer send UDP/TCP packets on port 53 to CoreDNS. Since name resolution fails, all domain-based lookups (like `db-svc.ecommerce-db.svc.cluster.local`) will fail.

**Allowing DNS Egress:**
To fix this, we allow egress traffic to CoreDNS. CoreDNS runs in the `kube-system` namespace and has the label `k8s-app: kube-dns`. Note that we MUST use `namespaceSelector: {}` to allow matching across namespaces (otherwise it matches only the policy's namespace).

`allow-dns-egress.yaml` (Apply to both namespaces)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: ecommerce-internal
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {} # Match pods in all namespaces (crucial for cross-namespace)
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```
*(Apply a similar policy in `ecommerce-db` if database pods ever need DNS, though here the database is isolated and does not initiate connections).*

---

### Task 2 — Secure Database Ingress (Cross-Namespace Rules)

Standard Kubernetes NetworkPolicies combine namespace and pod selectors. 
- An OR constraint is written as separate array items:
  ```yaml
  # This matches pods in the current namespace OR any pods in the specified namespace
  from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ecommerce-internal
  - podSelector:
      matchLabels:
        app: backend-api
  ```
- An AND constraint is written as a single array item with multiple keys:
  ```yaml
  # This matches ONLY pods with the label 'app: backend-api' inside the namespace 'ecommerce-internal'
  from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ecommerce-internal
    podSelector:
      matchLabels:
        app: backend-api
  ```

Since Kubernetes 1.21, namespaces are auto-labeled with `kubernetes.io/metadata.name`. We can use this label to select the namespace without needing to manually label it.

`db-ingress-policy.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-ingress-policy
  namespace: ecommerce-db
spec:
  podSelector:
    matchLabels:
      app: secure-db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ecommerce-internal
      podSelector:
        matchLabels:
          app: backend-api
    ports:
    - protocol: TCP
      port: 5432
```

Apply this manifest. Egress is still default-denied, and ingress is only allowed from `backend-api` in `ecommerce-internal` namespace.

---

### Task 3 — CIDR Egress and Payment Gateway Control

To restrict `backend-api` egress to only the Database, CoreDNS, and the Payment Gateway, configure the following policy. It combines pod selectors, namespace selectors, and `ipBlock`.

`backend-egress-policy.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress-policy
  namespace: ecommerce-internal
spec:
  podSelector:
    matchLabels:
      app: backend-api
  policyTypes:
  - Egress
  egress:
  # 1. Allow Egress to CoreDNS
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # 2. Allow Egress to secure-db in ecommerce-db namespace
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ecommerce-db
      podSelector:
        matchLabels:
          app: secure-db
    ports:
    - protocol: TCP
      port: 5432
  # 3. Allow Egress to simulated Payment Gateway (8.8.8.8)
  - to:
    - ipBlock:
        cidr: 8.8.8.8/32
    ports:
    - protocol: TCP
      port: 443
```

---

### Task 4 — Backend Ingress (The Service Port vs Pod Port Trap)

The frontend connects to `http://backend-svc.ecommerce-internal.svc.cluster.local:8080`.
The `backend-svc` listens on port `8080` and redirects to containerPort `80`.
Kubernetes NetworkPolicies apply to **traffic arriving at the Pod interface**, which has already gone through DNAT on the host node. Thus, the destination port matching is done against the **containerPort (80)**. Allowing port 8080 in the policy would result in blocked traffic because the packet arriving at the pod interface has a destination port of 80.

`backend-ingress-policy.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-ingress-policy
  namespace: ecommerce-internal
spec:
  podSelector:
    matchLabels:
      app: backend-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ecommerce-public
    ports:
    - protocol: TCP
      port: 80 # MUST match containerPort, not Service port 8080!
```

---

### Task 5 — CNI and Flannel+Calico Diagnosis

1. **CNI Configuration Directory**:
   By default, the active CNI config file is located in `/etc/cni/net.d/` on each Kubernetes node. For a Calico+Flannel (Canal) setup, you would find configuration files such as `10-canal.conflist` or `10-calico.conflist` here. Since `sudo` is unavailable on Debian nodes in this lab, you can inspect how CNI is configured by looking at the DaemonSet configuration or mounting `/etc/cni/net.d` into a privileged troubleshooting pod to view files if you have cluster-admin privileges.

2. **Retrieve Node Pod CIDRs**:
   You can view the Pod CIDR allocated to each node in the cluster by querying the node spec:
   ```bash
   kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
   ```
   *Expected output style:*
   ```text
   localmaster     10.244.0.0/24
   localworker01   10.244.1.0/24
   ```

3. **Inspect CNI Logs**:
   To inspect Calico daemon status and logs, check the pods in `calico-system` (or `kube-system` in some clusters):
   ```bash
   kubectl get pods -n calico-system
   kubectl logs -n calico-system daemonset/calico-node -c calico-node
   ```
   Calico acts as the policy engine by managing host iptables rules or eBPF programs, while Flannel acts as the data plane overlay (VxLAN) forwarding packets between nodes.
