---
title: Kubeblocks Tutorial 201 - Seamless Upgrades
description: |
  Learn how to run any database on Kubernetes with KubeBlocks!

kind: tutorial

playground:
  name: k3s

   # Protect the playground's registry (registry.iximiuz.com) with a username and password.
   # default: no authentication
  registryAuth: testuser:testpassword

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

cover: __static__/mysql-upgrade-process-c.png

createdAt: 2025-01-16
updatedAt: 2025-01-16

categories:
  - kubernetes
  - databases

tagz:
  - kubernetes
  - databases

tasks:
  init_use_docker_hub_mirror:
    init: true
    run: |
      echo 'DOCKER_OPTS="${DOCKER_OPTS} --registry-mirror=https://mirror.gcr.io"' >> /etc/default/docker
      systemctl restart docker

  # 1) Initialization task
  init_task_1:
    init: true
    user: laborant
    run: |
      export KB_CLI_VERSION=v0.9.2
      curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash -s $KB_CLI_VERSION
      export KB_VERSION=v0.9.2
      kubectl create -f https://github.com/apecloud/kubeblocks/releases/download/$KB_VERSION/kubeblocks_crds.yaml
      helm repo add kubeblocks https://apecloud.github.io/helm-charts
      helm repo update
      # helm -n kb-system install kubeblocks kubeblocks/kubeblocks --version 0.9.2 \
      # --set image.registry=docker.io \
      # --set dataProtection.image.registry=docker.io \
      # --set addonChartsImage.registry=docker.io \
      # --create-namespace
      helm -n kb-system install kubeblocks kubeblocks/kubeblocks --version 0.9.2 --create-namespace
      kbcli addon enable mysql --set image.registry=apecloud-registry.cn-zhangjiakou.cr.aliyuncs.com --set images.registry=apecloud-registry.cn-zhangjiakou.cr.aliyuncs.com
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
          replicas: 3
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

  verify_cluster_upgrade:
    needs:
      - verify_mysql_pod_ready
    run: |
      output="$(kubectl get opsrequest mysql-upgrade -n demo -o jsonpath='{.status.status}' 2>&1)"
      echo "controlplane \$ kubectl get opsrequest mysql-upgrade -n demo -o jsonpath='{.status.status}'"
      echo "$output"

      if [ "$output" = "Succeed" ]; then
        echo "done - cluster upgrade operation completed successfully"
        exit 0
      else
        echo "upgrade not complete - current status: $output"
        exit 1
      fi
---

Welcome to the **second chapter** of our **KubeBlocks** tutorial series!

In this guide, we focus on **seamless upgrades**—a key feature that aligns with **Operator Capability Level 2**. You’ll see how KubeBlocks keeps your databases updated **with minimal downtime**, even in a production-grade environment. Whether you’re managing a small dev cluster or a large-scale enterprise deployment, KubeBlocks streamlines the entire **database lifecycle** on Kubernetes, and can scale up to even more advanced capabilities.

::image-box
---
src: __static__/operator-capability-level.png
alt: 'Operator Capability Level'
---
::

## Prerequisites

To save you time, we’ve **automatically installed KubeBlocks** and created a **3-replica MySQL cluster** in the background. It may take a few minutes to complete the setup—feel free to proceed, but keep in mind that some commands might need to wait until the installation is fully finished.

