# Deploy Database Cluster

## Step 1 - Create the Cluster

Create a **PostgreSQL** cluster named **mycluster** with the specified CPU and memory limits:

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
  - name: postgresql
    componentDef: postgresql-12
    enabledLogs:
    - running
    disableExporter: true
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
```{{exec}}

Check the pod status:

```bash
kubectl get pods -n demo
```{{exec}}

> **Note**: It may take a few minutes for the pods to transition to `Running`. You should see output similar to:

```
controlplane $ kubectl get pods -n demo
NAME                     READY   STATUS    RESTARTS   AGE
mycluster-postgresql-0   4/4     Running   0          2m43s
```

## Step 2 - Connect to the PostgreSQL Cluster

**Wait for port 5432 to become available**:

```bash
kubectl -n demo exec mycluster-postgresql-0 -- \
    sh -c 'until pg_isready -h 127.0.0.1 -p 5432 -U postgres; do \
    echo "Waiting for PostgreSQL on port 5432..." && sleep 5; \
    done'
```{{exec}}

Once the cluster is ready and port 5432 is open, connect to PostgreSQL by running:

```bash
kubectl -n demo exec -it mycluster-postgresql-0 -- \
    bash -c 'psql -h 127.0.0.1 -p 5432 -U postgres'
```{{exec}}

> **Tip**: For information on how to view the username and password, or to connect in other ways, see the [KubeBlocks documentation](https://kubeblocks.io/docs/).