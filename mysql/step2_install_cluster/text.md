# Deploy MySQL Cluster

## Step 6 - Create MySQL Cluster

```
kbcli cluster create mysql mycluster --cpu=0.5 --memory=0.5
```{{exec}}

You can view the status of the cluster:
```
kbcli cluster describe mycluster
```{{exec}}

Then you can connect to the MySQL cluster using the following command:
```
kubectl exec -it mycluster-mysql-0 -- bash -c 'mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD'
```{{exec}}
