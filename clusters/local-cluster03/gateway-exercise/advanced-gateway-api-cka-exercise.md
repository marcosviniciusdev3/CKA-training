# Advanced Gateway API Exercise — CKA Practice

**Format:** same as the Ingress exercise — task descriptions, not copy-paste YAML. Write the manifests yourself, check against Solutions at the bottom.

**Assumed environment:** your 2-node kubeadm cluster. Unlike Ingress, the core Ingress API ships built into Kubernetes — Gateway API is the opposite: the CRDs and an actual implementation (controller) are both separate installs you do yourself. This exercise uses **Envoy Gateway**, a CNCF reference-quality implementation, and accesses everything through `kubectl port-forward` rather than NodePort/MetalLB, so there's no extra load-balancer setup required.

## What you're practicing

| Part | Skill | Est. time | Exam domain |
|---|---|---|---|
| 0–1 | CRD + controller install, starting state | 15 min | Services & Networking |
| 2 | Gateway + HTTPRoute basics, namespace-scoped attachment | 15 min | Services & Networking |
| 3 | Cross-namespace backend refs via `ReferenceGrant` | 15 min | Services & Networking |
| 4 | Path-based routing with `URLRewrite` (portable, no annotations) | 10 min | Services & Networking |
| 5 | Native traffic splitting via weighted `backendRefs` | 10 min | Services & Networking |
| 6 | TLS termination at the Gateway listener | 10 min | Services & Networking |
| 7 | Troubleshooting a broken Gateway/HTTPRoute pair | 20 min | **Troubleshooting** (highest-weighted domain) |
| Bonus | `TCPRoute`, regex path matching (newer/niche) | 15 min | Stretch |

---

## Part 0 — Install the Gateway API CRDs and Envoy Gateway

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml

kubectl get crds | grep gateway.networking.k8s.io
```
You should see CRDs including `gatewayclasses`, `gateways`, `httproutes`, `grpcroutes`, `referencegrants`, and `tcproutes` — check the exact list your install produced rather than assuming.

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.8.2 -n envoy-gateway-system --create-namespace

kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

(If either version tag 404s by the time you run this, check the current release on the [Gateway API releases page](https://github.com/kubernetes-sigs/gateway-api/releases) and [Envoy Gateway's quickstart](https://gateway.envoyproxy.io/docs/tasks/quickstart/) — both projects ship frequently.)

---

## Part 1 — Starting state (given)

Apply this as-is:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: v1
kind: Namespace
metadata:
  name: gw-infra
---
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

`gw-infra` represents the "cluster operator" persona in Gateway API's RBAC model — it'll own the shared Gateway that `team-a` and `team-b` (the "application developer" persona) attach routes to. This split is one of the real differences from Ingress, where there's no separate infra-owned object at all.

---

## Part 2 — Task: shared Gateway + basic HTTPRoutes

**Requirement:** create a Gateway named `shared-gateway` in `gw-infra` with a single HTTP listener on port 80. It should **only** accept routes from namespaces you've explicitly opted in — not from every namespace in the cluster. Then create one HTTPRoute per team, each attaching to this Gateway for its own hostname (`team-a.gw.test`, `team-b.gw.test`), each routing to its own local Service.

Think about what mechanism restricts which namespaces a Gateway's listener accepts routes from — it isn't `ReferenceGrant` (that's for cross-namespace backend references, which Part 3 covers). You'll need to label the `team-a` and `team-b` namespaces to match whatever selector you put in the Gateway spec.

Set up access once, reused for the rest of the exercise:

```bash
export ENVOY_SVC=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=gw-infra,gateway.envoyproxy.io/owning-gateway-name=shared-gateway \
  -o jsonpath='{.items[0].metadata.name}')
