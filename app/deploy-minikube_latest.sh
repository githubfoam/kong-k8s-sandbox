#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
set -o xtrace
# set -eox pipefail #safety for script

#Install kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

#https://minikube.sigs.k8s.io/docs/start/
#https://github.com/kubernetes/minikube
# Install Minikube
# curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
# chmod +x minikube
# cp minikube /usr/local/bin/ && rm minikube


curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.2.0/minikube-linux-amd64
chmod +x minikube
cp minikube /usr/local/bin/ && rm minikube
#starts Minikube with 6 CPUs, 12288 memory, 120G disk size
minikube start --vm-driver=none \
                --cpus 6 \
                --memory 12288 \
                --disk-size=120g \
                --extra-config=apiserver.authorization-mode=RBAC \
                --extra-config=kubelet.resolv-conf=/run/systemd/resolve/resolv.conf \
                --extra-config kubeadm.ignore-preflight-errors=SystemVerification

# Set docker environment to minikube
eval "$(minikube docker-env --profile=minikube)" && export DOCKER_CLI='docker'

echo "=========================================================================================="
kubectl version --client #ensure the version
kubectl cluster-info
minikube status
echo "=========================================================================================="
echo "Waiting for kubernetes to be ready ..."
  for i in {1..150}; do # Timeout after 5 minutes, 150x2=300 secs
    if kubectl get pods --namespace=kube-system -lk8s-app=kube-dns|grep Running ; then
      break
    fi
    sleep 2
  done
echo "============================status check=============================================================="
minikube status
kubectl cluster-info
kubectl get pods --all-namespaces
kubectl get pods -n default
kubectl get pod -o wide #The IP column will contain the internal cluster IP address for each pod.
kubectl get service --all-namespaces # find a Service IP,list all services in all namespaces

