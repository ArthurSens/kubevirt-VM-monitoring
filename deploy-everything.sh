# The first piece of the puzzle will be the Prometheus Stack
# The reason is because the KubeVirt CR, when installed on the cluster, will try to detect if the ServiceMonitor CR already exists
# If it does, then it will create ServiceMonitors so KubeVirt components can be monitored automatically
# We will not monitor those components in this tutorial, but it is a good practice to always install prometheus-operator first :)

# Alright, we will use helm charts to install the prometheus operator
echo "Fetching stable/prometheus-operator"
helm fetch stable/prometheus-operator
echo "Unarchiving chart"
tar xzf prometheus-operator*.tgz
echo "Deploying prometheus-operator"
kubectl create ns monitoring
cd prometheus-operator/ && helm install -n monitoring -f values.yaml monitoring stable/prometheus-operator && cd ..
echo "Removing artifacts"
rm -rf prometheus-operator*

# Even though the VM doesn't exist yet, we can already create the service and servicemonitor
# They will find the VM once it's created
kubectl apply -f manifests/vm-service-monitor.yaml

# Install KubeVirt Operator and wait until it's ready
# KubeVirt Operator is a deployment with 2 replicas
# Once all pods are ready, we are good to go!
echo "Getting lastest KubeVirt Version"
export KUBEVIRT_VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases | grep tag_name | grep -v -- - | sort -V | tail -1 | awk -F':' '{print $2}' | sed 's/,//' | xargs)
echo "Lastest KubeVirt version: ${KUBEVIRT_VERSION}"
kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-operator.yaml
sleep 5 ## There is a small delay between the POST to k8s API until the pods creation
kubectl rollout status -n kubevirt deployment virt-operator
echo "All Kubevirt Operator replicas are ready! Continuing..."


# Install the KubeVirt Custom Resource and wait until all it's components are ready
# The components are: virt-api, virt-controller and virt-handler
kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-cr.yaml
sleep 10
kubectl rollout status -n kubevirt deployment virt-api
kubectl rollout status -n kubevirt deployment virt-controller
kubectl rollout status -n kubevirt daemonset virt-handler
echo "Kubevirt components are ready! Continuing..."



# One last important component is the CDI (Containerized Data Importer)
# It will be responsible to provide a way to persist the KubeVirt VMs
# We will install the operator first and wait until it's ready
echo "Getting lastest CDI Version"
export CDI_VERSION=$(curl -s https://github.com/kubevirt/containerized-data-importer/releases/latest | grep -o "v[0-9]\.[0-9]*\.[0-9]*")
echo "Lastest CDI version: ${CDI_VERSION}"
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$CDI_VERSION/cdi-operator.yaml
sleep 5
kubectl rollout status -n cdi deployment cdi-operator
echo "All CDI Operator replicas are ready! Continuing..."



# Now we will install the CDI Custom Resource, which will install other components
# cdi-apiserver, cdi-uploadproxy and cdi-deployment
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$CDI_VERSION/cdi-cr.yaml
sleep 30
kubectl rollout status -n cdi deployment cdi-apiserver
kubectl rollout status -n cdi deployment cdi-uploadproxy
kubectl rollout status -n cdi deployment cdi-deployment
echo "CDI components are ready! Continuing..."



echo "Creating persistent volume and importing disk image"
kubectl apply -f manifests/persistent-volume.yaml
kubectl apply -f manifests/monitorable-vm.yaml
foundVirtLauncher=1
while [ $foundVirtLauncher == 1 ]
do
  foundLogs=1
  while [ $foundLogs == 1 ]
  do
    kubectl logs -f -n default importer-cirros-dv
    foundLogs=$?
    sleep 1
  done
  kubectl get vmi monitorable-vm
  foundVirtLauncher=$?
  if [ $foundVirtLauncher == 1 ]; then
    echo "VM disk importer wasn't successful :("
    echo "The importer will try again, let's check the logs"
  fi
done
echo "Waiting for virt-launcher to start up"
echo ""
kubectl wait -n default --for condition=ready --timeout=180s pods -l kubevirt.io=virt-launcher
echo ""
echo "Monitorable-VM is up and running"
echo ""
echo "You can access it's console with 'virtctl console monitorable-vm'"
echo "So let's do it! (VM is probably booting, a prompt will appear once you can login)"
sleep 2
virtctl console monitorable-vm