kubectl -n envoy-gateway-system port-forward svc/$ENVOY_SVC 8080:80 8443:443 &
```

Validate:

```bash
curl -H "Host: team-a.gw.test" http://localhost:8080/
curl -H "Host: team-b.gw.test" http://localhost:8080/
```

Also check the HTTPRoute's own status, not just curl output:

```bash
kubectl get httproute -A -o wide
kubectl describe httproute -n team-a
```

---

## Part 3 — Task: cross-namespace backend with `ReferenceGrant`

**Requirement:** in a new namespace `reports` (label it the same way you labeled team-a/team-b so it can attach to the Gateway), create an HTTPRoute for `cross.gw.test` that routes to team-a's `web-svc` — **not** a Service that lives in `reports` itself.

This is the one that would have been outright impossible with plain Ingress last time: an Ingress's backend must live in the same namespace as the Ingress object, full stop. Gateway API allows the cross-namespace reference, but only once the *target* namespace explicitly grants it — that's what `ReferenceGrant` is for. Create one in `team-a` permitting HTTPRoutes from `reports` to reference `web-svc`.

Validate:

```bash
curl -H "Host: cross.gw.test" http://localhost:8080/
kubectl describe httproute cross-route -n reports   # check ResolvedRefs condition
```

Try it without the ReferenceGrant first if you want to see the failure mode before fixing it.

---

## Part 4 — Task: path-based routing with `URLRewrite`

**Requirement:** under a shared hostname `apps.gw.test`, route `/team-a` → team-a's app and `/team-b` → team-b's app, stripping the matched prefix before the request reaches the backend — same end result as the Ingress exercise's regex rewrite, but this time using a portable HTTPRoute filter instead of an nginx-specific annotation.

Look at the `URLRewrite` filter type and its `path.type: ReplacePrefixMatch` option rather than reaching for regex.

Validate:

```bash
curl -H "Host: apps.gw.test" http://localhost:8080/team-a
curl -H "Host: apps.gw.test" http://localhost:8080/team-b/
```

---

## Part 5 — Task: native traffic splitting

**Requirement:** deploy a second version of team-a's app (different response text), then update team-a's HTTPRoute so `team-a.gw.test` splits traffic 80/20 between the stable and new version — no canary-specific annotation needed this time, since weighted routing is part of the core HTTPRoute spec.

Validate:

```bash
for i in $(seq 1 30); do curl -s -H "Host: team-a.gw.test" http://localhost:8080/; echo; done | sort | uniq -c
```

---

## Part 6 — Task: TLS termination at the listener

**Requirement:** add a second listener to your existing `shared-gateway` — HTTPS on port 443, terminating TLS with a self-signed cert for `secure.gw.test` — then attach an HTTPRoute for that host to it, routing to team-a's app.

Unlike Ingress, where TLS is configured per-Ingress-object, Gateway API terminates TLS at the **listener** level on the Gateway itself. The secret can live in `gw-infra` alongside the Gateway — same-namespace references never need a `ReferenceGrant`.

Validate:

```bash
curl -k --resolve secure.gw.test:8443:127.0.0.1 https://secure.gw.test:8443/
openssl s_client -connect localhost:8443 -servername secure.gw.test </dev/null 2>/dev/null | openssl x509 -noout -subject
```

---

## Part 7 — Troubleshooting challenge

Apply this manifest exactly as written (assumes `shared-gateway` from Part 2 already exists):

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: broken-gw
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: shop-content
  namespace: broken-gw
data:
  index.html: |
    <h1>Shop is up</h1>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
  namespace: broken-gw
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
  namespace: broken-gw
spec:
  selector:
    app: shopfront
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop-route
  namespace: broken-gw
spec:
  parentRefs:
    - name: shared-gatewy
      namespace: gw-infra
  hostnames:
    - shop.gw.test
  rules:
    - backendRefs:
        - name: shop-svc
          port: 80
```

**Requirement:** `curl -H "Host: shop.gw.test" http://localhost:8080/` currently fails. There are **three independent bugs**, and they surface through three different signals — don't just fix things randomly, read `kubectl describe httproute -n broken-gw shop-route` and its `status.conditions` after each fix.

---

## Bonus (stretch, newer/niche) — `TCPRoute` and regex path matching

`TCPRoute` recently graduated to GA (Standard channel, `v1`) — worth knowing it exists even if it's unlikely to be exam-critical yet: it routes raw TCP without any HTTP-layer awareness (no host-header fan-out, no path matching — one listener maps to one backend). Add a `TCP` listener to a Gateway and a minimal `TCPRoute` pointing at any backend Service on a plain TCP port, and confirm you can reach it with `nc` or `curl` at the raw TCP level.

Also worth a look: HTTPRouteMatch supports a `RegularExpression` path match type, a properly portable alternative to Ingress's implementation-specific regex-annotation hack — check whether your installed implementation's conformance covers it before relying on it. And if you spot `ListenerSet` in the Gateway API docs (added in the v1.5 release, Feb 2026), that's newer still — allowing listeners to be defined and merged onto a Gateway independently. Good to have heard of, not something to expect on the exam this year.

---

## Validation checklist

- [ ] `team-a.gw.test` and `team-b.gw.test` each reach their own team's app
- [ ] `cross.gw.test` (HTTPRoute in `reports`) reaches team-a's Service, only after the `ReferenceGrant` exists
- [ ] `apps.gw.test/team-a` and `apps.gw.test/team-b` both work with the prefix stripped, via `URLRewrite`
- [ ] `team-a.gw.test` traffic splits roughly 80/20 across two backends
- [ ] `secure.gw.test` serves HTTPS via the Gateway's listener-level TLS
- [ ] `shop.gw.test` works after fixing all three bugs in Part 7

---

## Solutions

Try everything above first.

### Part 2

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shared-gateway
  namespace: gw-infra
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              gateway-access: shared-gateway
```

Label the namespaces so the selector above actually matches them:
```bash
kubectl label namespace team-a gateway-access=shared-gateway
kubectl label namespace team-b gateway-access=shared-gateway
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-a-route
  namespace: team-a
