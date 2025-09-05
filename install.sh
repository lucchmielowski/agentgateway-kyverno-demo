#!/bin/bash

# Agentgateway + Kyverno integration installation script
# This script installs KGateway, creates MCP server, and sets up the gateway

set -e  # Exit on any error

echo "🚀 Starting Agentgateway + Kyverno integration installation..."

# Install KGateway
echo "📦 Installing Gateway API CDRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml

echo "📦 Installing KGateway CDRDs..."
helm upgrade -i --create-namespace --namespace kgateway-system --version v2.1.0-main kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds

echo "📦 Installing KGateway..."
helm upgrade -i --namespace kgateway-system --version v2.1.0-main kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway \
  --set agentGateway.enabled=true \
  --set gateway.aiExtension.enabled=true \
  --set agentGateway.enableAlphaAPIs=true

# Install Kyverno authz-server
echo "🔐 Installing cert-manager..."
helm upgrade -i cert-manager \
  --namespace cert-manager --create-namespace \
  --wait \
  --repo https://charts.jetstack.io cert-manager \
  --set crds.enabled=true

echo "🔐 Creating ClusterIssuer..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

echo "🔐 Installing kyverno-authz-server..."
helm upgrade -i kyverno-authz-server \
  --namespace kyverno --create-namespace \
  --version v0.3.0-alpha.2 \
  --wait \
  --repo https://kyverno.github.io/kyverno-envoy-plugin kyverno-authz-server \
  --set service.appProtocol="kubernetes.io/h2c" \
  --set certificates.certManager.issuerRef.group=cert-manager.io \
  --set certificates.certManager.issuerRef.kind=ClusterIssuer \
  --set certificates.certManager.issuerRef.name=selfsigned-issuer



# Install MCP server
echo "🔧 Creating MCP server..."
kubectl apply -f manifests/mcp/url-fetcher.yaml

echo "🔧 Configuring Kgateway..."
kubectl apply -f manifests/gateway

echo "📋 Creating ValidationPolicy..."
kubectl apply -f manifests/kyverno/vpol.yaml

echo "✅ Installation completed successfully!"
echo ""
echo "🧪 To test the installation:"
echo "1. Port-forward to agent-gateway: kubectl port-forward -n kgateway-system deployment/agentgateway 8080:8080"
echo "2. Launch mcp-inspector: npx modelcontextprotocol/inspector#0.16.2"
echo ""
echo "📝 Note: The Gateway Extension + TrafficPolicy section from the README has been skipped as it doesn't work for agentgateway."