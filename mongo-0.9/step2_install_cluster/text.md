# Deploy Database Cluster

## Step 1 - Create the Cluster

Create a **MongoDB** cluster named **mycluster** with the specified CPU and memory limits:

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
  - name: mongodb
    componentDef: mongodb
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
NAME                    READY   STATUS    RESTARTS   AGE
mycluster-mongodb-0     2/2     Running   0          2m43s
```

## Step 2 - Connect to the MongoDB Cluster

**Wait for port 27017 to become available**:

```bash
kubectl -n demo exec mycluster-mongodb-0 -- \
    sh -c 'until mongo --host 127.0.0.1 --port 27017 --eval "db.runCommand({ping:1})" > /dev/null 2>&1; do \
    echo "Waiting for MongoDB on port 27017..." && sleep 5; \
    done'
```{{exec}}

Once the cluster is ready and port 27017 is open, connect to MongoDB by running:

```bash
kubectl -n demo exec -it mycluster-mongodb-0 -- \
    bash -c 'mongo --host 127.0.0.1 --port 27017'
```{{exec}}

> **Tip**: For information on how to view the username and password, or to connect in other ways, see the [KubeBlocks documentation](https://kubeblocks.io/docs/).