# Advanced Ingress Controller Exercise — CKA Practice

**Format:** Task descriptions, not copy-paste YAML — write the manifests yourself, then check against the Solutions section at the bottom. This mirrors how Ingress questions actually show up on the exam.

**Assumed environment:** your 2-node kubeadm cluster (bare-metal style, no cloud LoadBalancer) — commands below use NodePort access accordingly. Swap in your own node IP / ports where noted.

> **Before you start — a heads-up for mid-2026:** the community `ingress-nginx` project (the controller this exercise uses) completed its planned retirement in March 2026 — best-effort maintenance ended, the repo is now archived/read-only, and there won't be further releases or security patches. Nothing below is affected by that: existing install artifacts remain available and everything here installs and behaves exactly as documented. For exam purposes, the Ingress API itself is **not** deprecated (just "feature-frozen"), and it's still core, tested material — several current study guides for the v1.35 curriculum note that Gateway API was added to the Services & Networking domain *alongside* Ingress, not instead of it. So this is still time well spent.

## What you're practicing

| Part | Skill | Est. time | Exam domain |
|---|---|---|---|
| 0–1 | Controller install, starting state | 10 min | Services & Networking |
| 2 | Host-based routing, multi-namespace | 10 min | Services & Networking |
| 3 | Path-based routing + regex rewrite | 15 min | Services & Networking |
| 4 | TLS termination | 10 min | Services & Networking |
| 5 | `pathType` semantics | 10 min | Services & Networking |
| 6 | Troubleshooting a broken Ingress | 15–20 min | **Troubleshooting** (highest-weighted domain) |
| Bonus | Canary + NetworkPolicy lockdown | 20–25 min | Services & Networking (stretch, nginx-specific) |

---

## Part 0 — Install the controller

Check whether it's already running:

```bash
kubectl get pods -n ingress-nginx
```

If not, install the bare-metal provider manifest (this variant creates a NodePort Service by default, which is what you want without a cloud LB or MetalLB):

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/baremetal/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

Capture your access variables once — you'll reuse these throughout:

```bash
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
export HTTP_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
export HTTPS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo "$NODE_IP $HTTP_PORT $HTTPS_PORT"
```

Confirm the IngressClass exists:

```bash
kubectl get ingressclass
```

---

## Part 1 — Starting state (given)

Apply this as-is — it's your backend infrastructure, already deployed, same as a real exam question would hand you:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
---
apiVersion: v1
kind: Namespace
metadata:
  name: team-b
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
  namespace: team-a
data:
  index.html: |
    <h1>Hello from Team A</h1>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: team-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: content
              mountPath: /usr/share/nginx/html
      volumes:
        - name: content
          configMap:
            name: web-content
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: team-a
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
  namespace: team-b
data:
  index.html: |
    <h1>Hello from Team B</h1>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: team-b
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: content
              mountPath: /usr/share/nginx/html
      volumes:
        - name: content
          configMap:
            name: web-content
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: team-b
spec:
  selector:
    app: web
  ports:
    - port: 8080
      targetPort: 80
