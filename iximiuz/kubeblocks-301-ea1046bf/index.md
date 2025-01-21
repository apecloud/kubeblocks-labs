---
title: KubeBlocks Tutorial 301 - Backup & Restore
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

cover: __static__/backup-restore.png

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
      sudo rm -rf /usr/local/bin/kbcli
      export KB_CLI_VERSION=v0.9.2
      curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash -s $KB_CLI_VERSION
      export KB_VERSION=v0.9.2
      kubectl create -f https://github.com/apecloud/kubeblocks/releases/download/$KB_VERSION/kubeblocks_crds.yaml
      helm repo add kubeblocks https://apecloud.github.io/helm-charts
      helm repo update
      helm -n kb-system install kubeblocks kubeblocks/kubeblocks --version 0.9.2 --set dataProtection.encryptionKey='S!B\*d$zDsb=' --create-namespace
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
      cat <<EOF | kubectl apply -f -
      apiVersion: dataprotection.kubeblocks.io/v1alpha1
      kind: BackupRepo
      metadata:
        name: backuprepo
        namespace: demo
        annotations:
          dataprotection.kubeblocks.io/is-default-repo: "true"
      spec:
        accessMethod: Mount
        config:
          accessMode: ReadWriteOnce
          storageClassName: local-path
          volumeMode: Filesystem
        pvReclaimPolicy: Retain
        storageProviderRef: pvc
        volumeCapacity: 20Gi
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
      output="$(kubectl get opsrequest mysql-upgrade -n demo | grep Succeed)"
      echo "controlplane $ kubectl get opsrequest mysql-upgrade -n demo | grep Succeed"
      echo "$output"

      if [ -n "$output" ]; then
        echo "done - cluster upgrade operation completed successfully" 
        exit 0
      else
        status=$(kubectl get opsrequest mysql-upgrade -n demo)
        echo "upgrade not complete - current status: $status"
        exit 1
      fi
    hintcheck: |
      kubectl get opsrequest -n demo | grep mysql-upgrade

  verify_trigger_backup:
    needs:
      - verify_mysql_pod_ready
    run: |
      output="$(kubectl get backup -n demo)"
      echo "controlplane $ kubectl get backup -n demo"
      echo "$output"

      if [ -n "$output" ]; then
        echo "done - backup was triggered successfully"
        exit 0
      else
        echo "backup not found"
        exit 1
      fi
    hintcheck: |
      kubectl get backup -n demo

  verify_backup_progress:
    needs:
      - verify_trigger_backup
    run: |
      output="$(kubectl get backup mybackup -n demo | grep Completed)"
      echo "controlplane $ kubectl get backup mybackup -n demo | grep Completed"
      echo "$output"

      if [ -n "$output" ]; then
        echo "done - backup operation completed successfully"
        exit 0
      else
        status=$(kubectl get backup mybackup -n demo)
        echo "backup not complete - current status: $status"
        exit 1
      fi
    hintcheck: |
      kubectl get backup -n demo | grep mybackup

  verify_restore_trigger:
    needs:
      - verify_backup_progress
    run: |
      output="$(kubectl get cluster myrestore -n demo)"
      echo "controlplane $ kubectl get cluster myrestore -n demo"
      echo "$output"

      if [ -n "$output" ]; then
        echo "done - restore cluster was created successfully"
        exit 0
      else
        echo "restore cluster not found"
        exit 1
      fi
    hintcheck: |
      kubectl get cluster -n demo
---

Welcome to the **third chapter** of our **KubeBlocks** tutorial series!

In this tutorial, we’ll focus on **backup & restore** — a crucial component of **Operator Capability Level 3**, which emphasizes **full lifecycle management** of databases on Kubernetes. We’ll now address why backups and restores are **vital for production environments**, how to create them with **minimal downtime**, and how to safely and quickly recover data when needed.

::image-box
---
src: __static__/operator-capability-level.png
alt: 'Operator Capability Level'
---
::

## Prerequisites

To save you time, we’ve **automatically installed KubeBlocks** and created a **3-replica MySQL cluster** in the background. It may take a few minutes to complete the setup—feel free to proceed, but keep in mind that some commands might need to wait until the installation is fully finished.

