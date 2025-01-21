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

## 1. Introduction & Recap

### 1.1 Operator Capability Level 3

- **Operator Capability Level 3** moves beyond basic installation and upgrade tasks to include **day-2 operations** such as **backups, restores, and failovers**.
- In our [Tutorial 201](#), we demonstrated **seamless upgrades** of a MySQL cluster with minimal impact on applications.
- Now, we’ll explore **backups and restores**, which are critical for:
    - **Disaster recovery**: Safeguard against unexpected data loss.
    - **Environment cloning**: Quickly spin up test or dev environments from production data.
    - **Data archiving**: Keep historical snapshots of your database state.

### 1.2 Reviewing Current Cluster

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

---

## 2. Backup Basics

### 2.1 Why Backup & Restore Matter

Most production databases **require robust backup strategies** for:

1. **Disaster Recovery (DR)**: In cases of hardware failures, software bugs, or accidental deletions.
2. **Environment Cloning**: Quickly replicate production data for development or QA.
3. **Data Archiving**: Retain snapshots for compliance or historical analysis.

**KubeBlocks** leverages operator intelligence to handle backups in an **application-aware** manner, ensuring **transaction consistency** and **seamless orchestration** with Kubernetes.

### 2.2 Supported Backup Types & Storage

1. **Full vs. Incremental**: Depending on your storage and database engine, you may configure different backup strategies (incremental backup is engine-dependent and might not always be supported).
2. **Storage Configurations**:
    - **Object storage** such as S3, GCS, OSS, COS, or MinIO (S3-compatible).
    - **PVC-based storage** on Kubernetes.
3. **Backup CRDs / Custom Resources**:
    - **BackupRepo**: A Custom Resource that defines the storage repository for backups.
    - **Backup**: A Custom Resource that defines when and how backups are taken.
    - **OpsRequest** (type=Backup) in certain cases, or **Backup** CR under `dataprotection.kubeblocks.io/v1alpha1`.

In **KubeBlocks**, you can create multiple **BackupRepos** to suit different scenarios (e.g., separate object storage for different lines of business or multi-region redundancy). For simplicity, **a default backup repository** has already been created in this tutorial environment.

To verify the existing BackupRepo:

```bash
kubectl get backuprepo -n demo
```

---

## 3. Creating a Backup

### 3.1 Backup Workflow Overview

When you trigger a backup in **KubeBlocks**:

1. The operator looks at the **Backup** (or **OpsRequest**) resource.
2. It checks which **BackupRepo** is specified (or defaults to the configured one).
3. It **orchestrates** the backup process, ensuring minimal disruption to the running MySQL cluster.
4. The resulting **backup artifact** is stored in the designated repository (e.g., an S3 bucket or a PVC).

**KubeBlocks** provides different backup methods for different databases. In MySQL, for instance, you might use:
- **xtrabackup** (physical backup tool).
- **volume-snapshot** (utilizing cloud-native volume snapshots).

To see which backup methods are available for `mycluster`:

```bash
kbcli cluster list-backup-policy mycluster -n demo
```

Then describe the default policy:

```bash
kbcli cluster describe-backup-policy mycluster -n demo
```

You will typically see two methods for MySQL:
- **xtrabackup**: backups to object storage.
- **volume-snapshot**: leverages volume snapshot capabilities.

### 3.2 Step-by-Step Backup Creation

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

2. **Apply the Backup**: (This is already done inline above via a multi-line `kubectl apply -f - ...`.)

3. **Monitor the Backup**:

   ```bash
   kubectl get pods -n demo --watch
   ```

   You may see a short-lived **backup job** or a Pod that performs the actual backup.

4. **Verify the Backup**:
    - Check the `Backup` status:

      ```bash
      kubectl get backup -n demo
      kubectl describe backup mybackup -n demo
      ```

    - List backups associated with `mycluster` using `kbcli`:

      ```bash
      kbcli cluster list-backups mycluster -n demo
      ```

   The backup artifact (data) should now reside in the configured **BackupRepo** (e.g., an S3 bucket or a PVC).

### 3.3 Validating the Backup

- **Check Logs or KubeBlocks UI** (if available) to confirm the backup was created successfully.
- Optionally, run:
  ```bash
  kbcli backup list -n demo
  ```
  to see all **Backup** resources in the `demo` namespace.

---

## 4. Restoring from a Backup

### 4.1 Restore Workflow Overview

**KubeBlocks** supports two typical restore scenarios:

1. **Overwrite an existing cluster**: For immediate disaster recovery.
2. **Create a new cluster**: Spin up a cloned environment for testing, QA, or analytics.

Under the hood, the KubeBlocks operator orchestrates the restore by **retrieving the backup data** from the specified **BackupRepo** and **re-seeding** the target MySQL cluster.

### 4.2 Preparing the Restore

To restore from a previously created backup (e.g., `mybackup`), we need to either:
- Use an **OpsRequest** of type `Restore`, or
- Use the `kbcli cluster restore ...` command, which creates the relevant resources on your behalf.

You’ll typically specify:
- **backupRef**: Which backup to restore from.
- **target cluster**: Where to restore the data.

### 4.3 Executing the Restore

Here’s a simple example using **`kbcli`**:

```bash
kbcli cluster restore myrestore --backup mybackup -n demo
```

This command instructs KubeBlocks to create a new cluster named `myrestore` from the `mybackup`. Alternatively, you can restore directly over your existing `mycluster` if that’s your intended scenario (though it’s generally safer to restore into a fresh cluster for testing first).

1. **Apply the Restore Resource**: The command above automatically generates the needed restore specs.
2. **Monitor the Restore Process**:

   ```bash
   kubectl get pods -n demo --watch
   ```

   You’ll see new Pods (e.g., `myrestore-mysql-0`, etc.) come online and begin synchronization.

3. **Validate the New/Recovered Cluster**:
    - Ensure each Pod transitions to `Running` and `Ready`.
    - (Optional) Connect to MySQL and verify data:

      ```bash
      kubectl -n demo exec -it myrestore-mysql-0 -- \
        mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT @@version;"
      ```

### 4.4 Pitfalls & Considerations

- **Downtime**: If you choose to overwrite an existing cluster, expect downtime. Restoring into a fresh cluster can mitigate downtime for production.
- **Primary/Secondary Role Reassignments**: The operator will handle internal MySQL role transitions automatically.
- **Best Practices**:
    - **Test your backups regularly** to ensure they are valid and restorable.
    - **Schedule backups** (e.g., daily or weekly) for critical production workloads. (See below for a reference link.)

---

## 5. Understanding the Backup & Restore Lifecycle

### 5.1 Data Consistency & Snapshot Mechanisms

KubeBlocks ensures **transaction-consistent** backups by:
- Integrating with MySQL’s **xtrabackup** tool, which performs online hot backups.
- Or using **volume snapshots** if your underlying storage supports it (logical or physical snapshots).

Both approaches aim to capture a consistent data state without significant downtime.

### 5.2 Operator’s Role

- The **KubeBlocks Operator** orchestrates container states during backup and restore.
- It manages underlying **volume snapshots** (if using the volume-snapshot method).
- It updates the cluster’s status resources, letting you monitor progress in real time.
- **Minimal manual intervention** is required once your backup policies and repos are set.

---

## 6. Conclusion & Next Steps

### 6.1 Summary

We have demonstrated how KubeBlocks supports **backup & restore** — a key feature at **Operator Capability Level 3**. These capabilities ensure **data integrity**, **disaster recovery**, and **production-grade** operations for your MySQL workloads on Kubernetes.

### 6.2 Try More Advanced Features

- **Scheduled Backups**: Automate recurring backups for peace of mind.  
  [Scheduled Backup Documentation](https://kubeblocks.io/docs/release-0.9/user_docs/maintenance/backup-and-restore/backup/scheduled-backup)
- **Point-in-time Recovery (PITR)**: If supported by your storage and backup method.
- **Customizing Backup Repos**: Store data in different object storage providers or across multiple regions.  
  [BackupRepo Documentation](https://kubeblocks.io/docs/release-0.9/user_docs/maintenance/backup-and-restore/backup/backup-repo)

### 6.3 Key Takeaways

- **KubeBlocks** offers a **production-grade, application-aware** approach to backing up and restoring databases on Kubernetes.
- With **operator-driven automation**, you can maintain data consistency, minimize downtime, and rapidly spin up new environments from backups.
- These features scale seamlessly across dev clusters, enterprise deployments, and multi-cloud environments.

---

## Optional Appendices

### Appendix A: Troubleshooting

- **Backup Not Starting**: Check if the `BackupRepo` is properly configured and accessible.
- **Restore Stuck**: Confirm the storage used by the new (or overwritten) cluster is sufficient and that the relevant Pods aren’t in a crash loop.

### Appendix B: Custom Storage Backends

- **S3 / GCS / OSS / COS / OBS**: Configure credentials and endpoints in the `BackupRepo` resource.
- **MinIO** (S3-compatible): Ideal for on-prem or dev setups.
- **PVC**: For local, on-Kubernetes storage (not recommended for cross-region DR).

For more details on configuring backup policies, methods, and advanced features, see:  
[Configure Backup Policy](https://kubeblocks.io/docs/release-0.9/user_docs/maintenance/backup-and-restore/backup/configure-backuppolicy)