```

Notice team-b's Service is deliberately exposed on port **8080**, not 80. Read backend ports carefully in every task below — don't assume.

---

## Part 2 — Task: host-based multi-tenant routing

**Requirement:** requests to `team-a.cka.test` should reach team-a's app; requests to `team-b.cka.test` should reach team-b's app.

**The catch:** an Ingress object can only reference Services in its *own* namespace — there's no cross-namespace backend reference in the core Ingress API. Since `team-a` and `team-b` are separate namespaces, this means **two separate Ingress objects** (one per namespace), each handled by the same shared ingress-nginx controller. Write both.

Validate:

```bash
curl -H "Host: team-a.cka.test" http://$NODE_IP:$HTTP_PORT/
curl -H "Host: team-b.cka.test" http://$NODE_IP:$HTTP_PORT/
```

---

## Part 3 — Task: shared-host path-based routing with rewrite

**Requirement:** under a single shared hostname `apps.cka.test`, route:
- `/team-a` (and anything under it) → team-a's app, with the `/team-a` prefix stripped before it reaches the backend
- `/team-b` (and anything under it) → team-b's app, same stripping behavior

Since the backend nginx containers don't know about the `/team-a` or `/team-b` prefix, you'll need a rewrite annotation with a regex capture group, plus the annotation that turns regex matching on. Again: this needs one Ingress object per namespace (same host, different path each), not one combined object.

Validate:

```bash
curl -H "Host: apps.cka.test" http://$NODE_IP:$HTTP_PORT/team-a
curl -H "Host: apps.cka.test" http://$NODE_IP:$HTTP_PORT/team-b/
```

Both should return their respective team's page, not a 404 from nginx looking for `/team-a/index.html` literally.

---

## Part 4 — Task: TLS termination

**Requirement:** serve team-a's app over HTTPS at `secure.cka.test`, terminating TLS at the ingress controller.

Steps:
1. Generate a self-signed cert for CN `secure.cka.test`.
2. Create a TLS secret from it **in the `team-a` namespace** (the secret must live in the same namespace as the Ingress that references it).
3. Write an Ingress with a `tls:` block referencing that secret and host.

Validate (self-signed, so `-k` to skip verification; `--resolve` handles SNI correctly, which a bare `-H "Host:"` header does not for TLS):

```bash
curl -k --resolve secure.cka.test:$HTTPS_PORT:$NODE_IP https://secure.cka.test:$HTTPS_PORT/team-a
```

Also confirm the cert nginx actually presents matches what you created:

```bash
openssl s_client -connect $NODE_IP:$HTTPS_PORT -servername secure.cka.test </dev/null 2>/dev/null | openssl x509 -noout -subject
```

---

## Part 5 — Task: `pathType` behavior

Add two more paths to team-a's Ingress (reuse the existing `web-svc` backend for both — this task is purely about matching behavior, not new backends):

- `/exact-test` with `pathType: Exact`
- `/prefix-test` with `pathType: Prefix`

Before testing, write down what you expect for each of these four requests, then test and compare:

```bash
curl -o /dev/null -s -w "%{http_code}\n" -H "Host: team-a.cka.test" http://$NODE_IP:$HTTP_PORT/exact-test
curl -o /dev/null -s -w "%{http_code}\n" -H "Host: team-a.cka.test" http://$NODE_IP:$HTTP_PORT/exact-test/extra
curl -o /dev/null -s -w "%{http_code}\n" -H "Host: team-a.cka.test" http://$NODE_IP:$HTTP_PORT/prefix-test
curl -o /dev/null -s -w "%{http_code}\n" -H "Host: team-a.cka.test" http://$NODE_IP:$HTTP_PORT/prefix-test/extra
```

If your predictions don't match the results, that's the point of the exercise — figure out why before reading the solution.

---

## Part 6 — Troubleshooting challenge

Apply this manifest exactly as written:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: broken-app
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: shop-content
  namespace: broken-app
data:
  index.html: |
    <h1>Shop is up</h1>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
  namespace: broken-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shop
  template:
    metadata:
      labels:
        app: shop
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: content
              mountPath: /usr/share/nginx/html
      volumes:
        - name: content
          configMap:
            name: shop-content
---
apiVersion: v1
kind: Service
metadata:
  name: shop-svc
  namespace: broken-app
spec:
  selector:
    app: shopfront
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop-ingress
  namespace: broken-app
spec:
  ingressClassName: nginx-controller
  rules:
    - host: shop.cka.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: shop-svc
                port:
                  number: 8080
```

**Requirement:** `curl -H "Host: shop.cka.test" http://$NODE_IP:$HTTP_PORT/` currently fails. There are **three independent bugs**. Find and fix all of them using `kubectl describe`, `kubectl get endpoints`, and `kubectl get ingressclass` — don't just diff against Part 1's working manifests. Fix them one at a time and re-test; each fix should change the symptom, not just silently resolve everything at once.

---

## Bonus (stretch, beyond core CKA scope) — Canary release + NetworkPolicy lockdown

This combines two Services & Networking topics that show up together in real clusters, even though the canary mechanism below is nginx-specific rather than a portable Ingress API feature.

**Canary:** deploy a second version of team-a's app (different response text so you can tell them apart) behind its own Service, then create a *second* Ingress object for `team-a.cka.test` with canary annotations at a 20% weight pointing to the new Service. Fire ~30 requests in a loop and tally how many hit each version — expect roughly an 80/20 split, not exactly 20% (small sample size).

**NetworkPolicy lockdown:** you've already done a NetworkPolicy exercise, so this should feel familiar — restrict team-a's `web` pods so they only accept traffic on port 80 from pods in the `ingress-nginx` namespace (every namespace carries an automatic `kubernetes.io/metadata.name` label you can match on, no manual labeling needed). Confirm:
- a `curl`/`wget` from a temporary pod in another namespace, direct to the Service, now times out
- traffic through the Ingress still works exactly as before

If your CNI doesn't enforce NetworkPolicy, you'll be able to apply the YAML but won't see the blocking behavior — treat it as manifest-writing practice in that case.

---

## Validation checklist

