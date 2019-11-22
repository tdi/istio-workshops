#!/bin/bash
set -e 

PROJECT="turnkey-cooler-231216"
NAME="istiofun"
NODE_COUNT=3
LOCATION="europe-west1-d"
ISTIO_VERSION="1.3.2"
KUBE_VER=$(az aks get-versions -l ${LOCATION} --query 'orchestrators[-1].orchestratorVersion' -o tsv)


# You can also check this site to see alternatives on setting up azure AKS
# https://istio.io/docs/setup/platform-setup/gke/


echo "Provisioning GKE engine ${NAME} version ${KUBE_VERSION} in project ${PROJECT} in ${LOCATION}"

echo "Creating AKS cluster ${NAME}:${KUBE_VERSION}"
gcloud beta container --project ${PROJECT} clusters create ${NAME} --zone ${LOCATION} --machine-type "n1-standard-1" --num-nodes 3 --cluster-version latest

echo "Cluster ${NAME} is fine, setting kubectl"
gcloud container clusters get-credentials ${NAME} --zone ${LOCATION} --project ${PROJECT}
exit 
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