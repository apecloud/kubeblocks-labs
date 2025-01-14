---
title: Kubeblocks Tutorial 101
description: |
  Learn how to run any database on Kubernetes with KubeBlocks!

kind: tutorial

playground:
  name: k3s

  tabs:
    - id: ide-dev-machine
      kind: ide
      name: IDE
      machine: dev-machine

    - id: kexp-dev-machine
      kind: kexp
      name: Explorer
      machine: dev-machine

    - id: terminal-dev-machine
      kind: terminal
      name: dev-machine
      machine: dev-machine

    - id: terminal-cplane-01
      kind: terminal
      name: cplane-01
      machine: cplane-01

    - id: terminal-node-01
      kind: terminal
      name: node-01
      machine: node-01

    - id: terminal-node-02
      kind: terminal
      name: node-02
      machine: node-02

  machines:
    - name: dev-machine
      users:
        - name: root
        - name: laborant
          default: true
      resources:
        cpuCount: 2
        ramSize: "4G"

    - name: cplane-01
      users:
        - name: root
        - name: laborant
          default: true
      resources:
        cpuCount: 2
        ramSize: "4G"

    - name: node-01
      users:
        - name: root
        - name: laborant
          default: true
      resources:
        cpuCount: 2
        ramSize: "4G"

    - name: node-02
      users:
        - name: root
        - name: laborant
          default: true
      resources:
        cpuCount: 2
        ramSize: "4G"

cover: __static__/kubeblocks-arch.png

createdAt: 2023-11-14
updatedAt: 2023-12-02

categories:
  - kubernetes
  - databases

tagz:
  - kubernetes
  - databases

tasks:
#  # 1) Initialization task
#  init_task_1:
#    init: true
#    user: laborant
#    run: |
#      # Example command: running a simple Docker container on dev-machine
#      docker run hello-world

  # 2) Task to verify kbcli is installed
  verify_kbcli_installation:
    run: |
      kbcli --help

  # 3) Task to verify KubeBlocks is installed
  verify_kubeblocks_installation:
    run: |
      output="$(kubectl get deployment -n kb-system 2>&1)"
      echo "controlplane \$ k get deployment -n kb-system"
      echo "$output"
      if echo "$output" | grep -q "kb-addon-snapshot-controller" \
          && echo "$output" | grep -q "kubeblocks " \
          && echo "$output" | grep -q "kubeblocks-dataprotection" \
          && echo "$output" | grep -q "1/1"
      then
          echo "done"
          exit 0
      else
          echo "not ready yet"
          exit 1
      fi

  # 4) Task to verify MySQL Pod is ready
  verify_mysql_pod_ready:
    needs:
      - verify_kubeblocks_installation
    run: |
      output="$(kubectl get pods -n demo 2>&1 || true)"
      echo "controlplane \$ kubectl get pods -n demo"
      echo "$output"
      if echo "$output" | grep -q "mycluster-mysql-0.*4/4.*Running"; then
        echo "done"
        exit 0
      else
        echo "not ready yet"
        exit 1
      fi
---

Welcome to this **KubeBlocks** tutorial!

