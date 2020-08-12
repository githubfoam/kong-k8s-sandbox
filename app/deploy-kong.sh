#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
set -o xtrace
# set -eox pipefail #safety for script

# https://github.com/Kong/kong-dist-kubernetes
# https://docs.konghq.com/1.4.x/kong-for-kubernetes/
# https://github.com/Kong/kubernetes-ingress-controller/blob/main/docs/deployment/k4k8s.md
echo "=============================deploy kong============================================================="

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
