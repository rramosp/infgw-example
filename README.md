


gcloud container clusters create-auto infgw \
    --project=genai-dev-454121 \
    --region=us-east4 \
    --release-channel=rapid \
    --cluster-version=1.32.3-gke.1170000

# changes cluster version

gcloud container clusters create-auto infgw     --project=genai-dev-454121     --region=us-east4     --release-channel=rapid     --cluster-version=1.32.2-gke.1182003

gcloud container clusters get-credentials infgw --location=us-east4

k apply -f 01-auths.yaml

kubectl create secret generic hf-secret --from-literal=token=<HF_TOKEN>
      
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v0.3.0/manifests.yaml

k apply -f 02-vllm-llama3-8b-instruct.yaml

k apply -f 03-inferencemodel.yaml