[KubeBlocks](https://kubeblocks.io/) is a Kubernetes Operator that allows you to deploy and manage databases and stateful applications seamlessly. With a strong emphasis on **“Run Any Database on KubeBlocks,”** you can effortlessly spin up popular databases such as MySQL, PostgreSQL, Redis, and more on your Kubernetes cluster.

In this guide, you will:
1. Install KubeBlocks and its command-line interface (CLI).
2. Create and connect to a MySQL cluster.

Below is a quick overview of KubeBlocks’s architecture.

::image-box
---
src: __static__/kubeblocks-arch.png
alt: 'KubeBlocks architecture'
---
::

Let’s dive in!

---

## 1. Install the KubeBlocks CLI

First, install the KubeBlocks CLI tool to interact with KubeBlocks resources easily.

```bash
export KB_CLI_VERSION=v0.9.2
curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash -s $KB_CLI_VERSION
```

::simple-task
---
:tasks: tasks
:name: verify_kbcli_installation
---
#active
Waiting for the `kbcli` installation to complete...

#completed
Yay! The `kbcli` installation is successful. 🎉
::

Once the installation completes, verify that the `kbcli` command is available:

```bash
kbcli --help
```

You should see a help message listing available `kbcli` commands.

---

## 2. Install KubeBlocks

This step merges the installation of CRDs, adding the KubeBlocks Helm repository, and installing KubeBlocks with Helm into a single procedure.

### 2.1. Install the KubeBlocks CRDs

Install the Custom Resource Definitions (CRDs) required by KubeBlocks. These CRDs define the additional Kubernetes objects that KubeBlocks will manage (e.g., database clusters).

```bash
export KB_VERSION=v0.9.2
kubectl create -f https://github.com/apecloud/kubeblocks/releases/download/$KB_VERSION/kubeblocks_crds.yaml
```

### 2.2. Add the KubeBlocks Helm Repository

Before installing KubeBlocks itself, add the official Helm repository and update your local Helm cache:

```bash
helm repo add kubeblocks https://apecloud.github.io/helm-charts
helm repo update
```

### 2.3. Install KubeBlocks with Helm

You’re now ready to install KubeBlocks:

```bash
helm -n kb-system install kubeblocks kubeblocks/kubeblocks --version 0.9.2 \
  --set image.registry=docker.io \
  --set dataProtection.image.registry=docker.io \
  --set addonChartsImage.registry=docker.io \
  --create-namespace
```

This command:
- Creates a new namespace called **kb-system** (if it doesn’t exist).
- Installs the KubeBlocks operator and required services into your cluster.

Once the installation finishes, check the status of the newly created Pods:

```bash
kubectl get pods -n kb-system
```

Within a few minutes, you should see KubeBlocks-related Pods in a **Running** status.

::simple-task
---
:tasks: tasks
:name: verify_kubeblocks_installation
---
#active
Waiting for the KubeBlocks installation to complete...

#completed
Yay! The KubeBlocks installation is successful. You are now ready to deploy a cluster. 🎉
::

---

## 3. Deploy a MySQL Cluster

Now that KubeBlocks is installed, let’s see it in action by deploying a MySQL cluster.

### 3.1. Create the MySQL Cluster

Use the following YAML to create a MySQL cluster named **mycluster** in the `demo` namespace, with minimal CPU and memory:

```bash
kubectl create namespace demo
cat <<EOF | kubectl apply -f -
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: mycluster
  namespace: demo
spec:
  clusterDefinitionRef: mysql
  clusterVersionRef: mysql-8.0.33
  terminationPolicy: Delete
  affinity:
    podAntiAffinity: Preferred
    topologyKeys:
    - kubernetes.io/hostname
  tolerations:
    - key: kb-data
      operator: Equal
      value: 'true'
      effect: NoSchedule
  componentSpecs:
  - name: mysql
    componentDefRef: mysql
    enabledLogs:
    - error
    - slow
    disableExporter: true
    replicas: 1
    serviceAccountName: kb-mycluster
    resources:
      limits:
        cpu: '0.5'
        memory: 0.5Gi
      requests:
        cpu: '0.5'
        memory: 0.5Gi
    volumeClaimTemplates:
    - name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
EOF
```

KubeBlocks will then spin up the necessary resources in your Kubernetes cluster.

Check the status of the Pods to see when they become ready:

```bash
kubectl get pods -n demo
```

After a few moments, you should see something like:

```
NAME                READY   STATUS    RESTARTS   AGE
mycluster-mysql-0   4/4     Running   0          <some time>
```

::simple-task
---
:tasks: tasks
:name: verify_mysql_pod_ready
---
#active
Waiting for the MySQL Pod to become ready...

#completed
Yay! The MySQL Pod is up and running. You can now connect to it. 🎉
::

### 3.2. Connect to the MySQL Cluster

To verify the database is available, wait for port 3306 to open on the MySQL Pod:

```bash
kubectl -n demo exec mycluster-mysql-0 -- sh -c 'until mysqladmin ping -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD --silent; do echo "Waiting for MySQL on port 3306..." && sleep 5; done'
```

Once the above check succeeds, connect to the MySQL server directly:

```bash
kubectl -n demo exec -it mycluster-mysql-0 -- bash -c 'mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD'
```

You will then be greeted by a MySQL shell prompt. Congratulations, you are now connected to your new MySQL cluster running on KubeBlocks!

---

## What’s Next?

- Explore other databases (PostgreSQL, Redis, MongoDB, and more) using the same KubeBlocks workflow.
- Adjust CPU/memory limits or scale the replica count for high availability.

## Conclusion

You have successfully:

1. Installed **KubeBlocks** on your Kubernetes cluster (CRDs, Helm repo, and Operator).
2. Deployed a **MySQL** cluster.
3. Connected to MySQL within the same cluster.

KubeBlocks provides a convenient way to **run any database on Kubernetes** with minimal friction, empowering you to standardize database operations in a cloud-native manner.

For more detailed usage and advanced configuration, check out the [official KubeBlocks documentation](https://kubeblocks.io/). Enjoy your new, streamlined database management capabilities on Kubernetes!