spec:
  parentRefs:
    - name: shared-gateway
      namespace: gw-infra
  hostnames:
    - team-a.gw.test
  rules:
    - backendRefs:
        - name: web-svc
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-b-route
  namespace: team-b
spec:
  parentRefs:
    - name: shared-gateway
      namespace: gw-infra
  hostnames:
    - team-b.gw.test
  rules:
    - backendRefs:
        - name: web-svc
          port: 8080   # team-b's Service port, not 80
```

### Part 3

```bash
kubectl create namespace reports
kubectl label namespace reports gateway-access=shared-gateway
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: cross-route
  namespace: reports
spec:
  parentRefs:
    - name: shared-gateway
      namespace: gw-infra
  hostnames:
    - cross.gw.test
  rules:
    - backendRefs:
        - name: web-svc
          namespace: team-a   # explicit cross-namespace ref
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-reports-to-web-svc
  namespace: team-a
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: reports
  to:
    - group: ""
      kind: Service
      name: web-svc
```

Without the `ReferenceGrant`, expect the HTTPRoute's `ResolvedRefs` condition to go `False` — the route itself can still be `Accepted`, but the backend reference is rejected. That split between "attached to a Gateway" and "backend actually resolvable" is exactly the kind of structured signal Gateway API gives you that Ingress never did.

### Part 4

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-a-path
  namespace: team-a
spec:
  parentRefs:
    - name: shared-gateway
      namespace: gw-infra
  hostnames:
    - apps.gw.test
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /team-a
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /
      backendRefs:
        - name: web-svc
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-b-path
  namespace: team-b
spec:
  parentRefs:
    - name: shared-gateway
      namespace: gw-infra
  hostnames:
    - apps.gw.test
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /team-b
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /
      backendRefs:
        - name: web-svc
          port: 8080
```

### Part 5

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-canary-content
  namespace: team-a
data:
  index.html: |
    <h1>Hello from Team A (v2)</h1>
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
```

Update `team-a-route` from Part 2:
```yaml
  rules:
    - backendRefs:
        - name: web-svc
          port: 80
          weight: 80
        - name: web-svc-canary
          port: 80
          weight: 20
```

### Part 6

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure.gw.test"

kubectl create secret tls secure-gw-tls -n gw-infra --cert=tls.crt --key=tls.key
```

Add to `shared-gateway`'s `spec.listeners`:
```yaml
    - name: https
      protocol: HTTPS
      port: 443
      hostname: secure.gw.test
      tls:
        mode: Terminate
        certificateRefs:
          - name: secure-gw-tls
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              gateway-access: shared-gateway
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: secure-route
  namespace: team-a
spec:
  parentRefs:
    - name: shared-gateway
      namespace: gw-infra
      sectionName: https
  hostnames:
    - secure.gw.test
  rules:
    - backendRefs:
        - name: web-svc
          port: 80
```

### Part 7 — the three bugs

1. **Typo'd `parentRefs` name:** `shared-gatewy` doesn't match the real Gateway `shared-gateway`. The route's `Accepted` condition goes `False` — it never attaches to anything. Fix the name.
2. **Missing namespace label:** even with the name fixed, `broken-gw` was never labeled `gateway-access=shared-gateway`, so the Gateway's `allowedRoutes` selector still rejects it — `Accepted` stays `False`, but for a different reason than bug 1. Label the namespace.
3. **Service selector mismatch:** `shop-svc` selects `app: shopfront`; the Deployment's pods carry `app: shop`. Once the route attaches, `ResolvedRefs` can still show `True` (the Service itself exists and is a valid reference) — but `kubectl get endpoints -n broken-gw shop-svc` is empty, so requests still fail. Fix the selector.

Diagnosis sequence:
```bash
kubectl describe httproute -n broken-gw shop-route   # check Accepted, then ResolvedRefs
kubectl get gateway -n gw-infra shared-gateway -o yaml   # confirm listener selector
kubectl get namespace broken-gw --show-labels
kubectl get endpoints -n broken-gw shop-svc
kubectl get pods -n broken-gw --show-labels
```

### Bonus

```yaml
# Add to shared-gateway's listeners
    - name: tcp-echo
      protocol: TCP
      port: 9999
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              gateway-access: shared-gateway
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: team-a-tcp
  namespace: team-a
spec:
  parentRefs:
    - name: shared-gateway
      namespace: gw-infra
      sectionName: tcp-echo
  rules:
    - backendRefs:
        - name: web-svc
          port: 80
```

Test at the raw TCP level (you'll get an HTTP response back since the backend happens to be nginx, but the point is the Gateway did zero HTTP-aware routing to get you there):
```bash
kubectl -n envoy-gateway-system port-forward svc/$ENVOY_SVC 9999:9999 &
curl http://localhost:9999/
```

(`TCPRoute`'s `apiVersion` may already be `v1` rather than `v1alpha2` by the time you try this, depending on which CRD bundle you installed — check `kubectl explain tcproute` to confirm what your cluster actually registered.)
