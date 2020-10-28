echo "deleting pre-existing cluster"
minikube delete -p kubevirt

echo "Configuring KubeVirt cluster"
minikube config -p kubevirt set vm-driver kvm2

echo "Starting up KubeVirt cluster"
minikube start -p kubevirt --memory=6g 