If you’re new to KubeBlocks or missed the previous tutorials, see:
- [KubeBlocks Tutorial 101 – Getting Started](/tutorials/kubeblocks-101-99db8bca)
- [KubeBlocks Tutorial 201 - Seamless Upgrades](/tutorials/kubeblocks-201-83b9a997)

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

## 1. Introduction

In this lab environment, you should already have:
- **KubeBlocks** installed.
- A **3-replica MySQL cluster** named `mycluster` in the `demo` namespace.

Verify that the cluster is running:

```bash
kubectl get pods -n demo
```

You should see something like:

```
NAME                READY   STATUS    RESTARTS   AGE
mycluster-mysql-0   4/4     Running   0          2m
mycluster-mysql-1   4/4     Running   0          2m
mycluster-mysql-2   4/4     Running   0          2m
```

This same cluster will be used to demonstrate **backup & restore** features.

**Optional: Add Sample Data**  
Before proceeding, you may want to **connect to your MySQL cluster** and create some test data. For example:

```bash
kbcli cluster connect mycluster -n demo
```

Once connected, create your own database, tables, and sample records (e.g., `CREATE DATABASE test;`, `CREATE TABLE test.mytable ...;`, `INSERT INTO test.mytable ...;`) so that you can confirm the backup and restore processes successfully carry over any data you create.

---

Below is a **simplified** version of the *Backup Basics* section, emphasizing the **key points** while maintaining clarity and readability:

---

## 2. Backup Basics

KubeBlocks provides **comprehensive backup and restore capabilities** to protect your database data. All backups require a **BackupRepo**, where backup artifacts are stored—this can be **object storage** or **PVC-based** volumes.

Under the hood, KubeBlocks supports **physical backup tools** (like XtraBackup for MySQL) and **volume snapshots**, giving you the flexibility to choose the method that best fits your workload. You can perform **on-demand** backups for immediate data protection or set up **scheduled** backups to automatically capture and manage your data over time.

### 2.1 Supported Backup Storage

- **Object Storage**: S3, GCS, OSS, COS, or MinIO (S3-compatible).
- **PVC-based Storage**: Uses Kubernetes Persistent Volume Claims.

In **KubeBlocks**, you may have multiple **BackupRepos** for different environments or regions. For this tutorial, a **default** repository has already been created. To verify it:

```bash
kubectl get backuprepo -n demo
```

::details-box
---
:summary: You should be able to see output like this
---
```bash
NAME         STATUS   STORAGEPROVIDER   ACCESSMETHOD   DEFAULT   AGE
backuprepo   Ready    pvc               Mount          true      45m
```
::

---

## 3. Creating a Backup

### 3.1 Backup Methods

**KubeBlocks** supports a variety of backup methods, which may differ based on the database engine and the underlying storage. In general:

- **Physical backup** (e.g., `xtrabackup`) captures the actual data files on disk.
- **Volume snapshot** leverages cloud-native snapshot capabilities of the storage layer.

The approach you choose can vary depending on your **database engine**, **storage provider**, and **performance requirements**. For MySQL, two common methods are:

- **xtrabackup**: Uses the Percona XtraBackup tool for online backups.
- **volume-snapshot**: Uses Kubernetes volume snapshot functionality if supported by your storage.

To see which backup methods are available for `mycluster`:

```bash
kbcli cluster describe-backup-policy mycluster -n demo
```

::details-box
---
:summary: You should be able to see output like this
---
```bash
Summary:
Name:               mycluster-mysql-backup-policy
Cluster:            mycluster
Namespace:          demo
Default:            true

Backup Methods:
NAME              ACTIONSET              SNAPSHOT-VOLUMES
xtrabackup        mysql-xtrabackup       false
volume-snapshot   mysql-volumesnapshot   true
```
::

### 3.2 Create a Backup

Below is a **minimal** example of creating a backup via YAML. We’ll use **xtrabackup** here:

1. **Define the Backup Resource**:

```bash
kubectl apply -f - <<-'EOF'
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: Backup
metadata:
  name: mybackup
  namespace: demo
spec:
  backupMethod: xtrabackup
  backupPolicyName: mycluster-mysql-backup-policy
EOF
```

- `backupMethod: xtrabackup` indicates we’re using the **xtrabackup** tool.
- `backupPolicyName: mycluster-mysql-backup-policy` references the default MySQL backup policy.

