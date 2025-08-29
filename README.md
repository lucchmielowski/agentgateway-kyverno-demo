# KGateway (agentgateway) + Kyverno demo

## Pre-setup


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

## Manifest install

```sh
kubectl apply -f https://raw.githubusercontent.com/lucchmielowski/agentgateway-kyverno-demo/refs/heads/main/manifests/agentgateway.yaml
```

## Testing

```sh
# ADD vpol
k apply -f manifests/vpol.yaml
```


```sh
kubectl port-forward deployment/agentgateway 8080:8080

npx github:modelcontextprotocol/inspector
```