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

To save you time, we’ve **automatically installed KubeBlocks** and created a **MySQL cluster** in the background. It may take a few minutes to complete the setup—feel free to proceed, but keep in mind that some commands might need to wait until the installation is fully finished.

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

Observability in Kubernetes involves monitoring metrics, logs, and events to gain actionable insights into your system’s behavior. By analyzing this data, you can diagnose issues, pinpoint performance bottlenecks, and ensure that your clusters run smoothly.

**Enhanced Metrics Exporting:**

KubeBlocks automatically deploys a metrics exporter for each database instance (Pod). This built-in exporter collects detailed performance data in real time, seamlessly integrating with Prometheus to help you monitor resource usage and overall system health.

**Key Features:**

* **Metrics:**  
KubeBlocks scrapes a wide range of cluster metrics via Prometheus, enabling continuous monitoring of resource usage and performance.

* **Alerting:**  
Set up alerts to notify you when critical events or performance thresholds are exceeded, ensuring issues are addressed promptly.


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

::details-box
---
:summary: You should be able to see output like this
---
```bash
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
::


::simple-task
---
:tasks: tasks
:name: verify_monitor_ready
---
#active
Waiting for the Prometheus & Grafana to become ready...

#completed
Yay! Prometheus & Grafana is ready. 🎉
::

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

::simple-task
---
:tasks: tasks
:name: verify_disable_exporter_is_false
---
#active
Waiting for the MySQL Cluster to export metrics by enabling the exporter...

#completed
Yay! Your MySQL Cluster is exporting metrics. 🎉
::

---

## 3. Accessing and Visualizing Metrics

With Prometheus and Grafana deployed and properly configured, you can now access and visualize your cluster’s metrics.

In the Iximiuz Lab interface, switch to the **Grafana** tab. Once you are on the Grafana page, log in using the following credentials:

- **Username:** `admin`
- **Password:** `prom-operator`

After logging in, click on the **Home** tab in the left-hand menu, then navigate to **Dashboards > APPS / MySQL**. Here, you will find the MySQL Dashboard displaying key metrics such as query performance, resource usage, and overall operational status.

These visualizations provide you with real-time insights into your database cluster's health and performance, enabling you to quickly identify and troubleshoot issues, and ensuring that your KubeBlocks-managed database clusters run efficiently.

⏳This may take a minute. If you don't see it, please wait a moment and refresh the tab.

::image-box
---
src: __static__/grafana-1.png
alt: 'Grafana'
---
::


---

## 4. Alerts and Anomaly Detection

In this section, we create a service-level alert for MySQL to detect when an instance goes offline. This alert monitors the MySQL service in the `demo` namespace and will trigger immediately when an instance goes down.

We create a `PrometheusRule` custom resource (CR) that instructs Prometheus to evaluate the condition for the MySQL service. In this case, if `mysql_up{namespace="demo"}` equals 0, it indicates that the MySQL instance is not running, and an alert will be triggered immediately.

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
      expr: mysql_up{namespace="demo"} == 0
      labels:
        severity: warning
      annotations:
        summary: "MySQL instance is down"
        description: "MySQL instance {{ $labels.pod }} in namespace demo is down"
EOF
```

::simple-task
---
:tasks: tasks
:name: verify_prometheus_rule_created
---
#active
Waiting for the PrometheusRule CR to be created in the monitoring namespace...

#completed
Yay! The PrometheusRule CR has been created successfully. 🎉
::


Next, we apply an AlertmanagerConfig custom resource to customize how alerts are routed and handled. While Prometheus generates alerts based on your rules, Alertmanager is responsible for grouping, silencing, and routing those alerts. 

In our example, we configure Alertmanager to route alerts to a "null" receiver, which effectively discards the alerts for demonstration purposes.

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

::simple-task
---
:tasks: tasks
:name: verify_alertmanager_config_created
---
#active
Waiting for the AlertmanagerConfig CR (mysql-null-config) to be created in the monitoring namespace...

#completed
Awesome! The AlertmanagerConfig CR has been created successfully. 🎉
::


In the Iximiuz Lab interface, switch to the **Prometheus** tab. After applying the alert configuration, refresh your Prometheus UI. You should see the new MySQL downtime alert listed in the alert panel.

⏳This may take a minute. If you don't see it, please wait a moment and refresh the tab.

::image-box
---
src: __static__/alert.png
alt: 'Alert Panel'
---
::

To simulate a failure and verify that the alert is correctly triggered, delete the MySQL pods:

```bash
kubectl delete pods mycluster-mysql-0 -n demo
```

After the pods are deleted, return to the Prometheus alert panel, refresh the tab to see the triggered alert.

::image-box
---
src: __static__/alert-firing.png
alt: 'Firing Alert'
---
::


---

## Summary

In this tutorial, we demonstrated how to enable and leverage observability features in KubeBlocks. We showed you how to deploy Prometheus and Grafana to monitor metrics, set up a PodMonitor to scrape data from your MySQL cluster, and configure alerts to detect service anomalies.

It is important to note that KubeBlocks leverages open source solutions and integrates tightly with the open source community. This approach ensures that our observability features benefit from continuous improvements and community support.

---

## What’s Next?

* Experiment with KubeBlocks on other database engines such as PostgreSQL, MongoDB, and Redis. 
* Try integrating different alert channels and custom dashboards to tailor the monitoring experience to your environment.
* Stay tuned for our upcoming Tutorial 501, where we'll explore advanced auto-tuning and optimization features aligned with Operator Capability Level 5.
