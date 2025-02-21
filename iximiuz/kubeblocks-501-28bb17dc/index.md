---
title: KubeBlocks Tutorial 501 – Auto-Tuning for Optimal Performance
description: |
  Learn how to run any database on Kubernetes with KubeBlocks!

kind: tutorial

playground:
  name: k3s-bare

    # Protect the playground's registry (registry.iximiuz.com) with a username and password.
  # default: no authentication
  registryAuth: testuser:testpassword

  tabs:
    - id: terminal-dev-machine
      kind: terminal
      name: dev-machine
      machine: k3s-01
      
    - id: Grafana
      kind: http-port
      name: Grafana
      machine: k3s-01
      number: 32000
      
    - id: Prometheus
      kind: http-port
      name: Prometheus
      machine: k3s-01
      number: 32001
      
    - id: AlertManager
      kind: http-port
      name: AlertManager
      machine: k3s-01
      number: 32002

  machines:
    - name: k3s-01
      users:
        - name: root
        - name: laborant
          default: true
      resources:
        cpuCount: 4
        ramSize: "8G"

cover: __static__/grafana-1.png

createdAt: 2025-01-16
updatedAt: 2025-01-16

categories:
  - kubernetes
  - databases

tagz:
  - kubeblocks

tasks:
  # 1) Initialization task
  init_task_1:
    init: true
    user: laborant
    run: |
      sudo rm -rf /usr/local/bin/kbcli
      export KB_CLI_VERSION=v0.9.2
      curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash -s $KB_CLI_VERSION

  init_task_2:
    init: true
    user: laborant
    needs:
      - init_task_1
    run: |
      export KB_VERSION=v0.9.2
      kubectl create -f https://github.com/apecloud/kubeblocks/releases/download/$KB_VERSION/kubeblocks_crds.yaml
      helm repo add kubeblocks https://apecloud.github.io/helm-charts
      helm repo update
      helm -n kb-system install kubeblocks kubeblocks/kubeblocks --version 0.9.2 --set dataProtection.encryptionKey='S!B\*d$zDsb=' --create-namespace

  init_task_3:
    init: true
    user: laborant
    needs:
      - init_task_2
    run: |
      kbcli addon enable mysql --set image.registry=apecloud-registry.cn-zhangjiakou.cr.aliyuncs.com --set images.registry=apecloud-registry.cn-zhangjiakou.cr.aliyuncs.com
      kubectl create namespace demo
      cat <<EOF | kubectl apply -f -
      apiVersion: apps.kubeblocks.io/v1alpha1
      kind: Cluster
      metadata:
        name: mysql-cmpd-cluster
        namespace: demo
      spec:
        terminationPolicy: Delete
        componentSpecs:
          - name: mysql
            componentDef: "mysql-8.0"
            serviceVersion: 8.0.33
            disableExporter: true
            replicas: 2
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
                  storageClassName: ""
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
      
  verify_monitor_ready:
    needs:
      - verify_kubeblocks_installation
    run: |
      output="$(kubectl get pods -n monitoring 2>&1 || true)"
      echo "controlplane \$ kubectl get pods -n monitoring"
      echo "$output"
      if echo "$output" | grep -q "prometheus-operator-grafana.*3/3.*Running"; then
        echo "done"
        exit 0
      else
        echo "not ready yet"
        exit 1
      fi

  verify_disable_exporter_is_false:
    needs:
      - verify_kubeblocks_installation
    run: |
      output="$(kubectl get cluster -n demo mycluster -o yaml 2>&1 || true)"
      echo "controlplane \$ kubectl get cluster -n demo mycluster -o yaml"
      echo "$output"
      if echo "$output" | grep -q "disableExporter:.*false"; then
        echo "done"
        exit 0
      else
        echo "disableExporter is not false yet"
        exit 1
      fi

  verify_prometheus_rule_created:
    needs:
      - verify_kubeblocks_installation
    run: |
      output="$(kubectl get prometheusrule mysql-restart-alert -n monitoring --ignore-not-found 2>&1)"
      echo "controlplane \$ kubectl get prometheusrule mysql-restart-alert -n monitoring --ignore-not-found"
      echo "$output"
      if [ -z "$output" ]; then
        echo "PrometheusRule CR not created yet"
        exit 1
      else
        echo "done"
        exit 0
      fi
      
  verify_alertmanager_config_created:
    needs:
      - verify_kubeblocks_installation
    run: |
      output="$(kubectl get alertmanagerconfig mysql-null-config -n monitoring --ignore-not-found 2>&1)"
      echo "controlplane \$ kubectl get alertmanagerconfig mysql-null-config -n monitoring --ignore-not-found"
      echo "$output"
      if [ -z "$output" ]; then
        echo "AlertmanagerConfig CR not created yet"
        exit 1
      else
        echo "done"
        exit 0
      fi



