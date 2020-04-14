#!/usr/bin/env bash
# exit immediately when a command fails
set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail
# error on unset variables
set -u
# print each command before executing it
set -x

#
# NOTE: This script was originally copied from the CoreOs Prometheus Operator build
# https://github.com/coreos/prometheus-operator/blob/master/scripts/create-minikube.sh

# socat is needed for port forwarding
sudo apt-get update && sudo apt-get install socat

#export MINIKUBE_VERSION=v1.0.0
export KUBERNETES_VERSION=v1.14.0

MINIKUBE=$(which minikube) # it's outside of the regular PATH, so, need the full path when calling with sudo

sudo mount --make-rshared /
sudo mount --make-rshared /proc
sudo mount --make-rshared /sys

mkdir "${HOME}"/.kube || true
touch "${HOME}"/.kube/config
cat /etc/resolv.conf

cat /run/systemd/resolve/resolv.conf || true

# minikube config
minikube config set WantNoneDriverWarning false
minikube config set vm-driver none

minikube version
sudo ${MINIKUBE} delete
sudo ${MINIKUBE} start --kubernetes-version=$KUBERNETES_VERSION --extra-config=apiserver.authorization-mode=RBAC
sudo chown -R $USER $HOME/.kube $HOME/.minikube

minikube update-context

# waiting for node(s) to be ready
echo FIRST
JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'; until kubectl get nodes -o jsonpath="$JSONPATH" 2>&1 | grep -q "Ready=True"; do sleep 1; done

# waiting for kube-addon-manager to be ready
echo SECOND
JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'; until kubectl -n kube-system get pods -lcomponent=kube-addon-manager -o jsonpath="$JSONPATH" 2>&1 | grep -q "Ready=True"; do sleep 1;echo "waiting for kube-addon-manager to be available"; kubectl get pods --all-namespaces; done

# waiting for kube-dns to be ready
# kubectl -n kube-system get pods -lk8s-app=kube-dns
kubectl get pods --all-namespaces


# Get the log from one of the dns pods
export ONEDNSPOD=$(kubectl --namespace kube-system get pods -lk8s-app=kube-dns | grep coredns | head -1 | awk '{print $1}')
kubectl wait --for=condition=Ready pod/${ONEDNSPOD} --namespace kube-system --timeout=60s || true
kubectl logs --namespace kube-system $ONEDNSPOD

###### JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'; until kubectl -n kube-system get pods -lk8s-app=kube-dns -o jsonpath="$JSONPATH" 2>&1 | grep -q "Ready=True"; do sleep 1;echo "waiting for kube-dns to be available"; kubectl get pods --all-namespaces; done

sudo ${MINIKUBE} addons enable ingress

eval $(minikube docker-env)