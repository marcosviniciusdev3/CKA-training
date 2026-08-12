# CKA Advanced Ingress Controller Exercise Progress Tracker

This progress tracker monitors the completion, validation, and scoring of each part of the CKA Advanced Ingress practice exercises defined in [advanced-ingress-cka-exercise.md](file:///home/router/Documents/CKA/cluster3/advanced-ingress-cka-exercise.md).

---

## 📊 Exercise Progress & Scores

| Part | Description | Est. Time | Status | Score | Verification & Comments |
|---|---|---|---|---|---|
| **Part 2** | Host-based multi-tenant routing | 10 min | ✅ Verified | **10 / 10** | Correct Ingresses in `team-a` and `team-b` namespaces with matching hosts and ports. |
| **Part 3** | Shared-host path-routing + rewrite | 15 min | ✅ Verified | **10 / 10** | Correct rewrite target pattern and regex matching annotation. |
| **Part 4** | TLS termination | 10 min | ⚠️ Partial | **7 / 10** | Secret created & TLS terminated. However, root path (/) returns 404 because path is still set to Part 3's regex path. |
| **Part 5** | `pathType` semantics | 10 min | ✅ Verified | **10 / 10** | Correctly split into a separate Ingress without regex annotations. Exact and Prefix match semantics behave properly. |
| **Part 6** | Troubleshooting challenge | 15-20 min| ✅ Verified | **10 / 10** | Successfully resolved service selector, ingressClassName, and service port mismatches. |
| **Bonus** | Canary + NetworkPolicy lockdown | 20-25 min| ⏳ Pending | **0 / 10** | Not yet started. |
| **Total** | | **80-90m** | | **47 / 60** | **Current Grade: 78.3% (Pass mark: 66%)** |

---

## 🔍 Validation Log

### Part 2 — Host-based multi-tenant routing
* **Status**: **PASSED**
* **Score**: 10 / 10
* **Verification Steps Run**:
  1. Listed existing ingress resources in all namespaces:
     ```bash
     kubectl --kubeconfig=.kube/config get ingress -A
     ```
     *Output*:
     * Ingress `team-a` in namespace `team-a` pointing to `web-svc:80` for host `team-a.cka.test`
     * Ingress `team-b` in namespace `team-b` pointing to `web-svc:8080` for host `team-b.cka.test`
  2. Verified HTTP routing using target NodePort `30990`:
     ```bash
     curl -H "Host: team-a.cka.test" http://192.168.0.163:30990/
     # Output: <h1>Hello from Team A</h1> (Status: 200 OK)
     
     curl -H "Host: team-b.cka.test" http://192.168.0.163:30990/
     # Output: <h1>Hello from Team B</h1> (Status: 200 OK)
     ```

> [!NOTE]
> The ingress resources were successfully created as defined in [ingresses.yaml](file:///home/router/Documents/CKA/cluster3/ingresses.yaml) and correctly mapped. Nice job on using namespace-specific Ingress resources to circumvent the namespace boundaries of backend service references!

### Part 3 — Shared-host path-based routing with rewrite
* **Status**: **PASSED**
* **Score**: 10 / 10
* **Verification Steps Run**:
  1. Checked deployed Ingress config:
     ```bash
     kubectl --kubeconfig=.kube/config get ingress -A
     ```
  2. Verified HTTP path routing and prefix stripping using target NodePort `30990`:
     ```bash
     curl -H "Host: apps.cka.test" http://192.168.0.163:30990/team-a
     # Output: <h1>Hello from Team A</h1> (Status: 200 OK)
     
     curl -H "Host: apps.cka.test" http://192.168.0.163:30990/team-b/
     # Output: <h1>Hello from Team B</h1> (Status: 200 OK)
     ```

### Part 4 — TLS termination
* **Status**: **PARTIALLY CORRECT**
* **Score**: 7 / 10
* **Verification Steps Run**:
  1. Verified secret `apps-tls` exists in `team-a` namespace:
     ```bash
     kubectl --kubeconfig=.kube/config get secrets -n team-a
     ```
  2. Verified certificate CN:
     ```bash
     openssl s_client -connect 192.168.0.163:32580 -servername secure.cka.test </dev/null 2>/dev/null | openssl x509 -noout -subject
     # Output: CN=secure.cka.test
     ```
  3. Verified HTTP response code of `https://secure.cka.test/`:
     ```bash
     curl -k --resolve secure.cka.test:32580:192.168.0.163 https://secure.cka.test:32580/
     # Output: 404 Not Found (Should be 200 OK)
     ```

> [!WARNING]
> The path for `team-a` ingress is still configured as `/team-a(/|$)(.*)` with rewrite-target annotations instead of `/` (or `/exact-test` / `/prefix-test`). As a result, visiting the root `https://secure.cka.test/` results in a `404 Not Found` response.

### Part 5 — `pathType` semantics
* **Status**: **PASSED**
* **Score**: 10 / 10
* **Verification Steps Run**:
  1. Checked HTTP response codes and Server headers for exact and prefix matches:
     * `/exact-test` -> **404 Not Found** (Server: `nginx/1.31.3` - **PASSED**. Correctly routed to backend.)
     * `/exact-test/extra` -> **404 Not Found** (Server: `nginx` - **PASSED**. Correctly blocked by Ingress Controller due to `Exact` path matching.)
     * `/prefix-test` -> **404 Not Found** (Server: `nginx/1.31.3` - **PASSED**. Correctly routed to backend.)
     * `/prefix-test/extra` -> **404 Not Found** (Server: `nginx/1.31.3` - **PASSED**. Correctly routed to backend due to `Prefix` path matching.)

> [!NOTE]
> The split was successful! Defining `team-a-subpath` as a separate Ingress resource without the regex annotations allows the Nginx controller to process the standard `pathType: Exact` and `pathType: Prefix` matches exactly according to the Kubernetes specification.

---

## 🚀 Next Steps

### Part 6 — Troubleshooting challenge
* **Status**: **PASSED**
* **Score**: 10 / 10
* **Verification Steps Run**:
  1. Verified endpoint IPs are properly mapped:
     ```bash
     kubectl --kubeconfig=.kube/config get endpoints -n broken-app
     # Output: shop-svc endpoints are mapped to shop deployment pod IPs
     ```
  2. Verified ingress status and class name matching:
     ```bash
     kubectl --kubeconfig=.kube/config get ingress -n broken-app shop-ingress
     # Output: shop-ingress has class nginx and valid address 192.168.0.163
     ```
  3. Verified HTTP/HTTPS response:
     ```bash
     curl -k --resolve shop.cka.test:32580:192.168.0.163 https://shop.cka.test:32580/
     # Output: <h1>Shop is up</h1> (200 OK)
     ```

> [!NOTE]
> All three independent bugs were diagnosed and resolved perfectly:
> 1. Service selector matched correctly with deployment labels (`app: shop`).
> 2. `ingressClassName` corrected from `nginx-controller` to `nginx`.
> 3. Ingress backend target port changed from `8080` to `80` to match the Service port.

---

## 🚀 Next Steps

1. **Fix Part 4 (Optional, for 10/10)**: Update `team-a`'s Ingress for `secure.cka.test` to map path `/` to `web-svc:80` (instead of `/team-a(/|$)(.*)`) and remove the regex/rewrite annotations from that resource.
2. **Start Bonus Section**: Configure Canary release (20% weight split) and NetworkPolicy lockdown.
3. **Update progress**: Let me know when you have completed the Bonus section!
