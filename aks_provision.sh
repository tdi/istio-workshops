#!/bin/bash
set -e 

# DELETE_DATE=$(gdate "+%Y.%m.%d" -d "+30 days")
# DELETE_TAG="Delete=${DELETE_DATE}"
NAME="bcistiofun"
NODE_COUNT=3
LOCATION="westeurope"
ISTIO_VERSION="1.3.2"
KUBE_VER=$(az aks get-versions -l ${LOCATION} --query 'orchestrators[-1].orchestratorVersion' -o tsv)


# You can also check this site to see alternatives on setting up azure AKS
# https://istio.io/docs/setup/platform-setup/azure/
# and https://docs.microsoft.com/en-us/azure/aks/istio-install

echo "Provisioning AKS engine ${NAME} version ${KUBE_VERSION} in resource group ${NAME} in ${LOCATION}"
echo "Creating resource group ${NAME}"
az group create --name ${NAME} --location ${LOCATION} 
echo "Creating AKS cluster ${NAME}:${KUBE_VERSION}"
az aks create --resource-group ${NAME} --name ${NAME} --node-count ${NODE_COUNT} --enable-addons monitoring --generate-ssh-keys --kubernetes-version ${KUBE_VER}

echo "Cluster ${NAME} is fine, setting kubectl"
az aks get-credentials --resource-group ${NAME} --name ${NAME}
kubectl config set-context ${NAME}

echo "The cluster is ready"
kubectl cluster-info
sleep 2

echo "Downloading istio ${ISTIO_VERSION}"
if [ ! -d istio-${ISTIO_VERSION} ]; then
    curl -# -L https://git.io/getLatestIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
fi 

echo "Installing istio into cluster"
pushd istio-${ISTIO_VERSION}/
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
kubectl apply -f install/kubernetes/istio-demo.yaml
kubectl get svc -n istio-system

echo "Deploying Bookinfo app"
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

echo "Installing Istio Gateway"
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
popd 

# kubectl get svc istio-ingressgateway -n istio-system
echo 
echo 
echo "Run these commands to get the Products Page in GATEWAY_URL variable"
cat <<"HEHE"
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')"
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT"
HEHE


echo
echo
# curl -s http://${GATEWAY_URL}/productpage | grep -o "<title>.*</title>" 

echo "If you want to run Kiali run this command"
echo "kubectl port-forward -n istio-system $(kubectl get pod -n istio-system -l app=kiali -o jsonpath='{.items[0].metadata.name}') 20001:20001 &" 
echo "Kiali will be available at http://localhost:20001"