---

Welcome to the **fifth chapter** of our **KubeBlocks** tutorial series!

In this tutorial, we dive into **Operator Capability Level 5**, focusing on **Auto-Tuning**. You’ll learn how KubeBlocks dynamically adjusts database parameters based on resource specifications to optimize performance, reducing manual intervention. 

👋 If you find KubeBlocks helpful, please consider giving us a star ⭐️ on our [GitHub repository](https://github.com/apecloud/kubeblocks). Your support drives us to improve!

::image-box
---
src: __static__/operator-capability-level.png
alt: 'Operator Capability Level'
---
::

---

## Prerequisites

To save you time, we’ve **automatically installed KubeBlocks** and created a **MySQL cluster** in the background. The setup might take a few minutes—feel free to proceed, but some commands may require the installation to complete first.

If you’re new to KubeBlocks or missed earlier tutorials, check out:
- [KubeBlocks Tutorial 101 – Getting Started](/tutorials/kubeblocks-101-99db8bca)
- [KubeBlocks Tutorial 201 - Seamless Upgrades](/tutorials/kubeblocks-201-83b9a997)
- [KubeBlocks Tutorial 301 - Backup & Restore](/tutorials/kubeblocks-301-ea1046bf)
- [KubeBlocks Tutorial 401 – Observability in Action](/tutorials/kubeblocks-401-df4bd8a5)

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

**What is Auto-Tuning?**

At Operator Capability Level 5, Auto-Tuning refers to the Operator’s ability to dynamically adjust an application’s configuration based on workload patterns or resource changes, ensuring optimal performance with minimal manual effort. KubeBlocks supports this by automatically tuning database parameters (e.g., MySQL’s `max_connections`) when resource specifications (like memory) are updated.

::details-box
---
:summary: Why does even MySQL bother to limit max_connections?
---
MySQL limits connections for resource management reasons. Each connection consumes memory resources, including various buffers allocated for that connection. 

MySQL needs to reserve substantial memory for its buffer pool to cache data and indexes for efficient query performance. 

If connections were unlimited, too many connections could consume excessive memory, squeezing the space available for the buffer pool, ultimately leading to degraded query performance. 

Therefore, limiting max_connections is a necessary measure to protect database performance and stability.
::

**Goals of This Tutorial**

In this lab, we’ll:
- Demonstrate how KubeBlocks auto-tunes MySQL parameters based on resource changes.
- Optimize configurations to showcase the "Auto Pilot" philosophy of reducing manual intervention.

**Key Features:**
- **Parameter Auto-Tuning:** Adjusts database settings based on resource specs.
- **Automation Focus:** Minimizes manual configuration for better efficiency.
- **Performance Insights:** Leverages Prometheus and Grafana for bottleneck detection.

---

## 3. Auto-Tuning in Action: Dynamic Parameter Adjustment

Let’s explore how KubeBlocks auto-tunes MySQL parameters when resources change.

### 3.1 Check Initial Parameters

Connect to the MySQL cluster:
```bash
kbcli cluster connect mycluster -n demo

```
Then inspect the `max_connections` parameter:
```bash
mysql> SHOW VARIABLES LIKE 'max_connections';
+-----------------+-------+
| Variable_name   | Value |
+-----------------+-------+
| max_connections | 83    |
+-----------------+-------+
1 row in set (0.01 sec)
```

### 3.2 Adjust Resources and Trigger Auto-Tuning

Increase the memory from 0.5Gi to 2Gi:
```bash
kbcli cluster update mycluster --memory 2Gi -n demo
```

::simple-task
---
:tasks: tasks
:name: verify_resource_updated
---
#active
Waiting for resource update to complete...
#completed
Resources updated successfully! 🎉
::

Recheck `max_connections`:
```bash
kbcli cluster connect mycluster -n demo -- mysql -e "SHOW VARIABLES LIKE 'max_connections';"
```
Example output:
```
Variable_name    Value
max_connections  300
```
**Explanation:** KubeBlocks detected the memory increase and automatically adjusted `max_connections` to optimize for the new resource capacity.


---

## 5. Summary

In this tutorial, we explored KubeBlocks’ Auto-Tuning capabilities:
- Automatically adjusting parameters like `max_connections` based on resource specs.
- Leveraging observability to detect and resolve performance issues.
- Reducing manual intervention for efficient database management.

While KubeBlocks doesn’t yet support auto-scaling, its parameter tuning aligns with Level 5’s “Auto Pilot” vision. Stay tuned for future enhancements like automated scaling!

---

## 6. What’s Next?

- Experiment with Auto-Tuning on other engines like PostgreSQL or Redis.
- Customize configuration templates for specific workloads.
- Keep an eye on KubeBlocks updates for more Level 5 features.