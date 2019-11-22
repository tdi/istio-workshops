# Install AKS + ISTIO

All the commands should be copied and pasted into terminal. 
What is needed is `az cli`,  `kubectl` and `git` installed. 
YOu can also set up the cluster with isiot and demo app with `./provision.sh` script and go straigh to the `Excercises`.


# Install AKS

Set the version. 

`export KUBE_VER=$(az aks get-versions -l ${LOCATION} --query 'orchestrators[-1].orchestratorVersion' -o tsv)`

Set the name for the resource group and the cluster and istio version.

```
export NAME="darek"
export NODE_COUNT=3
export LOCATION="westeurope"
export ISTIO_VERSION="1.3.2"
```

Provisioning AKS engine

```
az group create --name ${NAME} --location ${LOCATION} 
echo "Creating AKS cluster ${NAME}:${KUBE_VERSION}"

az aks create --resource-group ${NAME} --name ${NAME} --node-count ${NODE_COUNT} --enable-addons monitoring --generate-ssh-keys --kubernetes-version ${KUBE_VER}
```

Now set the credentials:

`az aks get-credentials --resource-group ${NAME} --name ${NAME}
kubectl config set-context ${NAME}`

> If you are overwriting the config aree if the scripts asks (y/n/)

Check if the clyster is fine:

```
kubectl get nodes
kubectl cluster-info
```
# Set up istio

Istio can be set up with helm or manually, we will do it manually - it is easier.

Downloading istio:

```
curl -# -L https://git.io/getLatestIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
```

Install istio into the cluster

```
cd istio-${ISTIO_VERSION}/
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
kubectl apply -f install/kubernetes/istio-demo.yaml
```

Now wait for all pods are `Ready`

```
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

# Deploy the demo app 


We say that namespace `default` will be automatically injected with sidecars:

```
kubectl label namespace default istio-injection=enabled --overwrite
```

Now go into the istio-${ISTIO_VERSION} directory and run:
```
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```
Wait for all pods to be `Ready`

`kubectl get pods`

Now we need to check what is the application entry. Export these variables. 

```
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')"
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT"
```

If you do `curl -s http://${GATEWAY_URL}/productpage | grep -o "<title>.*</title>" ` you should see the page title. You can also go to the `${GATEWAY_URL}` in your browser. `echo ${GATEWAY_URL}` will give the adress to copy / paste.

## Run kiali

Kiali is the mesh visualization. To run in on `localhost:20001` do the command (user and password are admin/admin):

`kubectl port-forward -n istio-system $(kubectl get pod -n istio-system -l app=kiali -o jsonpath='{.items[0].metadata.name}') 20001:20001 &` 


# Excercises

All commands for this execrize will be assumed you are in the `istio-${ISTIO_VERSION}` directory. In order to generate constant traffic to the page (so that stats are shown in Kiali), you can use this command, which will do a `GET` operation every 1s.

`watch -n 1 curl -s http://$\{GATEWAY_URL\}/productpage | grep -o "<title>.*</title>"` 

## Traffic Management 

## Request routing

First apply default destination rules. 

`kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml` 

They will direct traffic to the v1 of the services. You can see them with :`kubectl get destinationrules -o yaml`

Apply default virtual service - it will create ISTIO services for the microservices we have and direct traffic to v1.

`kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml`

In Kiali you should see how traffic goes to the v1. 

### Routing based on HTTP header

When you log in as user `jason` the product page will add an `end-user` header with the value `jason`. 

This rule will make sure all jason traffic will be router to the version 2:

`kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml` 

All other traffic will still go to version 1. You can open one browser window and log in as jason, and second incognito mode without logging. Do some more rquests. Check Kiali how the traffic flows.

> to go back to version 1 traffic flow do `kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml`

### Traffic shifting

Here we will do gradual traffic shifting based on %. Let's reset to the v1 version, before we start.

`kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml`


Let's simulate canary deployment. Let's transfer 50% traffic from `reviews:v1` to `reviews:v3` 

``kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml`


You can check of the rule is applied:

`kubectl get virtualservice reviews -o yaml` 

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
  ...
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 50
    - destination:
        host: reviews
        subset: v3
      weight: 50
```

Now generate more traffic and check Kiali what happens. If traffic distribution is 50/50, we can switch all traffic to v3.

`kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-v3.yaml`

 Now you can open `samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml` and do some changes to percentages youserself. Remember to `kubectl apply`. 

 



