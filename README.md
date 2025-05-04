
# GKE Inference Gateway example deployment

This is a simplified version of the instructions under [Serve an LLM with GKE Inference Gateway](https://cloud.google.com/kubernetes-engine/docs/tutorials/serve-with-gke-inference-gateway)

**Recommended**: Follow [Deploying Gateways](https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways) to deploy a GKE Gateway to serve a sample web application (no model, LLM, etc. just a plain web app).



## Deployment sequence

Check you have a VPC named `default`. If not, create it with subnets in all regions (this usually happens automatically when creating a VPC)

Set env vars

```
export PROJECT_ID=genai-dev-454121
export LOCATION=us-central1
export CLUSTER_NAME=infgw
alias k=kubectl
```


Create a proxy subnet in the `default` VPC. This is required by GKE gateways (see [this](https://cloud.google.com/load-balancing/docs/proxy-only-subnets#proxy_only_subnet_create))
```
gcloud compute networks subnets create xproxy-subnet \
    --purpose=REGIONAL_MANAGED_PROXY \
    --role=ACTIVE \
    --region=${LOCATION} \
    --network=default \
    --range=10.1.1.0/24
```

enable the Network Services API https://console.cloud.google.com/apis/api/networkservices.googleapis.com/

Create cluster with autopilot
```
gcloud container clusters create-auto ${CLUSTER_NAME} \
    --project=${PROJECT_ID}\
    --region=${LOCATION}\
    --release-channel=rapid\
    --cluster-version=1.32.2-gke.1182003 

gcloud container clusters get-credentials ${CLUSTER_NAME} --location=${LOCATION}

# this is regularly not needed for autopilot cluster as
# gateways are enabled by default
gcloud container clusters update ${CLUSTER_NAME} \
    --location=${LOCATION} \
    --gateway-api=standard
```

Set up cluster
```
k apply -f 01-auths.yaml

export HF_TOKEN=<HF_TOKEN>

k create secret generic hf-secret --from-literal=token=$HF_TOKEN
      
k apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v0.3.0/manifests.yaml
```

Deploy LLM serving pods

```
k apply -f 02-deployment.yaml
```

Install and configure GKE inference gateway
```
helm install vllm-llama3-8b-instruct \
  --set inferencePool.modelServers.matchLabels.app=vllm-llama3-8b-instruct \
  --set provider.name=gke \
  --set targetPort=8000 \
  --version v0.3.0 \
  oci://registry.k8s.io/gateway-api-inference-extension/charts/inferencepool

k apply -f 03-inferencemodel.yaml

k apply -f 04-gateway.yaml

k apply -f 05-httroute.yaml
```

Make inference
```
k get gateways

NAME          CLASS                              ADDRESS          PROGRAMMED   AGE
infgw-llama   gke-l7-regional-external-managed   35.208.159.148   True         14m


export GATEWAY_IP=35.208.159.148

curl -i -X POST ${GATEWAY_IP}/v1/completions -v \
-H 'Content-Type: application/json' \
-d '{
    "model": "meta-llama/Meta-Llama-3-8B",
    "prompt": "tell me about wwii",
    "max_tokens": "128",
    "temperature": "1.0"
}'
```



## Troubleshooting


**Check status of components**

     k get nodes,pods,gateways,inferencemodels,inferencepools,httproutes

a healthy set up would show something like this

    NAME                                        STATUS   ROLES    AGE     VERSION
    node/gk3-infgw-nap-1ojvdjlz-a8a26123-6dqs   Ready    <none>   6m14s   v1.32.2-gke.1182003
    node/gk3-infgw-nap-361h5752-03b2b53d-xjck   Ready    <none>   5m30s   v1.32.2-gke.1182003

    NAME                                               READY   STATUS    RESTARTS   AGE
    pod/vllm-llama3-8b-instruct-7cfc9f4585-648d6       1/1     Running   0          7m37s
    pod/vllm-llama3-8b-instruct-epp-59db965c45-h9qkj   1/1     Running   0          7m

    NAME                                            CLASS                              ADDRESS          PROGRAMMED   AGE
    gateway.gateway.networking.k8s.io/infgw-llama   gke-l7-regional-external-managed   35.208.159.148   True         6m40s

    NAME                                                   MODEL NAME                   INFERENCE POOL            CRITICALITY   AGE
    inferencemodel.inference.networking.x-k8s.io/xllama3   meta-llama/Meta-Llama-3-8B   vllm-llama3-8b-instruct   Standard      6m49s

    NAME                                                                  AGE
    inferencepool.inference.networking.x-k8s.io/vllm-llama3-8b-instruct   6m58s

    NAME                                              HOSTNAMES   AGE
    httproute.gateway.networking.k8s.io/route2llama               6m28s

observe
- all pods are ready and running.
- there is a pod `-epp` which runs the inference pool.
- the gateway has a public IP address.


**Check pods startup**

With the following you should see the pod waiting for and being deployed on a node

    export LLM_POD=pod/vllm-llama3-8b-instruct-7cfc9f4585-648d6
    k describe ${LLM_POD}

Watch a pod load the model and start serving it

    k logs -f ${LLM_POD}


**Interact directly with serving pods**

select any pod, port-forward to it and make a request for metrics and one actually calling the llm

    k port-forward ${LLM_POD} 8000:8000

    curl -i GET localhost:8000/metrics -v

then, make a request to the llm

    curl -i -X POST localhost:8000/v1/completions -v \
    -H 'Content-Type: application/json' \
    -d '{
        "model": "meta-llama/Meta-Llama-3-8B",
        "prompt": "tell me about wwii",
        "max_tokens": "128",
        "temperature": "1.0"
    }'

This checks that the pods are working as expected.

**Check cluster has gateway capabilities enabled**

    gcloud container clusters describe ${CLUSTER_NAME} \
    --location=us-central1 \
    --format json

you should see

    "networkConfig": {
    ...
    "gatewayApiConfig": {
        "channel": "CHANNEL_STANDARD"
    },
    ...
    },

**Check inference pool is running**

    k describe inferencepools

**Check gateway is routing basic requests**

get metrics from whatever pod the request is routed to

    curl -i GET ${GATEWAY_IP}:80/metrics -v

this request does not go through the LLM routing logic, so with this you check the gateway is actually getting requests. 

**Monitor inference pool**

here you should see the actual routing to specific models (the `-epp` pod)

    export INFPOOL_POD=pod/vllm-llama3-8b-instruct-epp-59db965c45-h9qkj
    k logs -f ${INFPOOL_POD}

**Suggested troubleshooting scenario**

open three shells in different windows

- one to monitor the llm serving pod `k logs -f ${LLM_POD}`
- one to monitor the inference pool pod `k logs -f ${INFPOOL_POD}`
- one to send `curl` requests to the gateway and the llm serving pod.

you should see the requests getting to the inference pool and then to an llm pod.