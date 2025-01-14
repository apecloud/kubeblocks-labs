# Deploy MySQL Cluster

## Step 1 - Create the MySQL Cluster

Create a MySQL cluster named **mycluster** with the specified CPU and memory limits:

```bash
kbcli cluster create mysql mycluster --cpu=0.5 --memory=0.5
```{{exec}}

Check the pod status:

```bash
kubectl get pods
```{{exec}}

> **Note**: It may take a few minutes for the pods to transition to `Running`. You should see output similar to:

```
controlplane $ kubectl get pods
NAME                READY   STATUS    RESTARTS   AGE
mycluster-mysql-0   4/4     Running   0          9m8s
```

## Step 2 - Connect to the MySQL Cluster

**Wait for port 3306 to become available**:

```bash
kubectl exec mycluster-mysql-0 -- sh -c 'until mysqladmin ping -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD --silent; do echo "Waiting for MySQL on port 3306..." && sleep 5; done'
```{{exec}}

Once the cluster is ready and 3306 is open, connect to MySQL by running:

```bash
kubectl exec -it mycluster-mysql-0 -- bash -c 'mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD'
```{{exec}}

> **Tip**: For information on how to view the username and password, or to connect in other ways, see the [KubeBlocks documentation](https://kubeblocks.io/docs/preview/user_docs/kubeblocks-for-mysql-community-edition/cluster-management/create-and-connect-a-mysql-cluster#connect-to-a-mysql-cluster).
