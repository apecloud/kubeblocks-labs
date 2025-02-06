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

cover: __static__/backup-restore2.png

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
      if kubectl get backup -n demo >/dev/null 2>&1; then
        echo "💡 Backup task is in progress..."
        echo "⏳ Please wait a few minutes for the backup to complete."
      else
        echo "❌ No backup found in namespace 'demo'"
        echo "💡 You need to create a backup first"
      fi

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
---

# KubeBlocks Tutorial 401 – Observability in Action

Welcome to the fourth chapter of our KubeBlocks tutorial series! In this tutorial, we’ll explore **Observability**—a key feature of **Operator Capability Level 4**. You’ll learn how to monitor, analyze, and troubleshoot your database clusters on Kubernetes with built-in observability features.

> **Tip:** If you find KubeBlocks useful, please consider starring our [GitHub repository](https://github.com/apecloud/kubeblocks). Every star helps us improve!

---

## 1. Introduction

- **Overview:**
    - Introduce observability as an essential aspect for production environments.
    - Explain that Operator Capability Level 4 extends KubeBlocks with monitoring, logging, metrics, and alerting capabilities.
- **Recap:**
    - Briefly mention previous tutorials (101 – Getting Started, 201 – Seamless Upgrades, 301 – Backup & Restore) and how observability ties into full lifecycle management.
- **Goals:**
    - Demonstrate how to enable and leverage observability features.
    - Show how to access metrics, logs, and alerts to ensure the health of your database clusters.

---

## 2. Prerequisites

- **Environment Setup:**
    - KubeBlocks is already installed.
    - A sample database cluster (for example, a 3-replica MySQL cluster in the `demo` namespace) is running.
- **Tools:**
    - The `kbcli` CLI tool is installed.
    - Observability components (e.g., Prometheus and Grafana) are pre-configured or available in the lab environment.
- **Verification Tasks:**
    - Confirm that the KubeBlocks operator and the sample database cluster are up and running.
    - Ensure observability endpoints (metrics, logging) are accessible.

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
  :name: verify_cluster_status
  ---
  #active
  Confirming the sample database cluster is running in the `demo` namespace...

  #completed
  Great! The cluster is running.
  ::

---

## 3. Observability Fundamentals with KubeBlocks

- **What is Observability?**
    - Define observability in the context of Kubernetes: monitoring metrics, logs, and events to gain insights into the system’s behavior.
- **Operator Capability Level 4:**
    - Explain how KubeBlocks leverages observability to provide deep insights into database health, performance, and operational anomalies.
- **Components:**
    - **Metrics:** Integration with Prometheus for scraping cluster metrics.
    - **Logging:** Aggregated logs via native Kubernetes logging or integrated logging solutions.
    - **Alerting:** Configuring alerts for critical events and performance thresholds.

- **Visual Aid:**
    - Include an image/diagram that outlines the observability stack (e.g., showing Prometheus, Grafana, and logging pipelines).

  ::image-box
  ---
  src: __static__/observability-stack.png
  alt: 'Observability Stack for KubeBlocks'
  ---
  ::

---

## 4. Enabling Observability for a KubeBlocks Cluster

- **Configuration Overview:**
    - Discuss how to enable observability features in your cluster’s definition.
    - Explain any annotations, labels, or configuration fields that activate observability.
- **Example YAML Snippet:**
    - Show how to modify a cluster resource to enable Prometheus scraping or add observability sidecars.

  ```yaml
  apiVersion: apps.kubeblocks.io/v1alpha1
  kind: Cluster
  metadata:
    name: mycluster
    namespace: demo
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "9187"
  spec:
    clusterDefinitionRef: apecloud-mysql
    clusterVersionRef: ac-mysql-8.0.30
    terminationPolicy: WipeOut
    componentSpecs:
      - name: mysql
        componentDefRef: mysql
        replicas: 3
  ```
- **Task:**
    - Apply the updated cluster configuration and verify that observability endpoints are active.

  ::simple-task
  ---
  :tasks: tasks
  :name: apply_observability_config
  ---
  #active
  Applying the observability configuration to your cluster...

  #completed
  Configuration applied successfully! Observability endpoints are now active.
  ::

---

## 5. Accessing and Visualizing Metrics

- **Accessing Metrics:**
    - Explain how Prometheus scrapes metrics from your KubeBlocks cluster.
    - Demonstrate how to query metrics directly via Prometheus or through Grafana dashboards.
- **Steps to Visualize:**
    - Use port-forwarding to access the Prometheus and/or Grafana UI.
    - Provide sample queries that reveal key database performance indicators (e.g., connection counts, query latency, resource usage).

  ```bash
  # Example: Port-forward to access Grafana
  kubectl port-forward svc/grafana -n observability 3000:80
  ```
- **Task:**
    - Verify that you can see the cluster metrics and dashboards are updating.

  ::simple-task
  ---
  :tasks: tasks
  :name: verify_metrics_endpoint
  ---
  #active
  Accessing Prometheus/Grafana to verify metrics are visible...

  #completed
  Great! Metrics are being collected and visualized.
  ::

---

## 6. Log Aggregation and Analysis

- **Log Access:**
    - Detail how logs are collected from your database cluster pods.
    - Explain integration with logging tools (e.g., EFK/ELK stack) if available.
- **Troubleshooting with Logs:**
    - Provide sample commands to view and analyze logs for troubleshooting.

  ```bash
  # Example: Fetch logs from a MySQL pod
  kubectl logs mycluster-mysql-0 -n demo
  ```
- **Task:**
    - Retrieve and inspect logs to ensure that any anomalies are captured.

  ::simple-task
  ---
  :tasks: tasks
  :name: inspect_cluster_logs
  ---
  #active
  Retrieving logs from a database pod...

  #completed
  Logs retrieved successfully!
  ::

---

## 7. Alerts and Anomaly Detection

- **Alerting Overview:**
    - Explain how alerts can be configured based on metrics thresholds or error logs.
- **Example Alert Configuration:**
    - Show an example of a Prometheus alert rule that notifies you when query latency exceeds a defined threshold.

  ```yaml
  groups:
  - name: mysql-alerts
    rules:
    - alert: HighQueryLatency
      expr: mysql_query_latency_seconds_mean > 0.5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High query latency detected in MySQL cluster"
        description: "Query latency has exceeded 0.5 seconds for more than 2 minutes."
  ```
- **Simulate and Verify Alerts:**
    - Describe how to simulate an alert (e.g., by generating load or using a test metric).
    - Provide steps to verify that the alert is triggered and visible in your alerting dashboard.

- **Task:**
    - Configure and test an alert to ensure notifications are working as expected.

  ::simple-task
  ---
  :tasks: tasks
  :name: verify_alerts
  ---
  #active
  Configuring and testing alert rules...

  #completed
  Alert triggered and verified successfully!
  ::

---

## 8. Observability Best Practices and Advanced Features

- **Best Practices:**
    - Recommendations on setting up dashboards, alert thresholds, and log retention policies.
    - Tips for proactive monitoring and anomaly detection.
- **Advanced Topics:**
    - Integrating distributed tracing (if applicable).
    - Customizing observability configurations for multi-region or multi-cluster environments.
    - Combining observability data with auto-scaling policies.

---

## 9. Summary

- **Recap:**
    - We demonstrated how to enable and leverage observability features in KubeBlocks.
    - Covered accessing metrics, logs, and setting up alerting mechanisms.
- **Benefits:**
    - Emphasized how observability helps maintain high availability, performance, and facilitates proactive troubleshooting for your database clusters.
- **Next Steps:**
    - Encourage exploring additional observability integrations and advanced monitoring configurations.

---

## 10. What’s Next?

- **Further Exploration:**
    - Experiment with integrating other monitoring tools or custom dashboards.
    - Dive deeper into distributed tracing or anomaly detection with more advanced setups.
- **Additional Resources:**
    - Links to KubeBlocks documentation on observability.
    - Tutorials on advanced monitoring strategies for Kubernetes.

