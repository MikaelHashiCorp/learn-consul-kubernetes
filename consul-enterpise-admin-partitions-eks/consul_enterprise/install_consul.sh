#!/usr/bin/env bash

set -e

SECONDARY=${CURRENT_KUBE_CONTEXT}
PRIMARY=${CONSUL_PRIMARY}
CONSUL_DEPLOY_TYPE=${CONSUL_DEPLOY_TYPE}

if [ "${CONSUL_DEPLOY_TYPE}" = "server" ]; then
  helm install --wait hashicorp-"${CONSUL_DEPLOY_TYPE}" hashicorp/consul -f ./consul-values-"${CONSUL_DEPLOY_TYPE}".yaml
  # Commented out, but this is the order of operations in which to deploy client cluster resources
#  kubectl apply -f ./hashicups/crds/proxydefaults-all.yaml
#  kubectl apply -f ./hashicups/crds/crd-exported-service-"${CONSUL_PRIMARY}"
#  kubectl apply -f ./hashicups/crds/crd-intentions.yaml
#  kubectl apply -f ./hashicups/postgres.yaml
else
  kubectl config use-context "${PRIMARY}"

  kubectl get secret server-bootstrap-acl-token --context "${PRIMARY}" -o yaml | kubectl apply --context "${SECONDARY}" -f -
  kubectl get secret server-ca-key --context "${PRIMARY}" -o yaml | kubectl apply --context "${SECONDARY}" -f -
  kubectl get secret server-ca-cert --context "${PRIMARY}" -o yaml | kubectl apply --context "${SECONDARY}" -f -
  kubectl get secret server-client-acl-token --context "${PRIMARY}" -o yaml | kubectl apply --context "${SECONDARY}" -f -
  kubectl get secret server-gossip-encryption-key --context "${PRIMARY}" -o yaml | kubectl apply --context "${SECONDARY}" -f -
  kubectl get secret server-partitions-acl-token --context "${PRIMARY}" -o yaml | kubectl apply --context "${SECONDARY}" -f -

  PartitionIp=$(kubectl get svc | grep -i "LoadBalancer" | awk \{'print $4'\})
  #TERM=dumb removes ANSI color coding from this command. See: https://github.com/kubernetes/kubernetes/issues/5698#issuecomment-566125254
  ControlPlaneHost=$(TERM=dumb kubectl --context "${SECONDARY}" cluster-info | grep -i "kubernetes control plane" | awk \{'print $NF'\})
  yq e ".externalServers.k8sAuthMethodHost = \"${ControlPlaneHost}\"" -i ./consul-values-"${CONSUL_DEPLOY_TYPE}".yaml
  yq e ".client.join = [\"${PartitionIp}\"]" -i ./consul-values-"${CONSUL_DEPLOY_TYPE}".yaml
  yq e ".externalServers.hosts = [\"${PartitionIp}\"]" -i ./consul-values-"${CONSUL_DEPLOY_TYPE}".yaml
  kubectl config use-context "${SECONDARY}"
  helm install --wait hashicorp-"${CONSUL_DEPLOY_TYPE}" hashicorp/consul -f ./consul-values-"${CONSUL_DEPLOY_TYPE}".yaml
# Commented out, but this is the order of operations in which to deploy client cluster resources
#  kubectl apply -f ./hashicups/crds/proxydefaults-all.yaml
#  kubectl apply -f ./hashicups/crds/crd-exported-service-"${SECONDARY}"
#  kubectl apply -f ./hashicups/crds/crd-intentions.yaml
#  kubectl apply -f ./hashicups/products-api.yaml
#  kubectl apply -f ./hashicups/public-api.yaml
#  kubectl apply -f ./hashicups/payments.yaml
#  kubectl apply -f ./hashicups/frontend.yaml
fi