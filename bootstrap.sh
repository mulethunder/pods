    # For GUI support, see this: https://gist.github.com/niw/bed28f823b4ebd2c504285ff99c1b2c2
    echo "##########################################################################"
    echo "###################### Updating packages ##############################"

    sudo apt-get update

    echo "##########################################################################"    
    echo "###################### Installing Git ##############################"

    sudo apt-get install git -y
   
    echo "##########################################################################"
    echo "############### Installing NodeJS via Node Version Manager on an Ubuntu Machine ###############"

    #curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
    #source ~/.bashrc 
    #nvm list-remote

    chmod 755 /vagrant/nvm-install.sh
    /vagrant/nvm-install.sh

    source ~/.nvm/nvm.sh

    #nvm install v14.17.5
    #Switch: nvm use v14.10.0 
    nvm install 16
    nvm use 16

    sudo apt install npm -y


    echo "########################################################################################"
    echo "############################### Installing API-Catalog CLI #########################"

    # First satisfy API Catalog role in Anypoint Platform for user
    # Satisfy NVP -> Node version 16

    npm install -g api-catalog-cli@latest




    echo "##########################################################################"
    echo "############# Installing and configuring Docker for Dev #######################"

    sudo apt-get install docker.io -y
    sudo usermod -G docker ubuntu
    sudo usermod -G docker vagrant
    docker --version


    echo "##########################################################################"
    echo "############################### Installing FlexGateway #########################"

    #####################
    ####### Manual task alert:
    ####### Choose a way to run your Flex GW:
    ####### - Option 1: Ubuntu OS service
    ####### - Option 2: Docker image
    ####### - OPtion 3: Ingress Controller via official helm chart (supports HPA)
    #####################

    ## Option 2: Running as a container:
    ## 2.1 Pull the Flex GW
    # docker pull mulesoft/flex-gateway:1.0.0
    ## Register:
    # docker run --entrypoint flexctl -w /registration \
    # -v "$(pwd)":/registration mulesoft/flex-gateway:1.0.0 \
    # register <gateway-name> \
    # --token=XXX \
    # --organization=xxxxxxx \
    # --connected=true    
    #
    ## Start:
    # docker run --rm \
    # -v <absolute-path-to-directory-with-conf-file>/:/etc/flex-gateway/rtm \
    # -p 8081:8081 \
    # -e FLEX_RTM_ARM_AGENT_CONFIG=/etc/flex-gateway/rtm/<UUID-of-your-file>.conf \
    # mulesoft/flex-gateway:1.0.0

    ## Accessed the container: 
    # docker ps
    # docker exec -it [PID] bash


    ## Optoin 3: Running Flex Gateway as an Ingress Controller


    echo "################################################################################################"
    echo "################ Installing Flex Gateway as an Ingress Controller in Kubernetes #########################"


    # Install kubectl
    echo "#################### Install kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Install k3d - current release (as in: https://k3d.io/v5.0.0/#installation):
    echo "#################### Install k3d"
    curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

   # Create a cluster calles mycluster with just a single server node:
    #k3d cluster create mycluster
    echo "#################### Create cluster"
    # sudo runuser -l vagrant -c "k3d cluster create cluster-fg-ic-conn-1 --k3s-arg '--disable=traefik@server:*' --port '80:80@server:*' --port '443:443@server:*' --wait --timeout '300s'"

    ## Testing creating cluster with port 8081 auto-mapping: (see: https://k3d.io/v5.4.1/usage/exposing_services/)
    ## INFO[0000] portmapping '8081:8081' targets the loadbalancer: defaulting to [servers:*:proxy agents:*:proxy]
    sudo runuser -l vagrant -c "k3d cluster create pods-fg-hyb-ic-conn-2-local-c1 --k3s-arg '--disable=traefik@server:*' --port '8081:8081@loadbalancer' --port '8082:8082@loadbalancer' --port '8083:8083@loadbalancer' --wait --timeout '300s'"

    

    #### k3d help:
    ## List clusters: k3d cluster list
    ## Stop a cluster: k3d cluster stop flex-gateway-1
    ## Restart cluster: k3d cluster start flex-gateway-1


    # Install helm:
    echo "#################### Install helm"
    curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
    sudo apt install apt-transport-https --yes
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt update
    sudo apt install helm -y    



    # Merge kube config and set context:
    #k3d kubeconfig merge mycluster --kubeconfig-switch-context

    # Get cluster info
    echo "#################### Get cluster info"
    kubectl cluster-info
    kubectl get nodes
    kubectl get pods -A 


    # Let's break gracefully here....
    exit 0


    # Download Flex Gateway docker image (Not needed once being public):
    # echo "#################### Download Flex Gateway docker images"
    # docker pull mulesoft/flex-gateway:1.0.0
    # k3d image import -c flex-gateway-1 mulesoft/flex-gateway:1.0.0

    ########## Register Flex Gateway (Local/Connected mode)
    # docker run --entrypoint flexctl -w /registration \
    # -v "$(pwd)":/registration mulesoft/flex-gateway:1.0.0 \
    # register XXXXXXXXXX \
    # --token=XXXXXXXXXXX \
    # --organization=XXXXXXXXX \
    # --connected=XXXXXXXX

    # Change ownership to vagrant/ubuntu, so that we can read:
    # sudo chown ubuntu:ubuntu *.conf *.key *.pem
    sudo chown vagrant:vagrant *.conf *.key *.pem

    # Create a namespace (if not already):
    kubectl create namespace gateway

    # Create a Kubernetes secrete from the files:
    # kubectl -n gateway create secret generic XXXXXXXXXX \
    # --from-file=platform.conf=XXXXXXXXXX.conf \
    # --from-file=platform.key=XXXXXXXXXX.key \
    # --from-file=platform.pem=XXXXXXXXXX.pem


    ## Remove any old Flex Gateway Helm repo:
    helm repo remove flex-gateway

    ## Add and update the Flex Gateway Helm repository:
    helm repo add flex-gateway https://flex-packages.anypoint.mulesoft.com/helm
    ## Get the latest changes:
    helm repo up

    ## Show the helm repo:
    helm repo ls

    ########################
    ############ Installing Flex Gateway:

    ######
    #### Layer 1: Flex Gateway as Ingress Controller in Connected Mode:

    ## Install Flex-Gateway Helm Chart as Ingress Controller:
    helm -n gateway upgrade -i --wait ingress flex-gateway/flex-gateway \
    --set registerSecretName=<secret> \
    --set service.http.port=8081

    ######
    #### Layer 2: Flex Gateway as Gateway Instance in Local Mode:

    ## Registering the FG in Local Mode:

    # Create a new namespace for internal FG (if not already):
    kubectl create namespace gateway-internal

    docker run --entrypoint flexctl -w /registration \
    -v "$(pwd)":/registration mulesoft/flex-gateway:1.0.0 \
    register pods-fg-1 \
    --token=XXXXXXXXX \
    --organization=XXXXXX \
    --connected=false

    ## Change ownership to vagrant/ubuntu, so that we can read:
    # sudo chown ubuntu:ubuntu *.conf *.key *.pem
    sudo chown vagrant:vagrant *.conf *.key *.pem

    ## Create Secret again:
    kubectl -n gateway-internal create secret generic XXXXXXXXXX \
          --from-file=platform.conf=XXXXXXXXXX.conf \
          --from-file=platform.key=XXXXXXXXXX.key \
          --from-file=platform.pem=XXXXXXXXXX.pem

    ## Old approach using configMap:
    kubectl -n gateway-internal create configmap flex-config \
    --from-file=$UUID.pem \
    --from-file=$UUID.key \
    --from-file=$UUID.conf -o yaml --dry-run  | kubectl apply -f -

    # ## Installing Flex-Gateway using Helm Chart but not as an Ingress Controller, but Gateway Instance:
    helm -n gateway-internal upgrade -i --wait flex-gw flex-gateway/flex-gateway \
        --set registerSecretName=<UUID-GOES-HERE> \
        --set replicaCount=1 \
        --set autoscaling.enabled=true \
        --set autoscaling.minReplicas=1 \
        --set autoscaling.maxReplicas=4 \
        --set autoscaling.targetCPUUtilizationPercentage=50 \
        --set autoscaling.targetMemoryUtilizationPercentage=70 \
        --set resources.limits.cpu=500m \
        --set resources.limits.memory=256Mi \
        --set service.enabled=true \
        --set service.type=ClusterIP \
        --set service.http.enabled=true \
        --set service.http.port=8082 \
        --set service.https.enabled=false


    ## Verify the IC was created:
    kubectl get apiinstances -n gateway
        # NAME            ADDRESS
        # ingress-https   http://0.0.0.0:443
        # ingress-http    http://0.0.0.0:80

    kubectl get crd
        # apiinstances.gateway.mulesoft.com     2022-06-03T05:16:26Z
        # configurations.gateway.mulesoft.com   2022-06-03T05:16:26Z
        # extensions.gateway.mulesoft.com       2022-06-03T05:16:26Z
        # policybindings.gateway.mulesoft.com   2022-06-03T05:16:26Z
        # services.gateway.mulesoft.com         2022-06-03T05:16:26Z

    ## List all Services and ApiInstances created and forward the Ingress port to localhost
    echo "#################### List all services and API-instances in -n gateway"
    kubectl -n gateway get svc,apiinstances









    
    # Add Peregrine and Grafana helm repo
    echo "#################### Add Peregrine and Grafana help repo"
    helm repo add grafana https://grafana.github.io/helm-charts \
    && helm repo add peregrine https://peregrine:48bcfd4617c9cce@d8wbbsqfcfi8u.cloudfront.net/helm \
    && helm repo up

    # Forward the Ingress port to localhost and hit it, it should return a 404 response
    echo "#################### Trying to access the ingress -> Should be 404 for now..."
    kubectl --namespace gateway port-forward svc/ingress 8000:80 & 
    curl -v http://localhost:8000/

    # Follow: https://docs.google.com/document/d/1nz5Dj9tVGGWfVkkj-uPMDbI7ATkcqrB3p21U3W_yvKA/edit#heading=h.73o2smff9vhd
    #   As a Cluster Operator User:
    #       1. Configure Local Storage used by policies that need to share some data
    #       2. Configure Logging, we will forward runtimeLog and accessLog to Loki, so we can see it in Grafana
    #
    #   As an API Administrator User:
    #       1. Apply access-log policy to ApiInstance ingress-http, so we can see it into Grafana
    #       2. Apply rate-limit-local policy to ApiInstance ingress-http
    #
    #   As a Developer User:
    #       1. Install httpbin application and create an ingress that route traffic from /httpbin/* to the ApiInstance ingress-http in namespace gateway
    helm -n default upgrade -i --wait --create-namespace httpbin peregrine/httpbin --set ingress.enabled=true,ingress.name=ingress-http.gateway

    #       2. Install whoami application and create an ingress that route traffic from /whoami/* to the ApiInstance ingress-http in namespace gateway
    helm -n default upgrade -i --wait --create-namespace whoami peregrine/whoami --set ingress.enabled=true,ingress.name=ingress-http.gateway



    # kubectl exec --stdin --tty pod/ingress-584657d695-4g856 -- sh 
    # apt update && apt install net-tools -y && apt install curl -y
    # curl localhost:9999/status/gateway/namespaces/default/apiInstances

    # kubectl logs pod/ingress-584657d695-4g856 --tail 100 --follow 


    # http://payments-service.payments.svc:3000/


    # curl -u foo:bar 172.18.0.2:8081/services/payments/ -v


    echo "#################### Add  Grafana help repo"
    helm repo add grafana https://grafana.github.io/helm-charts \
    && helm repo up

    # Download the grafana-values.yaml file and Install Grafana using it as the install config
    echo "#################### Install Grafana"
    helm -n monitoring upgrade -i --wait --create-namespace grafana grafana/grafana -f /vagrant/peregrine/grafana-values.yaml

    # Open Grafana in localhost:8080
    # Make sure the native Peregrine service is not running on the same port.
    # sudo services peregrine stop
    echo "#################### Open Grafana as a port-forward in 8080"
    kubectl --namespace monitoring port-forward svc/grafana 8080:80 & 

        # Open http://localhost:8080/
            #admin/peregrine

    # Install loki:
    echo "#################### Install Loki"
    helm -n monitoring upgrade -i --wait --create-namespace loki grafana/loki



    # Hit whoami application - We can see the following headers added by the rate-limit policy
    curl -v http://localhost:8000/whoami/get 
    #curl -v http://172.18.0.2:30510/whoami/get 

    # Go to Grafana Peregrine dashboard and check for logs and traffic
    # open http://localhost:8080/d/WMcWrCv7k/peregrine





