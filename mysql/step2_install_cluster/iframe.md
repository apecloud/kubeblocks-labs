[Create and connect](https://kubeblocks.io/docs/preview/user_docs/kubeblocks-for-mysql-community-edition/cluster-management/create-and-connect-a-mysql-cluster)

[]: # Compare this snippet from mysql/step2_install_cluster/iframe.md:
[]: # <iframe src="https://kubeblocks.io/docs/preview/user_docs/kubeblocks-for-mysql-community-edition/cluster-management/create-and-connect-a-mysql-cluster" width="100%" height="1000px"></iframe>
[]: # 
[]: # Compare this snippet from mysql/step2_install_cluster/text.md:
[]: # # Deploy MySQL Cluster
[]: # 
[]: # ## Step 6 - Create MySQL Cluster
[]: # 
[]: # ```
[]: # kbcli cluster create mysql mycluster --cpu=0.5 --memory=0.5
[]: # ```{{exec}}
[]: # 
[]: # You can view the status of the cluster:
[]: # ```
[]: # kbcli cluster describe mycluster
[]: # ```{{exec}}
[]: # 
[]: # Then you can connect to the MySQL cluster using the following command:
[]: # ```
[]: # kubectl exec -it mycluster-mysql-0 -- bash -c 'mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD'
[]: # ```{{exec}}
[]: # Compare this snippet from README.md:
[]: # https://killercoda.com/kubeblocks/scenario/kubeblocks-1node
[]: # Compare this snippet from docs/user_docs/kubeblocks-for-mysql-community-edition/kubeblocks-for-mysql-community-edition.md:
[]: # ---
[]: # title: KubeBlocks for MySQL Community Edition
[]:: # description: Feature list of KubeBlocks for MySQL Community Edition
[]: # keywords: [mysql, introduction, feature]
[]: # sidebar_position: 1
[]: # ---
[]: # 
[]: # # KubeBlocks for MySQL Community Edition
[]:: # 
[]: # This tutorial illustrates how to create and manage a MySQL cluster by `kbcli`, `kubectl` or a YAML file. You can find the YAML examples in [the GitHub repository](