::simple-task
---
:tasks: tasks
:name: verify_trigger_backup
---
#active
Confirming the backup was triggered...

#completed
Great! The backup was triggered successfully.
::

2. **Verify the Backup**:

After applying the resource, you can:

```bash
kubectl get backup -n demo
```

::simple-task
---
:tasks: tasks
:name: verify_backup_progress
---
#active
Checking backup progress...

#completed
Great! The backup has completed successfully.
::

Wait for the STATUS to become `Completed` (It may take about a minute).

```bash
NAME       POLICY                          METHOD       REPO         STATUS      TOTAL-SIZE   DURATION   CREATION-TIME          COMPLETION-TIME        EXPIRATION-TIME
mybackup   mycluster-mysql-backup-policy   xtrabackup   backuprepo   Completed   1587198      55s        2025-01-21T10:03:35Z   2025-01-21T10:04:30Z
```

Here, `TOTAL-SIZE` shows the size of the backup, and `DURATION` indicates how long the backup process took.

You can also check details:

```bash
kubectl describe backup mybackup -n demo
```

The backup artifact now resides in the configured **BackupRepo** (e.g., S3, MinIO, or a PVC).

---

## 4. Restoring from a Backup

### 4.1 Restore Workflow Overview

**KubeBlocks** supports creating a **new cluster** from an existing backup, allowing you to spin up a cloned environment. Under the hood, the operator retrieves the backup data from the specified **BackupRepo** and re-seeds the target MySQL cluster.

### 4.2 Executing the Restore

1. **Restore the Backup**:

```bash
kbcli cluster restore myrestore --backup mybackup -n demo
```

::simple-task
---
:tasks: tasks
:name: verify_restore_trigger
---
#active
Confirming the restore cluster was created...

#completed
Great! The restore cluster was created successfully.
::

::details-box
---
:summary: How to Restore data from backup using YAML
---
The `kbcli` command above is a convenience wrapper that ultimately applies YAML behind the scenes. For instance:

```bash
kubectl apply -f - <<-'EOF'
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: myrestore
  namespace: demo
  annotations:
    kubeblocks.io/restore-from-backup: '{"mysql":{"name":"mybackup","namespace":"demo","connectionPassword":"Bw1cR15mzfldc9hzGuK4m1BZQOzha6aBb1i9nlvoBdoE9to4"}}'
spec:
  clusterDefinitionRef: apecloud-mysql
  clusterVersionRef: ac-mysql-8.0.30
  terminationPolicy: WipeOut
  componentSpecs:
    - name: mysql
      componentDefRef: mysql
      replicas: 3
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

Here, the annotation `kubeblocks.io/restore-from-backup` references the backup to use and the necessary credentials for restoration.
::

2. **Monitor the Restore Process**:

```bash
kubectl get pods -n demo
```

You’ll see new Pods (e.g., `myrestore-mysql-0`, etc.) come online and begin synchronization.

3. **Validate the New/Recovered Cluster**:

- Ensure each Pod transitions to `Running`.
- Confirm that you can connect and that the data is correct:

```bash
kbcli cluster connect myrestore -n demo
```

Check whether any test databases or tables you created earlier are present in this new cluster, confirming that your backup and restore processes worked successfully.

---

## Summary

We have demonstrated how KubeBlocks supports **backup & restore** — a key feature at **Operator Capability Level 3**. These capabilities ensure **data integrity**, **disaster recovery**, and **production-grade** operations for your MySQL workloads on Kubernetes.

---

## What’s Next?
### Try More Advanced Features

- **[Scheduled Backups](https://kubeblocks.io/docs/release-0.9/user_docs/maintenance/backup-and-restore/backup/scheduled-backup)**: Automate recurring backups for peace of mind.
- **[Point-in-time Recovery (PITR)](https://kubeblocks.io/docs/release-0.9/user_docs/maintenance/backup-and-restore/restore/pitr)**: If supported by your storage and backup method.
- **[Customizing Backup Repos](https://kubeblocks.io/docs/release-0.9/user_docs/maintenance/backup-and-restore/backup/backup-repo#manual-backuprepo-configuration)**: Store data in different object storage providers or across multiple regions.
- Try the **same backup/restore workflow** for other databases (PostgreSQL, Redis, MongoDB, etc.) to see how KubeBlocks provides consistent management across multiple engines.