# SSH into FG Container:
# kubectl exec --stdin --tty flex-gateway-deployment-6bf599b96b-jc7ck -- /bin/bash

# View Logs:
# kubectl logs pod/flex-gateway-deployment-6bf599b96b-6m8h2 --tail 100 --follow 

# Busybox for testing inside the cluster:
# Create it:
# kubectl run mycurlpod --image=curlimages/curl -i --tty -- sh
# Subsequent use (once pod isrunning)
# kubectl exec --stdin --tty mycurlpod -- sh
#    curl http://payments-service.payments.svc.cluster.local:3000/payments
#    curl http://payments-service.payments.svc:3000/payments

## How about the actual Ingress????
#    curl http://ingress.gateway.svc/payments
#### WHY IT DOESN'T WORK??????
## How do I access the IC in connected mode?????
# Let's try to port fwd:
kubectl -n gateway port-forward svc/ingress 8081:80 --address='0.0.0.0' &



#    curl http://flex-gateway-service.flex-gw.svc.cluster.local:8081/payments


## Attaching to FG container:
# kubectl exec --stdin --tty pod/ingress-8658dff789-sjvwt -- /bin/bash -n gateway
## Install curl:
# apt update && apt install net-tools -y && apt install curl -y


#########
#### Adding extra ports in service/ingress: (i.e. Flex Gateway wunning as Ingress Controller in Connected Mode)
# kubectl edit service/ingress -n gateway


