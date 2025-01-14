# Deploy Database Cluster

## Step 1 - Create the Cluster

Create a **Redis** cluster named **mycluster** with the specified CPU and memory limits:

```bash
kubectl create namespace demo
cat <<EOF | kubectl apply -f -
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: mycluster
  namespace: demo
spec:
  terminationPolicy: Delete
  componentSpecs:
  - name: redis
    componentDef: redis-7
    affinity:
      podAntiAffinity: Preferred
      topologyKeys:
      - kubernetes.io/hostname
      tenancy: SharedNode
    tolerations:
    - key: kb-data
      operator: Equal
      value: 'true'
      effect: NoSchedule
    disableExporter: true
    enabledLogs:
    - running
    replicas: 1
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
  - name: redis-sentinel
    componentDef: redis-sentinel-7
    disableExporter: false
    affinity:
      podAntiAffinity: Preferred
      topologyKeys:
      - kubernetes.io/hostname
      tenancy: SharedNode
    tolerations:
    - key: kb-data
      operator: Equal
      value: 'true'
      effect: NoSchedule
    replicas: 1
    resources:
      limits:
        cpu: '0'
        memory: 0.5Gi
      requests:
        cpu: '0'
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
```{{exec}}

Check the pod status:

```bash
kubectl get pods -n demo
```{{exec}}

> **Note**: It may take a few minutes for the pods to transition to `Running`. You should see output similar to:

```
controlplane $ kubectl get pods -n demo
NAME                           READY   STATUS    RESTARTS   AGE
mycluster-redis-0              2/2     Running   0          2m43s
mycluster-redis-sentinel-0     2/2     Running   0          2m43s
```

## Step 2 - Connect to the Redis Cluster

Wait for port 6379 to become available (main Redis port), Once the cluster is ready and port 6379 is open, connect to Redis by running:

```bash
kubectl -n demo exec -it mycluster-redis-0 -- \
    bash -c 'redis-cli -h 127.0.0.1 -p 6379'
```{{exec}}

> **Tip**: For information on how to view the username and password, or to connect in other ways, see the [KubeBlocks documentation](https://kubeblocks.io/docs/).