- [ ] `team-a.cka.test` and `team-b.cka.test` each return their own team's page
- [ ] `apps.cka.test/team-a` and `apps.cka.test/team-b` both work with the prefix stripped
- [ ] `secure.cka.test` serves HTTPS with your self-signed cert
- [ ] `/exact-test` vs `/prefix-test` behavior matches the documented `pathType` semantics
- [ ] `shop.cka.test` returns "Shop is up" after fixing all three bugs
- [ ] (Bonus) canary split is roughly 80/20
- [ ] (Bonus) direct cross-namespace access is blocked; ingress access still works

---

## Solutions

Try everything above first — these are here to check your work, not to read ahead.

### Part 2

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team-a-host
  namespace: team-a
spec:
  ingressClassName: nginx
  rules:
    - host: team-a.cka.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team-b-host
  namespace: team-b
spec:
  ingressClassName: nginx
  rules:
    - host: team-b.cka.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port:
                  number: 8080   # team-b's Service port, not 80
```

**Speed tip for the real exam:** the imperative form covers simple cases faster than writing full YAML:
```bash
kubectl create ingress team-a-host -n team-a --class=nginx --rule="team-a.cka.test/*=web-svc:80"
```

### Part 3

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team-a-path
  namespace: team-a
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: apps.cka.test
      http:
        paths:
          - path: /team-a(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: web-svc
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team-b-path
  namespace: team-b
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: apps.cka.test
      http:
        paths:
          - path: /team-b(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: web-svc
                port:
                  number: 8080
```

`pathType: Prefix` is deliberately wrong here — Prefix does strict element-wise matching and isn't meant to carry regex; `ImplementationSpecific` is what tells Kubernetes "let the controller interpret this path however it wants," which is what lets nginx's regex engine take over.

### Part 4

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure.cka.test"

kubectl create secret tls secure-tls -n team-a --cert=tls.crt --key=tls.key
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team-a-tls
  namespace: team-a
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - secure.cka.test
      secretName: secure-tls
  rules:
    - host: secure.cka.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port:
                  number: 80
```

### Part 5

```yaml
          - path: /exact-test
            pathType: Exact
            backend:
              service:
                name: web-svc
                port:
                  number: 80
          - path: /prefix-test
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port:
                  number: 80
```

Expected results: `/exact-test` → 200, `/exact-test/extra` → 404 (Exact matches the literal string only), `/prefix-test` → 200, `/prefix-test/extra` → 200 (Prefix matches element-wise on anything below it).

### Part 6 — the three bugs

1. **Service selector mismatch:** `shop-svc` selects `app: shopfront`, but the Deployment's pods are labeled `app: shop`. Result: `kubectl get endpoints -n broken-app shop-svc` shows no addresses. Fix the selector to `app: shop`.
2. **Wrong IngressClass:** `ingressClassName: nginx-controller` doesn't match any real IngressClass (`kubectl get ingressclass` shows `nginx`). The controller silently never adopts this Ingress — no `ADDRESS` ever appears. Fix to `ingressClassName: nginx`.
3. **Wrong backend port:** the Ingress references port `8080`, but `shop-svc` actually serves on port `80`. Once bugs 1 and 2 are fixed you'd get a 502/503 from this alone. Fix to `number: 80`.

Diagnosis sequence that gets you here:
```bash
kubectl get ingress -n broken-app shop-ingress    # empty ADDRESS -> class problem
kubectl get ingressclass                          # confirm real class name
kubectl get endpoints -n broken-app shop-svc       # empty -> selector problem
kubectl get pods -n broken-app --show-labels       # compare against the Service selector
kubectl describe ingress -n broken-app shop-ingress # backend service/port + events
```

### Bonus

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-canary-content
  namespace: team-a
data:
  index.html: |
    <h1>Hello from Team A (CANARY v2)</h1>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-canary
  namespace: team-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-canary
  template:
    metadata:
      labels:
        app: web-canary
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          volumeMounts:
            - name: content
              mountPath: /usr/share/nginx/html
      volumes:
        - name: content
          configMap:
            name: web-canary-content
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc-canary
  namespace: team-a
spec:
  selector:
    app: web-canary
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team-a-canary
  namespace: team-a
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "20"
spec:
  ingressClassName: nginx
  rules:
    - host: team-a.cka.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc-canary
                port:
                  number: 80
```

Test the split:
```bash
for i in $(seq 1 30); do curl -s -H "Host: team-a.cka.test" http://$NODE_IP:$HTTP_PORT/; echo; done | sort | uniq -c
```

NetworkPolicy:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-only
  namespace: team-a
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: 80
```

Test the block:
```bash
kubectl run test-pod --rm -it --image=busybox:1.36 --restart=Never -n default -- \
  wget -qO- --timeout=3 http://web-svc.team-a.svc.cluster.local
```
This should now time out, while `curl` through the Ingress (Part 2) still works.
