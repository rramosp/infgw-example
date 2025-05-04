following instructions here: https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways


## create cluster

    gcloud container clusters create-auto simplegw\
            --region=us-central1\
            --release-channel=rapid\
            --cluster-version=1.32.2-gke.1182003 


**verify cluster**

    gcloud container clusters describe simplegw \
    --location=us-central1 \
    --format json

must have 

    "networkConfig": {
    ...
    "gatewayApiConfig": {
        "channel": "CHANNEL_STANDARD"
    },
    ...
    },

**confirm gateway classes are installed in the cluster**

    k get gatewayclass

## create proxy-only subnet

    gcloud compute networks subnets create xproxy-subnet \
        --purpose=REGIONAL_MANAGED_PROXY \
        --role=ACTIVE \
        --region=us-central1 \
        --network=default \
        --range=10.0.0.1/24

**check subnet**

    gcloud compute networks subnets describe xproxy-subnet \
        --region=us-central1


## deploy gateway 

    k apply -f 01-gateway.yaml

**check the gateway**

    k describe gateways.gateway.networking.k8s.io internal-http

## deploy demo application

    k apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/gke-networking-recipes/main/gateway/gke-gateway-controller/app/store.yaml

**verify deplpoyment**

    k get nodes,pods,services
    k port-forward  pod/store-v1-5dfcd55f77-j62f6 8080:8080

choose any pod form `describe` command and open localhost:8080

## deploy httproute

    k apply -f 02-httproute.yaml 