#
# - sudo apt-get -qq -y install conntrack #X Sorry, Kubernetes v1.18.3 requires conntrack to be installed in root's path
# - curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/ # Download kubectl
# - curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/ # Download minikube
# - mkdir -p $HOME/.kube $HOME/.minikube
# - touch $KUBECONFIG
# - sudo minikube start --profile=minikube --vm-driver=none --kubernetes-version=v$KUBERNETES_VERSION #the none driver, the kubectl config and credentials generated are owned by root in the root user’s home directory
# - minikube update-context --profile=minikube
# - "sudo chown -R travis: /home/travis/.minikube/"
# - eval "$(minikube docker-env --profile=minikube)" && export DOCKER_CLI='docker'
# - echo "=========================================================================================="
# - kubectl version --client #ensure the version
# - kubectl cluster-info
# - minikube status
# - echo "=========================================================================================="
# - |
#   echo "Waiting for Kubernetes to be ready ..."
#   for i in {1..150}; do # Timeout after 5 minutes, 150x2=300 secs
#     if kubectl get pods --namespace=kube-system -lcomponent=kube-addon-manager|grep Running && \
#        kubectl get pods --namespace=kube-system -lk8s-app=kube-dns|grep Running ; then
#       break
#     fi
#     sleep 2
#   done
# - echo "============================status check=============================================================="
# - minikube status
# - kubectl cluster-info
# - kubectl get pods --all-namespaces;
# - kubectl get pods -n default;
# - echo "=========================================================================================="
# - echo "=============================Inspection============================================================="
# - echo "=========================================================================================="
# - kubectl get pod -o wide #The IP column will contain the internal cluster IP address for each pod.
# - kubectl get service --all-namespaces # find a Service IP,list all services in all namespaces
# - docker ps #Find the container ID or name of any container in the pod
# # - docker inspect --format '{{ .State.Pid }}' container-id-or-name #get the process ID of either container, take note of the container ID or name
# # - nsenter -t your-container-pid -n ip addr #advantage of using nsenter to run commands in a pod’s namespace – versus using something like docker exec – is that you have access to all of the commands available on the node
# # - nsenter -t your-container-pid -n ip addr #Finding a Pod’s Virtual Ethernet Interface
# # - curl $CONTAINERIP:8080 #confirm that the web server is still running on port 8080 on the container and accessible from the node
# - echo "=============================Inspecting Conntrack Connection Tracking============================================================="
# # - sudo apt-get -qq -y install conntrack #http://conntrack-tools.netfilter.org/
# - sudo apt-get -qq -y install bridge-utils # Install Linux Bridge Tools.
# - sudo apt-get -qq -y install tcpdump
# - sudo ip address show #List your networking devices
# - sudo ip netns list # list configured network namespaces
# - sudo ip netns add demo-ns #add a namespace called demo-ns
# - sudo ip netns list #see that it's in the list of available namespaces
# #A network namespace is a segregated network environment, complete with its own network stack
# # - echo "=============================start bash in our new namespace demo-ns============================================================="
# # - sudo ip netns exec demo-ns bash #start bash in our new namespace and look for interfaces that it knows about
# # - ping 8.8.8.8 #ping Google's public DNS server
# # #Observe that we have no route out of the namespace, so we don't know how to get to 8.8.8.8 from here
# # - netstat -rn #Check the routes that this namespace knows about
# # # - sudo tcpdump -ni veth0  icmp -c 4 #Confirm that the ping is still running and that both veth0 and cbr0 can see the ICMP packets in the default namespace
# # # - sudo tcpdump -ni eth0  icmp -c 4 #Now check whether eth0 can see the ICMP packets
# # # - sudo sysctl net.ipv4.conf.all.forwarding=1 #Turn forwarding on,Linux, by default, doesn't forward packets between interfaces
# # # - sudo tcpdump -ni eth0  icmp -c 4 #run tcpdump against eth0 to see if fw is working
# # # - sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE #make all outgoing packets from the host look like they're coming from the host's eth0 IP address
# # # - sudo tcpdump -ni eth0  icmp # sniff
# # # - sudo conntrack -L |grep 8.8.8.8 #iptables applies new rules to new flows and leaves ongoing flows alone
# # - ip address show
# # - ip route show
# # - sudo arp #Let's understand how the connectivity looks from the namespace's layer 2 perspective. Confirm that, from demo-ns, the MAC address of192.168.255.1
# # - ping 192.168.255.1 #Attempt to to ping cbr0,From this namespace, we can only see a local loopback interface. We can no longer see or ping eth0 or cbr0.
# # - exit #Exit out of the demo-ns namespace
# # - echo "=============================Exit out of the demo-ns namespace ============================================================="
# - ip address show #Confirm that you can see the interfaces in the default namespace
# - sudo arp #Confirm that you can see the interfaces in the default namespace
# # - sudo tcpdump -ni ens4 icmp -c 4 && sleep 10 #Confirm that you can see the interfaces in the default namespace
# # - sudo conntrack -L | grep 8.8.8.8
# # - conntrack -L #list all the connections currently being tracked
# # - conntrack -E && sleep 5 #watch continuously for new connections
# # - conntrack -L -f ipv4 -d IPADDRESS -o extended #grep conntrack table information using the source IP and Port
# # - kubectl get po — all-namespaces -o wide | grep IPADDRESS #use kubectl to lookup the name of the pod using that Pod IP address
# # - conntrack -D -p tcp --orig-port-dst 80 # delete the relevant conntrack state
# # - sudo conntrack -D -s IPADDRESS
# # - conntrack -L -d IPADDRESS #list conntrack-tracked connections to a particular destination address
# - echo "=============================Inspecting Iptables Rules============================================================="
# - sysctl net.netfilter.nf_conntrack_max #sysctl setting for the maximum number of connections to track
# - sudo sysctl -w net.netfilter.nf_conntrack_max=191000 #set a new valu
# # - sudo iptables-save | head -n 20 #dump all iptables rules on a node
# - sudo iptables -t nat -L KUBE-SERVICES #list just the Kubernetes Service NAT rules
# - echo "=============================Querying Cluster DNS============================================================="
# - sudo apt install dnsutils -y #if dig is not installed
# - kubectl get service -n kube-system kube-dns #find the cluster IP of the kube-dns service CLUSTER-IP
# # - nsenter -t 14346 -n dig kubernetes.default.svc.cluster.local @IPADDRESS #nsenter to run dig in the a container namespace, Service’s full domain name of service-name.namespace.svc.cluster.local
# - sudo apt-get -qq -y install -y ipvsadm
# # - ipvsadm -Ln #list the translation table of IPs ,kube-proxy can configure IPVS to handle the translation of virtual Service IPs to pod IPs
# # - ipvsadm -Ln -t IPADDRESS:PORT #show a single Service IP
# - echo "=========================================================================================="
