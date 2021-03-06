#!/bin/bash

set -euo pipefail

if [ $# -ne 2 ]
  then
    echo "Usage: ${0} <run-name> <num-nodes>"
    exit 1
fi

run_name=${1?}
golang_commit=
num_nodes=${2:-2500}

log() { echo $1 | ts | tee -a ${log_file}; }


apply_patch() {
 cl_id=${1?}
 revision=${2?}

 echo "Applying patch ${cl_id} at revision ${revision}"

 wget https://go-review.googlesource.com/changes/go~${cl_id}/revisions/${revision}/patch?zip -O patch.zip
 unzip patch.zip && rm patch.zip
 git apply --3way *.diff
 rm *.diff
 git add .
 git commit -a -m "Applied ${cl_id} revision ${revision}"
}

build_golang() {
  echo "Building golang for $run_name"

  cd ~/golang/go/src
  git checkout master
  git pull

  git checkout 7b62e98

  git branch -D ${run_name} || true
  git checkout -b ${run_name}


  #git revert f1a8ca30fcaa91803c353999448f6f3a292f1db1 --no-edit
  #apply_patch 186598 3

  ./make.bash

  cd -
}

build_k8s() {
  log "Building k8s"

  cd $GOPATH/src/k8s.io/kubernetes
  git checkout $k8s_branch

  cd build/build-image/cross/
  rm -rf go || true
  cp -R ~/golang/go/ go

  echo "$run_name" > VERSION

  git add .
  git commit -a -m "Update golang version for run ${run_name}"

  make build

  cd -
  make clean quick-release
}


log_dir=~/log/${run_name}
mkdir -p ${log_dir}
log_file=${log_dir}/log_$(date +%Y%m%d_%H%M%S)

log "Running the ${run_name} test with ${num_nodes} nodes"

k8s_branch=golang_kubemark_932487c7440b05_no_patches
perf_test_branch=golang1.13
test_infra_commit=63eb09459


build_golang 2>&1 | ts | tee -a ${log_file}
build_k8s 2>&1 | ts | tee -a ${log_file}


log "k8s.io/perf-tests branch is: $perf_test_branch"
log "k8s.io/test-infra commit is: $test_infra_commit"


go install k8s.io/test-infra/kubetest

cd ~/go/src/k8s.io/perf-tests && git checkout ${perf_test_branch} && cd -

source $GOPATH/src/github.com/mm4tt/k8s-util/set-common-envs/set-common-envs.sh preset-e2e-kubemark-common ${test_infra_commit}
source $GOPATH/src/github.com/mm4tt/k8s-util/set-common-envs/set-common-envs.sh preset-e2e-kubemark-gce-scale ${test_infra_commit}

export PROJECT=mmatejczyk-gke-dev
export ZONE=us-east1-b

export HEAPSTER_MACHINE_TYPE=n1-standard-32
export KUBE_DNS_MEMORY_LIMIT=300Mi

export CLUSTER=${run_name}
export KUBE_GCE_NETWORK=${CLUSTER}
export INSTANCE_PREFIX=${CLUSTER}
export KUBE_GCE_INSTANCE_PREFIX=${CLUSTER}

go run hack/e2e.go -- \
    --gcp-project=$PROJECT \
    --gcp-zone=$ZONE \
    --cluster=$CLUSTER \
    --gcp-node-size=n1-standard-8 \
    --gcp-nodes=50 \
    --provider=gce \
    --kubemark \
    --kubemark-nodes=$num_nodes \
    --check-version-skew=false \
    --up \
    --down \
    --test=false \
    --test-cmd=$GOPATH/src/k8s.io/perf-tests/run-e2e.sh \
    --test-cmd-args=cluster-loader2 \
    --test-cmd-args=--enable-prometheus-server=true \
    --test-cmd-args=--experimental-gcp-snapshot-prometheus-disk=true \
    --test-cmd-args=--experimental-prometheus-disk-snapshot-name="${run_name}" \
    --test-cmd-args=--nodes=$num_nodes \
    --test-cmd-args=--provider=kubemark \
    --test-cmd-args=--report-dir=/tmp/${run_name}/artifacts \
    --test-cmd-args=--tear-down-prometheus-server=true \
    --test-cmd-args=--testconfig=$GOPATH/src/k8s.io/perf-tests/clusterloader2/testing/load/config.yaml \
    --test-cmd-args=--testoverrides=./testing/load/kubemark/throughput_override.yaml \
    --test-cmd-name=ClusterLoaderV2 2>&1 | ts | tee -a ${log_file}
