# Agentgateway + Kyverno integration

This repository serves as POC for showcasing Kgateway + Agentgateway + Kyverno integration

## Install KGateway

```shell
# install gateway API CDRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml

# install kgateway CDRDs
helm upgrade -i -create-namespace --namespace kgateway-system --version v2.1.0-main kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds
```

```sh
# install kgateway
helm upgrade -i --namespace kgateway-system --version v2.1.0-main kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway \
  --set agentGateway.enabled=true \
  --set agentGateway.enableAlphaAPIs=true
```

###  Create MCP server

```sh
kubectl apply -f manifests/mcp-server.yaml
```

```sh
# Create backend to MCP server
kubectl apply -f- <<EOF
apiVersion: gateway.kgateway.dev/v1alpha1
kind: Backend
metadata:
  name: mcp-backend
spec:
  type: MCP
  mcp:
    targets:
    - name: website
      static:
        host: mcp-website-fetcher.default.svc.cluster.local
        port: 80
        protocol: SSE   
EOF
```

### Create the gateway 
```sh
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: agentgateway
  namespace: kgateway-system
spec:
  gatewayClassName: agentgateway
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF
```


```sh
# Create HTTP Route to ref backend
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mcp
spec:
  parentRefs:
  - name: agentgateway
  rules:
    - backendRefs:
      - name: mcp-backend
        group: gateway.kgateway.dev
        kind: Backend   
EOF
```


## SKIP Gateway Extension + TrafficPolicy, does not work for agentgateway
```sh
## Create gateway-extension
kubectl apply -f - <<EOF
apiVersion: gateway.kgateway.dev/v1alpha1
kind: GatewayExtension
metadata:
  namespace: kgateway-system
  name: kyverno-authz-server
spec:
  type: ExtAuth
  extAuth:
    grpcService:
      backendRef:
        name: kyverno-authz-server
        namespace: kyverno
        port: 9081
EOF
```
```sh
# Add traffic policy to route traffic through extension
kubectl apply -f - <<EOF
apiVersion: gateway.kgateway.dev/v1alpha1
kind: TrafficPolicy
metadata:
  namespace: kgateway-system
  name: kyverno-authz-server
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: agentgateway
  extAuth:
    extensionRef: 
      name: kyverno-authz-server
EOF
```

```sh
# Grant authorization to kyverno authz-server
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: kgateway-gateway
  namespace: kyverno
spec:
  from:
    - group: gateway.kgateway.dev
      kind: GatewayExtension
      namespace: kgateway-system
  to:
    - group: ""
      kind: Service
EOF
```

## Install kyverno authz-server

```shell
kind create cluster --image kindest/node:v1.31.4 --wait 1m
```

```shell
helm install cert-manager \
  --namespace cert-manager --create-namespace \
  --wait \
  --repo https://charts.jetstack.io cert-manager \
  --set crds.enabled=true


kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

```sh
helm install kyverno-authz-server \
  --namespace kyverno --create-namespace \
  --version v0.3.0-alpha.2 \
  --wait \
  --repo https://kyverno.github.io/kyverno-envoy-plugin kyverno-authz-server \
  --set service.appProtocol="kubernetes.io/h2c" \
  --set certificates.certManager.issuerRef.group=cert-manager.io \
  --set certificates.certManager.issuerRef.kind=ClusterIssuer \
  --set certificates.certManager.issuerRef.name=selfsigned-issuer
```

```sh
# Create a ValidationPolicy
kubectl apply -f manifests/vpol.yaml
```

## Testing if it works

```sh
# Port-forward to agent-gateway
kubectl port-forward -n kgateway-system deployment/agentgateway 8080:8080

# (In another termnial) Launch mcp-inspector
npx modelcontextprotocol/inspector#0.16.2
```

From the Inspector's UX, you should be able to do everything. Update the validation rule in the `manifests/vpol.yaml` file so that the rule is now `envoy.Denied(403).Response()`. 
You should now get 403 errors for all actions (even login).

## TODO: Add more complex example(s)