---
title: Kubeblocks Tutorial 201 - Seamless Upgrades & Basic Maintenance
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

createdAt: 2025-01-16
updatedAt: 2025-01-16

categories:
  - kubernetes
  - databases

tagz:
  - kubernetes
  - databases

tasks:
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
      helm -n kb-system install kubeblocks kubeblocks/kubeblocks --version 0.9.2 \
      --set image.registry=docker.io \
      --set dataProtection.image.registry=docker.io \
      --set addonChartsImage.registry=docker.io \
      --create-namespace
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
---

Welcome to the **second chapter** of our **KubeBlocks** tutorial series!

In this guide, we will focus on **seamless upgrades** and **basic maintenance**—two core features that showcase KubeBlocks’ ability to run **any database** at **Operator Capability Level 5**, suitable for **production-grade** operations. Whether you’re managing a small dev cluster or a large-scale enterprise environment, KubeBlocks streamlines the entire database lifecycle on Kubernetes.

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

When you’re ready, you can verify the environment with the following tasks:

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
Output: 
```
NAME                READY   STATUS    RESTARTS   AGE
mycluster-mysql-0   4/4     Running   0          16s
mycluster-mysql-1   4/4     Running   0          16s
mycluster-mysql-2   4/4     Running   0          16s
```

### 1.2. High Availability Demonstration

```bash
kubectl get pods -n demo -o yaml | grep kubeblocks.io/role
```
Output:
```
kubeblocks.io/role: secondary
kubeblocks.io/role: primary
kubeblocks.io/role: secondary
```

As shown, `mycluster-mysql-1` is the **primary**, while the others are **secondary**. Let’s try removing the primary Pod to see how KubeBlocks handles high availability:

```bash
kubectl delete pod mycluster-mysql-1 -n demo
```

A new Pod (`mycluster-mysql-1`) will be created, and KubeBlocks will automatically elect one of the secondaries as the new primary. All data remains intact—demonstrating KubeBlocks’ built-in HA capabilities.

---

## 2. Preparing for an Upgrade

Before upgrading:
- **Check the current cluster version** and the readiness of your setup.

```bash
# Look for MySQL versions recognized by KubeBlocks
kubectl get clusterversion | grep mysql
```
```bash
laborant@dev-machine:~$ kubectl get clusterversion | grep mysql
Warning: The ClusterVersion CRD has been deprecated since 0.9.0
ac-mysql-8.0.30      apecloud-mysql       Available   2m55s
ac-mysql-8.0.30-1    apecloud-mysql       Available   2m55s
mysql-5.7.44         mysql                Available   2m56s
mysql-8.0.33         mysql                Available   2m56s
mysql-8.4.2          mysql                Available   2m56s
```

---

## 3. Performing a Rolling Upgrade

Now, let’s **perform a rolling upgrade** to a newer MySQL version. KubeBlocks orchestrates this process Pod-by-Pod to maintain availability.

1. **Edit the `Cluster` resource** to bump your MySQL version, for example to `mysql-8.4.2` (fictional for demo):

   ```bash
   kubectl edit cluster mycluster -n demo
   # Modify:
   # spec:
   #   clusterVersionRef: mysql-8.4.2
   ```

2. **Monitor the upgrade** process:

   ```bash
   kbcli cluster describe-ops <your-ops-request-name> -n demo
   ```

3. **Verify** that the Pods upgrade sequentially with minimal or zero downtime.

---

## 4. Automated Upgrades

To truly embrace “seamless upgrades,” you can configure **auto-upgrade policies** so that minor or patch releases are applied automatically—no manual intervention needed. KubeBlocks ensures a safe, rolling approach, typically starting with secondaries before handling the primary.

```bash
# Check MySQL Pod states again
kubectl get pods -n demo
# You should see sequential restarts or upgrades, starting with secondaries.
```

---

## 6. Post-Maintenance Validation

After the upgrade (or any maintenance operation), **validate**:

- **Logs & Metrics**: Confirm no errors or warnings in the logs.
- **Connectivity**: Ensure apps or clients can still connect to the cluster.
- **Replication & Roles**: Check that the primary/secondary relationships are intact.

---

## 9. What’s Next?

- **Explore** other databases (PostgreSQL, Redis, MongoDB, Elasticsearch, Qdrant, etc.) on KubeBlocks.
- **Continue** to the next tutorial, where we’ll dive into **full lifecycle management** (backups, restores, and failover), further showcasing how KubeBlocks simplifies production-grade database operations.

---

## Final Thoughts

KubeBlocks provides a **production-ready** approach to database management on Kubernetes. By mastering **seamless upgrades** and basic maintenance tasks, you’re well on your way to tackling more advanced features such as backup, restore, high availability, and beyond—all while harnessing the power of Kubernetes orchestration.

Stay tuned for future tutorials in this series, where we’ll explore even more of KubeBlocks’ capabilities and show you how to run **any database** with confidence at **Operator Capability Level 5**. Enjoy your newfound mastery of cloud-native database operations!
