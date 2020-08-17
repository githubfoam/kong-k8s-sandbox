#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
set -o xtrace
# set -eox pipefail #safety for script

# https://konghq.com/blog/canary-deployment-5-minutes-service-mesh/
# https://kuma.io/docs/0.7.1/installation/ubuntu/
# https://github.com/kumahq/kuma-demo/tree/master/kubernetes
echo "=============================securing your application with mTLS using Kuma============================================================="

# Kuma will store all of its state and configuration on the underlying Kubernetes API server, and therefore requiring no dependency to store the data. 
# Deploy the marketplace application
# kubectl apply -f https://raw.githubusercontent.com/Kong/kuma-demo/master/kubernetes/kuma-demo-aio.yaml
kubectl apply -f https://bit.ly/demokuma

# The first pod is an Elasticsearch service that stores all the items in our marketplace
# The second pod is the Vue front-end application that will give us a visual page to interact with
# The third pod is our Node API server, which is in charge of interacting with the two databasesö
# The fourth pod is the Redis service that stores reviews for each item
kubectl get pods -n kuma-demo

# port-forward the sample application to access the front-end UI
kubectl port-forward ${KUMA_DEMO_APP_POD_NAME} -n kuma-demo 8080:80# kubectl port-forward ${KUMA_DEMO_APP_POD_NAME} -n kuma-demo 8080:80
curl http://localhost:8080

# # Download Kuma
# # https://kuma.io/docs/0.7.1/installation/ubuntu/

# # Run the following script to automatically detect the operating system and download Kuma
# # curl -L https://kuma.io/installer.sh | sh -
# /bin/sh -c "curl -L https://kuma.io/installer.sh | sh -"

# export KUMAVERSION="0.7.1"
# # https://kong.bintray.com/kuma/kuma-0.7.1-ubuntu-amd64.tar.gz
# # tar xvzf kuma-0.7.1*.tar.gz

https://kong.bintray.com/kuma/kuma-$KUMAVERSION-ubuntu-amd64.tar.gz
tar xvzf kuma-$KUMAVERSION*.tar.gz

wget https://kong.bintray.com/kuma/kuma-0.3.0-darwin-amd64.tar.gz
tar xvzf kuma-0.3.0-darwin-amd64.tar.gz

cd bin && ls -lai

# Install Kuma
# ./kumactl install control-plane | kubectl apply -f -
# bash kumactl install control-plane | kubectl apply -f -
/bin/sh -c "kumactl install control-plane | kubectl apply -f -"

# check the pods are up and running within the kuma-system namespace
kubectl get pods -n kuma-system

# delete the existing kuma-demo pods so they restart
# give the injector a chance to deploy those sidecar proxies among each pod
kubectl delete pods --all -n kuma-demo

# The additional container is the Envoy sidecar proxy that Kuma is injecting into each pod
kubectl get pods -n kuma-demo

# port-forward our marketplace application again and spot the difference
# The only change is that Envoy now handles all the traffic between the services
kubectl port-forward ${KUMA_DEMO_APP_POD_NAME} -n kuma-demo 8080:80


# Canary Deployment
# scale up the deployments of v1 and v2 like
kubectl scale deployment kuma-demo-backend-v1 -n kuma-demo --replicas=1
kubectl scale deployment kuma-demo-backend-v2 -n kuma-demo --replicas=1

# check pods again, see three backend services
kubectl get pods -n kuma-demo

# This is also known as canary deployment
# a pattern for rolling out new releases to a subset of users or servers
# use the new TrafficRoute policy to slowly roll out users to our flash-sale capability
# By deploying the change to a small subset of users, we can test its stability
# define the following alias
alias benchmark='echo "NUM_REQ NUM_SPECIAL_OFFERS"; kubectl -n kuma-demo exec $( kubectl -n kuma-demo get pods -l app=kuma-demo-frontend -o=jsonpath="{.items[0].metadata.name}" ) -c kuma-fe -- sh -c '"'"'for i in `seq 1 100`; do curl -s http://backend:3001/items?q | jq -c ".[] | select(._source.specialOffer == true)" | wc -l ; done | sort | uniq -c | sort -k2n'"'"''
# send 100 requests from frontend-app to backend-api and count the number of special offers in the response
# The traffic is equally distributed because have not set any traffic-routing
benchmark


# With one simple policy and the weight
# apply to each matching service
# slowly roll out the v1 and v2 version of the application
cat <<EOF | kubectl apply -f -
apiVersion: kuma.io/v1alpha1
kind: TrafficRoute
metadata:
  name: frontend-to-backend
  namespace: kuma-demo
