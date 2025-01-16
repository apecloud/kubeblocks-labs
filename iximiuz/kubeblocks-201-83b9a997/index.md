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

Welcome to the second installment(换个说法) of our **KubeBlocks** tutorial series!

In this guide, we will focus on **seamless upgrades** and （删掉basic maintenance）**basic maintenance**—two core features that showcase KubeBlocks’ ability to run **any database** at **Operator Capability Level 5**, suitable for **production-grade** operations. Whether you’re managing a small dev cluster or a large-scale enterprise environment, KubeBlocks streamlines the entire database lifecycle on Kubernetes.

::image-box
---
src: __static__/operator-capability-level.png
alt: 'Operator Capability Level'
---
::

## Prerequisites

跟第一篇来点联动：跟读者说，为了节省他们的时间，我们自动在后台安装了KubeBlocks和3副本mysql cluster，但是可能得等几分钟安装完成，现在我们可以直接开始这个教程。（用verify_kubeblocks_installation,verify_mysql_pod_ready验证）
给个第一篇的链接，让读者可以回去看第一篇的教程：https://labs.iximiuz.com/tutorials/kubeblocks-101-99db8bca

- A running Kubernetes cluster (e.g., [K3s](https://k3s.io/) for local testing).
- [KubeBlocks Operator](https://kubeblocks.io/) installed (with CRDs) and ready to manage database workloads.
- Basic familiarity with `kbcli`, `kubectl`, and Helm from the Kubeblocks Tutorial 101 – Getting Started

---

## Outline

### 1. Introduction & Review
- **Briefly revisit** how KubeBlocks manages **any** database and achieves **Level 5** Operator capabilities.
- **Recap** key concepts from Tutorial 101 (installation, cluster creation, config management).

查看mysql：
kubectl get po -n demo
NAME                READY   STATUS    RESTARTS   AGE
mycluster-mysql-0   4/4     Running   0          16s
mycluster-mysql-1   4/4     Running   0          16s
mycluster-mysql-2   4/4     Running   0          16s

查看mysql角色：
kubectl get po -n demo -o yaml | grep kubeblocks.io/role
kubeblocks.io/role: secondary
kubeblocks.io/role: primary
kubeblocks.io/role: secondary
可以看到mycluster-mysql-1是primary，剩下2个是secondary

可以用`kubectl delete po mycluster-mysql-1 -n demo`命令删除primary pod，然后查看pod状态，可以看到mycluster-mysql-1被重新创建，可能会选择1个新的节点作为primary。
这个过程中没有数据丢失，这就是KubeBlocks的高可用性。

### 2. Preparing for an Upgrade
- **Check Current Cluster Version**: Verify your database cluster version and readiness.
- **Best Practices**: Backups, resource checks, and planning for minimal downtime.

查看mysql版本：
kubectl get clusterversion | grep mysql

### 3. Performing a Rolling Upgrade
- **Create an OpsRequest** to upgrade the MySQL/PostgreSQL/Redis version (example).
- **Monitor the Upgrade** progress using `kbcli cluster describe-ops`.
- **Verify** that Pods are sequentially upgraded with no major downtime.

修改mysql版本：
kubectl edit cluster mycluster -n demo
修改clusterVersionRef为mysql-8.4.2

### 4. Automated Upgrades
- **Configure Auto-Upgrade Policies**: Show how to automatically handle patch/minor version updates.
- **Observe** and confirm everything is done without manual intervention.

通过kubectl get po -n demo查看mysql pod状态，可以看到pod正在逐个升级。
并且是从secondary开始升级。这样避免了升级primary，选出新primary后又被升级的情况。

### 6. Post-Maintenance Validation
- **Check Logs and Metrics**: Confirm that the upgrades and maintenance steps were completed successfully.
- **Validate Connectivity**: Ensure your applications can reconnect to the database cluster seamlessly.

### 9. What’s Next
- **Explore** other databases (PostgreSQL, Redis, MongoDB, Elasticsearch, Qdrant, etc.).
- **Continue** 下一个tutorial介绍full lifecycle management，包括备份，恢复，failover等。

---

## Final Thoughts

KubeBlocks stands out by providing a **production-ready** approach to database management on Kubernetes. By mastering **seamless upgrades** and **basic maintenance**, you’ll be ready to tackle more complex scenarios—backups, disaster recovery, and beyond—all while reaping the benefits of container orchestration.

Stay tuned for further tutorials in this series, where we’ll delve even deeper into the power of KubeBlocks!