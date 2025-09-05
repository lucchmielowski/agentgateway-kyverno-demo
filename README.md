# Agentgateway + Kyverno integration

This repository serves as POC for showcasing Kgateway + Agentgateway + Kyverno integration

## Installing the demo

### Create a kind cluster

```sh
KIND_IMAGE=kindest/node:v1.33.4
kind create cluster
```


### Create an OpenAI secret (used for agentgateway LLM authentication)

```sh
export OPEN_AI_TOKEN="<your_token_here>"

# Create secret to be used by agentgateway for LLM access
kubectl apply -f- <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: openai-secret
  namespace: kgateway-system
  labels:
    app: agentgateway-kyverno
type: Opaque
stringData:
  Authorization: $OPENAI_API_KEY
EOF
```

### Install and configure KGateway + Kyverno

```sh
./install.sh
```

## Working with the demo 

```sh
# Port-forward to agent-gateway
kubectl port-forward -n kgateway-system deployment/agentgateway 8080:8080

# (In another termnial) Launch mcp-inspector
npx modelcontextprotocol/inspector#0.16.2
```

From the Inspector's UX, you should be able to do everything. Update the validation rule in the `manifests/vpol.yaml` file so that the rule is now `envoy.Denied(403).Response()`. 
You should now get 403 errors for all actions (even login).

## TODO: Add real-life  example(s)