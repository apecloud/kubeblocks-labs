---
title: KubeBlocks Tutorial 401 – Observability in Action
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
      
    - id: Grafana
      kind: http-port
      name: Grafana
      machine: node-01
      number: 32000
      
    - id: Prometheus
      kind: http-port
      name: Prometheus
      machine: node-01
      number: 32001
      
    - id: AlertManager
      kind: http-port
      name: AlertManager
      machine: node-01
      number: 32002

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

cover: __static__/backup-restore2.png

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

---

Welcome to the **fourth chapter** of our **KubeBlocks** tutorial series! 

In this tutorial, we’ll explore **Observability**—a key feature of **Operator Capability Level 4**. You’ll learn how to monitor, analyze, and troubleshoot your database clusters on Kubernetes with built-in observability features.

👋 If you find KubeBlocks helpful, please consider giving us a star ⭐️ on our [GitHub repository](https://github.com/apecloud/kubeblocks). Every star motivates us to make KubeBlocks even better!

::image-box
---
src: __static__/operator-capability-level.png
alt: 'Operator Capability Level'
---
::

---

## Prerequisites

To save you time, we’ve **automatically installed KubeBlocks** and created a **3-replica MySQL cluster** in the background. It may take a few minutes to complete the setup—feel free to proceed, but keep in mind that some commands might need to wait until the installation is fully finished.

If you’re new to KubeBlocks or missed the previous tutorials, see:
- [KubeBlocks Tutorial 101 – Getting Started](/tutorials/kubeblocks-101-99db8bca)
- [KubeBlocks Tutorial 201 - Seamless Upgrades](/tutorials/kubeblocks-201-83b9a997)
- [KubeBlocks Tutorial 301 - Backup & Restore](/tutorials/kubeblocks-301-ea1046bf)

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

**What is Observability?**

Observability in Kubernetes is the practice of monitoring metrics, logs, and events to gain insights into the system’s behavior. By collecting and analyzing this data, you can quickly diagnose issues, understand performance bottlenecks, and ensure that your clusters run smoothly.

**Operator Capability Level 4:**

At Operator Capability Level 4, KubeBlocks leverages advanced observability features to provide deep insights into database health, performance, and operational anomalies. This level of observability is crucial for maintaining high availability and ensuring proactive troubleshooting in production environments.

**Components:**

- **Metrics:**  
KubeBlocks integrates with Prometheus to scrape cluster metrics, allowing you to monitor resource usage and performance in real time.

- **Alerting:**  
You can configure alerts to notify you when critical events or performance thresholds are exceeded, ensuring that issues are addressed before they escalate.

---

## 2. Enabling Observability for a KubeBlocks Cluster

To fully leverage observability in KubeBlocks, you need to set up monitoring tools such as Prometheus and Grafana. Follow the steps below to install and configure these tools in your Kubernetes cluster.

### 2.1 Install Prometheus Operator and Grafana

1. **Create a Monitoring Namespace**  
It is a best practice to isolate monitoring components in their own namespace. Create a new namespace called `monitoring`:

```bash
kubectl create namespace monitoring
```

2. **Add the Prometheus Community Helm Repository**  
This repository contains the official Helm chart for the Prometheus Operator:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

3. **Install the Prometheus Operator (kube-prometheus-stack)**  
Use Helm to install the Prometheus Operator and Grafana. This command configures Grafana and Prometheus as NodePort services, exposing them on ports `32000` and `32001` respectively.

```bash
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=32000 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=32001 \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=32002
```

4. **Verify the Installation**  
Check that all the monitoring components are running in the `monitoring` namespace:

```bash
kubectl get pods -n monitoring
```

**Example Output:**

```plaintext
NAME                                                     READY   STATUS    RESTARTS   AGE
alertmanager-prometheus-operator-kube-p-alertmanager-0   2/2     Running   0          4m24s
prometheus-operator-grafana-5f5b9584b8-qmzqm             3/3     Running   0          4m30s
prometheus-operator-kube-p-operator-8fd7b657-rc9c6       1/1     Running   0          4m30s
prometheus-operator-kube-state-metrics-75597dbd5-xr96v   1/1     Running   0          4m30s
prometheus-operator-prometheus-node-exporter-bcsqr       1/1     Running   0          4m30s
prometheus-operator-prometheus-node-exporter-hbvjv       1/1     Running   0          4m30s
prometheus-operator-prometheus-node-exporter-rpngp       1/1     Running   0          4m30s
prometheus-prometheus-operator-kube-p-prometheus-0       2/2     Running   0          4m23s
```

### 2.2 Monitor a Database Cluster

After setting up Prometheus and Grafana, configure them to monitor your KubeBlocks database cluster.

1. **Create a PodMonitor Resource**  
A `PodMonitor` resource instructs Prometheus on which pods to scrape for metrics. In this example, the `PodMonitor` is configured to monitor the MySQL component of your `mycluster` database (running in the `demo` namespace). The labels specified help Prometheus to correctly associate the metrics with your database cluster.

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: mycluster-pod-monitor
  namespace: monitoring # Namespace where the Prometheus operator is installed
  labels:               # Labels to match the Prometheus operator’s podMonitorSelector
    release: prometheus-operator
spec:
  jobLabel: kubeblocks-service
  # Transfer selected labels from the associated pod onto the ingested metrics
  podTargetLabels:
  - app.kubernetes.io/instance
  - app.kubernetes.io/managed-by
  - apps.kubeblocks.io/component-name
  - apps.kubeblocks.io/pod-name
  podMetricsEndpoints:
    - path: /metrics
      port: http-metrics
      scheme: http
  namespaceSelector:
    matchNames:
      - demo
  selector:
    matchLabels:
      app.kubernetes.io/instance: mycluster
      apps.kubeblocks.io/component-name: mysql
EOF
```

2. **Enable Metrics Exporter for the Database Cluster**  
Ensure that your database cluster is exporting metrics by enabling the exporter. Patch the cluster configuration to set `disableExporter` to `false` for the relevant component (in this case, the MySQL component):

```bash
kubectl patch cluster mycluster -n demo --type "json" -p '[{"op":"add","path":"/spec/componentSpecs/0/disableExporter","value":false}]'
```

This configuration enables Prometheus to scrape metrics from your MySQL pods, allowing you to monitor the performance and health of your database cluster.

---

## 3. Accessing and Visualizing Metrics

With Prometheus and Grafana deployed and properly configured, you can now access and visualize your cluster’s metrics.

- **Accessing Grafana and Prometheus:**  
Since both services are exposed via NodePort, you can access them using your browser:
- **Grafana:** `http://<node-ip>:32000`
- **Prometheus:** `http://<node-ip>:32001`

- **Grafana Login Credentials:**
- **Username:** `admin`
- **Password:** `prom-operator`

- **Viewing the MySQL Dashboard in Grafana:**  
After logging into Grafana, navigate to:

**Home > Dashboards > APPS / MySQL**

Here, you will see the MySQL dashboard displaying key metrics such as query performance, resource usage, and overall operational status. These visualizations provide you with real-time insights into your database cluster's health and performance.

::image-box
---
src: __static__/grafana-1.png
alt: 'Grafana'
---
::

By regularly monitoring these dashboards, you can quickly identify and troubleshoot issues, ensuring that your KubeBlocks-managed database clusters run efficiently.

---

## 4. Alerts and Anomaly Detection

TODO：添加说明，我们创建1个MySQL服务在线检测。

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mysql-restart-alert
  namespace: monitoring
  labels:
    release: prometheus-operator
spec:
  groups:
  - name: mysql.rules
    rules:
    - alert: MySQLInstanceDown
      expr: |
        mysql_up{namespace="demo"} == 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "MySQL instance is down"
        description: "MySQL instance {{ $labels.pod }} in namespace demo is down"
EOF
```

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: mysql-null-config
  namespace: monitoring
spec:
  route:
    receiver: 'null'
    groupBy: ['alertname']
    groupWait: 10s
    groupInterval: 1m
  receivers:
  - name: 'null'
EOF
```

TODO:刷新Prometheus页面，应该能

::image-box
---
src: __static__/alert.png
alt: 'alert'
---
::


TODO:尝试删除pods，触发服务down，查看alert是否触发

```bash
kubectl delete pods mycluster-mysql-0 mycluster-mysql-1 mycluster-mysql-2 -n demo
```
::image-box
---
src: __static__/alert-triggerred.png
alt: 'alert-triggerred'
---
::

---

## Summary

TODO:强调kubeblocks采用的是开源方案，跟开源社区紧紧耦合。

- **Recap:**
  - We demonstrated how to enable and leverage observability features in KubeBlocks.
  - Covered accessing metrics, and setting up alerting mechanisms.
- **Benefits:**
  - Emphasized how observability helps maintain high availability, performance, and facilitates proactive troubleshooting for your database clusters.
- **Next Steps:**
  - Encourage exploring additional observability integrations and advanced monitoring configurations.

---

## What’s Next?

- **Further Exploration:**
    - Experiment with integrating other monitoring tools or custom dashboards.
    - Dive deeper into distributed tracing or anomaly detection with more advanced setups.
- **Additional Resources:**
    - Links to KubeBlocks documentation on observability.
    - Tutorials on advanced monitoring strategies for Kubernetes.