# curl localhost:9999/status/gateway/namespaces/default/apiInstances


####################################################
######################### Test External IP:

#### Not needed, but it was a good experiment: kubectl edit service/ingress -n flex-gw
                                               # edit to port 80 -> 8081

##################
######## Testing Payments and ms2 Services:

## Testing agains ext ip address of k3d LB:
## This worked:
# curl -u foo:bar 172.18.0.2/api/payments
# curl -u foo:bar 172.18.0.2/ms2/payments

## Testing against localhost:
## This worked:
# curl -u foo:bar localhost/api/payments
# curl -u foo:bar localhost/ms2/payments

## Testing against Ext EC2 IP Address/Domain:
## This DID NOT work: (Connection Refused) - As Port FWD is not established yet...
## curl -u foo:bar 3.220.212.173/api/payments -v
## curl -u foo:bar 3.220.212.173/ms2/payments -v
## curl -u foo:bar pods-fgw.demos.mulesoft.com/api/payments -v
## curl -u foo:bar pods-fgw.demos.mulesoft.com/ms2/payments -v

## Creating port fwd 80 ---> 8081 to ext network interface:
##### This did not work, as it routes to local interface: kubectl -n flex-gw port-forward svc/ingress 8081:80 &

# kubectl -n flex-gw port-forward svc/ingress 8081:80 --address='0.0.0.0' &
# ps -fea | grep kubectl
## This DID work: As Port FWD is now established...
## curl -u foo:bar 3.220.212.173:8081/api/payments -v
## curl -u foo:bar 3.220.212.173:8081/ms2/payments -v
## curl -u foo:bar pods-fgw.demos.mulesoft.com:8081/api/payments -v
## curl -u foo:bar pods-fgw.demos.mulesoft.com:8081/ms2/payments -v

#### In order to create a Configuration in Connected mode to FWD Logs to a 3rd party:
## Just create a Configuration resource in the same namespace as installed Flex  to configure it