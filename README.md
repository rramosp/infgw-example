

# inference gateway example deployment

sequence of commands

```
alias k=kubectl

gcloud container clusters create-auto infgw     --project=genai-dev-454121     --region=us-east4     --release-channel=rapid     --cluster-version=1.32.2-gke.1182003

gcloud container clusters get-credentials infgw --location=us-east4

k apply -f 01-auths.yaml

k create secret generic hf-secret --from-literal=token=<HF_TOKEN>
      
k apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v0.3.0/manifests.yaml

k apply -f 02-deployment-llama3-8b.yaml

helm install vllm-llama3-8b-instruct \
  --set inferencePool.modelServers.matchLabels.app=vllm-llama3-8b-instruct \
  --set provider.name=gke \
  --version v0.3.0 \
  oci://registry.k8s.io/gateway-api-inference-extension/charts/inferencepool

k apply -f 03-inferencemodel.yaml

k apply -f 04-gateway.yaml

k apply -f 05-httroute.yaml
``

NOTES:

- cluster version was changed to 1.32.2-gke.1182003