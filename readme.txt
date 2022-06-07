


docker run --entrypoint flexctl -w /registration \
-v "$(pwd)":/registration mulesoft/flex-gateway:1.0.0 \
register flex-gw-pods \
--token=XXXXX \
--organization=XXXXXXX \
--connected=true

export FILES=$(ls {*.conf,*.key,*.pem})
UUID=$(echo "$FILES" | cut -d'.' -f1 | sort -n | uniq)
echo $UUID

kubectl create ns flex-gw
kubectl get ns
kubectl config set-context --current --namespace="flex-gw"

kubectl get all --all-namespaces

kubectl create configmap flex-config --from-file=$UUID.pem --from-file=$UUID.key --from-file=$UUID.conf -o yaml --dry-run  | kubectl apply -f -

kubectl get configmaps
kubectl describe configmaps flex-config

# Run Flex GW by replacing UUID from rtm mount folder:
sed -i 's/UUID_CONFIG/$UUID_CONFIG/' $HOMEinstalls/flex-gateway/values.yaml


##############
####### Run it as an Ingress Controller:

# Register Flex GW and retrieve certificate:

docker run --entrypoint flexctl -w /registration \
 -v "$(pwd)":/registration mulesoft/flex-gateway:1.0.0 \
 register flex-gw-ic \
 --token=XXXXXXX \
 --organization=XXXXXXX \
 --connected=false


# Create a namespace (if not already):
# kubectl create namespace gateway

# Create a Kubernetes secrete from the files:
kubectl -n gateway create secret generic XXXXXXXXXX \
--from-file=platform.conf=XXXXXXXXXX.conf \
--from-file=platform.key=XXXXXXXXXX.key \
--from-file=platform.pem=XXXXXXXXXX.pem

# Add and update the Flex Gateway Helm repository:

helm repo add flex-gateway https://flex-packages.anypoint.mulesoft.com/helm
helm repo up

# Install Flex-Gateway Helm Chart as Ingress Controller:
helm -n gateway upgrade -i --wait ingress flex-gateway/flex-gateway \
--set registerSecretName=XXXXXXXXXX

# Verify the IC was created:
kubectl get apiinstances -n gateway
kubectl get crd
      apiinstances.gateway.mulesoft.com     2022-06-03T05:16:26Z
      configurations.gateway.mulesoft.com   2022-06-03T05:16:26Z
      extensions.gateway.mulesoft.com       2022-06-03T05:16:26Z
      policybindings.gateway.mulesoft.com   2022-06-03T05:16:26Z
      services.gateway.mulesoft.com         2022-06-03T05:16:26Z

