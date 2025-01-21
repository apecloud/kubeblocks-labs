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

## 1. Introduction & Recap

1.1 **Operator Capability Level 3**
- Briefly introduce the concept of Operator Capability Level 3, emphasizing **backup & restore** as a core part of “Full Lifecycle” management.
- Recap from **Tutorial 201** (Seamless Upgrades) and transition to **why backups and restores** are critical for production environments.

1.2 **Reviewing Current Cluster**
- Show how to confirm that the MySQL cluster (e.g., `mycluster` in `demo` namespace) is up and running.
- Emphasize that the setup from **Tutorial 201** still applies (3-replica MySQL cluster).

---

## Prerequisites

To save you time, we’ve **automatically installed KubeBlocks** and created a **3-replica MySQL cluster** in the background. It may take a few minutes to complete the setup—feel free to proceed, but keep in mind that some commands might need to wait until the installation is fully finished.

If you’re new to KubeBlocks or missed the previous tutorials, see:
[KubeBlocks Tutorial 101 – Getting Started](/tutorials/kubeblocks-101-99db8bca) and [KubeBlocks Tutorial 201 - Seamless Upgrades](/tutorials/kubeblocks-201-83b9a997)

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

## 2. Backup Basics

2.1 **Why Backup & Restore Matter**
- Highlight the common scenarios: disaster recovery, environment cloning, data archiving.
- Explain how KubeBlocks’ approach to backup & restore is **application-aware**, leveraging Operator intelligence.

2.2 **Supported Backup Types & Storage**
- Overview of **full** vs. **incremental** backups (if relevant).
- Discuss **storage configurations** for backups (e.g., persistent volumes, object storage, etc.).
- Introduce any CRDs or custom resources used by KubeBlocks for backup management.

---

## 3. Creating a Backup

3.1 **Backup Workflow Overview**
- Describe the **OpsRequest** or any relevant KubeBlocks resource that triggers a backup.
- Outline how the operator orchestrates a consistent backup process with minimal impact on running services.

3.2 **Step-by-Step Backup Creation**
1. **Define the Backup Resource** (e.g., YAML snippet for an `OpsRequest` of type `Backup`).
2. **Apply the Backup**:
   ```bash
   kubectl apply -f my-mysql-backup.yaml
   ```  
3. **Monitor the Backup**:
   ```bash
   kubectl get pods -n demo --watch
   ```  
4. **Verify the Backup**: Confirm the backup artifact is stored in the designated location (e.g., an S3 bucket or local PV).

3.3 **Validating the Backup**
- Show how to confirm in the KubeBlocks UI or logs that the backup completed successfully.
- Optional: Demonstrate listing available backups, e.g.:
   ```bash
   kbcli backup list -n demo
   ```

---

## 4. Restoring from a Backup

4.1 **Restore Workflow Overview**
- Explain how a **restore** can be performed to either:
    1. **Override an existing cluster** (e.g., disaster recovery).
    2. **Create a brand-new cluster** from a backup (e.g., for testing or staging).

4.2 **Preparing the Restore**
- Show the **OpsRequest** or relevant spec to initiate a restore. Mention any key fields needed, such as the **backupRef**.

4.3 **Executing the Restore**
1. **Apply the Restore Resource**:
   ```bash
   kubectl apply -f my-mysql-restore.yaml
   ```  
2. **Monitor the Restore Process**:
   ```bash
   kubectl get pods -n demo --watch
   ```  
3. **Validate the New/Recovered Cluster**:
    - Ensure all Pods reach `Running` and `Ready`.
    - Optionally, run a `SELECT @@version;` or sample query to confirm data integrity.

4.4 **Pitfalls & Considerations**
- Discuss any **downtime** implications.
- Explain how **KubeBlocks** handles **role reassignments** (primary/secondary) during restore.
- Recommend best practices for **testing** backups and **scheduling** regular backups.

---

## 5. Understanding the Backup & Restore Lifecycle

5.1 **Data Consistency & Snapshot Mechanisms**
- Provide a high-level explanation of how KubeBlocks ensures **transaction-consistent backups**.
- Reference any underlying technology (e.g., Percona XtraBackup for MySQL, logical vs. physical backups, etc.).

5.2 **Operator’s Role**
- Illustrate how the operator orchestrates container states, manages volume snapshots, and updates cluster status.
- Emphasize minimal manual intervention required because of KubeBlocks’ **automation**.

---

## 6. Conclusion & Next Steps

6.1 **Summary**
- Reiterate how backups and restores fit into **full lifecycle management** (Operator Capability Level 3).
- Highlight the **minimal downtime** and **data consistency** benefits showcased in the tutorial.

6.2 **Try More Advanced Features**
- Suggest exploring **scheduled backups**, **point-in-time recovery** (if supported), or other advanced database management features.
- Mention the upcoming or previous articles in the series for further learning.

6.3 **Key Takeaways**
- KubeBlocks provides a **production-grade** approach for backups and restores.
- Seamless integration with Kubernetes ensures easy scaling for both small dev clusters and large enterprise deployments.

---

### Optional Appendices

- **Appendix A: Troubleshooting**
    - Common errors during backup/restore and how to address them.
- **Appendix B: Custom Storage Backends**
    - Examples of storing backups in different object storage solutions (S3, MinIO, etc.).