mesh: default
spec:
  sources:
  - match:
      service: frontend.kuma-demo.svc:80
  destinations:
  - match:
      service: backend.kuma-demo.svc:3001
  conf:
  # it is NOT a percentage. just a positive weight
  - weight: 80
    destination:
      service: backend.kuma-demo.svc:3001
      version: v0
  # we're NOT checking if total of all weights is 100
  - weight: 20
    destination:
      service: backend.kuma-demo.svc:3001
      version: v1
  # 0 means no traffic will be sent there
  - weight: 0
    destination:
      service: backend.kuma-demo.svc:3001
      version: v2
EOF

# run the benchmark alias to see the TrafficRoute policy in action
# do not see any results for two special offers because it is configured with a weight of 0
benchmark

# see the action live on the webpage
# port-forward the application frontend
# Two out of roughly 10 requests to the webpage have the sale feature enabled
kubectl port-forward ${KUMA_DEMO_APP_POD_NAME} -n kuma-demo 8080:80

# kubectl apply -f https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/minikube/postgres.yaml
# kubectl apply -f https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/minikube/kong_migration_postgres.yaml
# kubectl apply -f https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/minikube/kong_postgres.yam

# kubectl get deployment kong-rc

# # Run the two mock services
# docker build --no-cache -t kong:mesh-config  . -f Dockerfile.kong-config

# kubectl apply -f serviceb.yaml
# kubectl apply -f servicea.yaml

# # Service B logs
# kubectl logs -l app=serviceb -c serviceb

# # Kong mesh logs
# kubectl logs -l app=servicea -c kong


# https://github.com/Kong/kubernetes-ingress-controller/blob/main/docs/deployment/k4k8s.md

# YAML manifests METHOD 1
# deploy Kong via kubectl
kubectl apply -f https://bit.ly/kong-ingress-dbless

# Helm Chart METHOD 2
# deploy Kong onto your Kubernetes cluster with Helm
# helm repo add kong https://charts.konghq.com
# helm repo update

# Helm 2
# helm install kong/kong

# Helm 3
# helm install kong/kong --generate-name --set ingressController.installCRDs=false


# echo "=========================================================================================="
echo "Waiting for  the Kong control plane to be ready ..."
for i in {1..60}; do # Timeout after 5 minutes, 60x5=300 secs
      if kubectl get pods --namespace=kong  | grep ContainerCreating ; then
        sleep 10
      else
        break
      fi
done

echo "============================status check=============================================================="
minikube status
kubectl cluster-info
kubectl get pods --all-namespaces
kubectl get pods -n default
kubectl get pods -n kong
kubectl get pod -o wide #The IP column will contain the internal cluster IP address for each pod.
kubectl get service --all-namespaces # find a Service IP,list all services in all namespaces

# Getting started with Kong Ingress Controller
# https://github.com/Kong/kubernetes-ingress-controller/blob/main/docs/guides/getting-started.md

# Setup an echo-server application to demonstrate how to use Kong Ingress Controller
# This application just returns information about the pod and details from the HTTP request
kubectl apply -f https://bit.ly/echo-service

# Basic proxy
# Create an Ingress rule to proxy the echo-server created previously
echo "
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: demo
spec:
  rules:
  - http:
      paths:
      - path: /foo
        backend:
          serviceName: echo
          servicePort: 80
" | kubectl apply -f -

# Test the Ingress rule
# This verifies that Kong can correctly route traffic to an application running inside Kubernetes
# curl -i $PROXY_IP/foo

# Using plugins in Kong
# Setup a KongPlugin resource
echo "
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: request-id
config:
  header_name: my-request-id
plugin: correlation-id
" | kubectl apply -f -

# Create a new Ingress resource which uses this plugin
# directs Kong to execute the request-id plugin whenever a request is proxied matching any rule defined in the resource
echo "
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: demo-example-com
  annotations:
    konghq.com/plugins: request-id
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /bar
        backend:
          serviceName: echo
          servicePort: 80
" | kubectl apply -f -


# Send a request to Kong
# curl -i -H "Host: example.com" $PROXY_IP/bar/sample

# Using plugins on Services
# execute a plugin whenever a request is sent to a specific k8s service, no matter which Ingress path it came from
echo "
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rl-by-ip
config:
  minute: 5
  limit_by: ip
  policy: local
plugin: rate-limiting
" | kubectl apply -f -


# apply the konghq.com/plugins annotation on the Kubernetes Service that needs rate-limiting
kubectl patch svc echo \
  -p '{"metadata":{"annotations":{"konghq.com/plugins": "rl-by-ip\n"}}}'

# any request sent to this service will be protected by a rate-limit enforced by Kong
# curl -I $PROXY_IP/foo
# curl -I -H "Host: example.com" $PROXY_IP/bar/sample