If you’re new to KubeBlocks or missed the first tutorial, see:
[Kubeblocks Tutorial 101 – Getting Started](https://labs.iximiuz.com/tutorials/kubeblocks-101-99db8bca)

::simple-task
---
:tasks: tasks
:name: verify_kbcli_installation
---
#active
Confirming the `kbcli` CLI tool is installed...

#completed
Great! The `kbcli` CLI is available.
::

::simple-task
---
:tasks: tasks
:name: verify_kubeblocks_installation
---
#active
Waiting for the KubeBlocks operator pods to be in a ready state...

#completed
All KubeBlocks components are installed and running!
::

::simple-task
---
:tasks: tasks
:name: verify_mysql_pod_ready
---
#active
Waiting for the MySQL Pods to become ready...

#completed
Yay! Your MySQL cluster is ready. 🎉
::

---

## 1. Introduction & Review

### 1.1. Checking Your MySQL Cluster

By default, a **3-replica** MySQL cluster named `mycluster` has been created in the `demo` namespace:

```bash
kubectl get pods -n demo
```

Example output:

```
NAME                READY   STATUS    RESTARTS   AGE
mycluster-mysql-0   4/4     Running   0          16s
mycluster-mysql-1   4/4     Running   0          16s
mycluster-mysql-2   4/4     Running   0          16s
```

### 1.2. High Availability Demonstration

KubeBlocks automatically configures one of these Pods as the **primary** database instance, while the rest act as **secondaries**. To see which is which, run:

```bash
kubectl get pods -n demo -o yaml | grep kubeblocks.io/role
```

You may see something like:

```
kubeblocks.io/role: secondary
kubeblocks.io/role: primary
kubeblocks.io/role: secondary
```

In this example, `mycluster-mysql-1` is the **primary**, but keep in mind the actual Pod name assigned as primary in your environment could be different (e.g., `mycluster-mysql-0` or `mycluster-mysql-2`).

To illustrate KubeBlocks’ built-in **High Availability (HA)**, try **removing the primary Pod**:

```bash
kubectl delete pod mycluster-mysql-1 -n demo
```

Shortly after deletion, KubeBlocks will:

1. **Promote** one of the secondaries to become the new primary.
2. **Restart** the removed Pod (e.g., `mycluster-mysql-1`).
3. **Maintain** data consistency across replicas throughout the process.

When you run `kubectl get pods -n demo` again, you’ll see that the removed Pod is **recreated** and that a **new primary** has been automatically elected. No manual intervention is needed, and **no data is lost**. This seamless recovery demonstrates why KubeBlocks is ideal for production-grade environments where minimal downtime is crucial.

---

## 2. Upgrade a Cluster

Upgrading your database version is a key maintenance task. KubeBlocks orchestrates a **rolling upgrade**—updating pods one at a time to keep your database highly available throughout the process.

### 2.1 View Available MySQL Versions

Before starting an upgrade, **check which MySQL versions** KubeBlocks can deploy:

```bash
kubectl get clusterversion | grep mysql
```

Example output (your environment may differ):

```
Warning: The ClusterVersion CRD has been deprecated since 0.9.0
ac-mysql-8.0.30      apecloud-mysql       Available   2m55s
ac-mysql-8.0.30-1    apecloud-mysql       Available   2m55s
mysql-5.7.44         mysql                Available   2m56s
mysql-8.0.33         mysql                Available   2m56s
mysql-8.4.2          mysql                Available   2m56s
```

### 2.2 Performing a Rolling Upgrade

Let’s say you want to upgrade from `mysql-8.0.33` to **`mysql-8.4.2`**. KubeBlocks will:

1. **Create a OpsRequest** to instruct `KubeBlocks Operator` to upgrade the cluster.
2. **Sequentially** take each secondary offline, upgrade it, bring it back up, and then move on.
3. **Upgrade** the primary last, typically with a secondary promoted temporarily if necessary to avoid downtime.

**1\. Patch the cluster**:

```bash
kubectl apply -f - <<EOF
apiVersion: apps.kubeblocks.io/v1alpha1
kind: OpsRequest
metadata:
  name: mysql-upgrade
  namespace: demo
spec:
  clusterRef: mycluster
  type: Upgrade 
  upgrade:
    clusterVersionRef: mysql-8.4.2
EOF
```

This instructs KubeBlocks to begin upgrading the `mycluster` to `mysql-8.4.2`.

::simple-task
---
:tasks: tasks
:name: verify_cluster_upgrade
---
#active
Waiting for the MySQL Cluster to be upgraded to version `mysql-8.4.2`...

#completed
Yay! Your MySQL cluster has been successfully upgraded to version `mysql-8.4.2`. 🎉
::

**2\. Monitor the rolling update**:

```bash
kubectl get pods -n demo
```

You should see the Pods being updated one by one.

**2\. Validate** that the cluster remains operational:

- **Check Pod Status**: Ensure each Pod transitions through `Running` and `Ready` states in a sequence.
- **Confirm New Version**: Once all Pods have been upgraded, you can connect to MySQL and run:
```bash
kubectl -n demo exec -it mycluster-mysql-0 -- bash -c 'mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT @@version;"'
```
to ensure that the reported version matches `8.4.2`.

If everything goes smoothly, you’ve completed a **seamless rolling upgrade** with minimal or zero downtime. Your applications should remain connected throughout.

### 2.3 Understanding the Rolling Upgrade Process

During the rolling upgrade, KubeBlocks follows a carefully orchestrated sequence:

::image-box
---
src: __static__/mysql-upgrade-process-c.png
alt: 'Operator Capability Level'
---
::

1. **Initial State**: mysql-2 serves as Primary, with mysql-0 and mysql-1 as Secondaries.
2. **Secondary Upgrades**:
    - First upgrades mysql-0 (Secondary)
    - Then upgrades mysql-1 (Secondary)
3. **Primary Switch**:
    - Promotes mysql-0 to become the new Primary
4. **Final Upgrade**:
    - Upgrades the original Primary (mysql-2)
    - mysql-2 becomes a Secondary in the new configuration

This careful sequencing ensures:
- Minimal downtime during the upgrade
- Data consistency throughout the process
- Automatic handling of Primary/Secondary roles
- Safe rollback capability if issues occur

---

## What’s Next?

- **Explore Other Databases**: Apply the same upgrade principles to PostgreSQL, Redis, MongoDB, Elasticsearch, Qdrant, and more.
- **Advance to the Next Tutorial**: Discover **full lifecycle management**—including backups, restores, and failover—showing how KubeBlocks delivers robust database operations that approach **higher Operator Capability Levels**.

By leveraging KubeBlocks’ built-in intelligence for upgrade orchestration and HA failover, you can keep your database versions current and reliable with ease.