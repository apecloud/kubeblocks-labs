# Deploy Database Cluster

## Step 1 - Create the Cluster

Create a MySQL cluster named **mycluster** with the specified CPU and memory limits:

```bash
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
```{{exec}}

Check the pod status:

```bash
kubectl get pods -n demo
```{{exec}}

> **Note**: It may take a few minutes for the pods to transition to `Running`. You should see output similar to:

```
controlplane $ kubectl get pods -n demo
NAME                READY   STATUS    RESTARTS   AGE
mycluster-mysql-0   4/4     Running   0          9m8s
```

## Step 2 - Connect to the MySQL Cluster

**Wait for port 3306 to become available**:

```bash
kubectl -n demo exec mycluster-mysql-0 -- sh -c 'until mysqladmin ping -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD --silent; do echo "Waiting for MySQL on port 3306..." && sleep 5; done'
```{{exec}}

Once the cluster is ready and 3306 is open, connect to MySQL by running:

```bash
kubectl -n demo exec -it mycluster-mysql-0 -- bash -c 'mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD'
```{{exec}}

> **Tip**: For information on how to view the username and password, or to connect in other ways, see the [KubeBlocks documentation](https://kubeblocks.io/docs/preview/user_docs/kubeblocks-for-mysql-community-edition/cluster-management/create-and-connect-a-mysql-cluster#connect-to-a-mysql-cluster).
