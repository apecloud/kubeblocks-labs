# Deploy KubeBlocks

In this scenario, you will learn how to deploy KubeBlocks in your Kubernetes cluster.

## Step 1 - Prepare Environment

First, set up the required environment variables:

```bash
export KB_CLI_VERSION=v1.0.0-beta.8
export KB_VERSION=v1.0.0-beta.20
```{{exec}}

## Step 2 - Install KubeBlocks CLI

Run the following command to install the KubeBlocks CLI tool:

```bash
curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash -s $KB_CLI_VERSION
```{{exec}}

## Step 3 - Install CRDs

Install the Custom Resource Definitions (CRDs) required by KubeBlocks:

```bash
kubectl create -f https://github.com/apecloud/kubeblocks/releases/download/$KB_VERSION/kubeblocks_crds.yaml
```{{exec}}

## Step 4 - Add Helm Repository

Add the KubeBlocks Helm repository and update:

```bash
helm repo add kubeblocks https://apecloud.github.io/helm-charts
helm repo update
```{{exec}}

## Step 5 - Install KubeBlocks using Helm

Finally, install KubeBlocks using Helm:

```bash
helm -n kb-system install kubeblocks kubeblocks/kubeblocks --version 1.0.0-beta.20 \
  --set image.registry=docker.io \
  --set dataProtection.image.registry=docker.io \
  --set addonChartsImage.registry=docker.io \
  --set 'autoInstalledAddons[0]=mysql' \
  --set 'autoInstalledAddons[1]=snapshot-controller' \
  --create-namespace
```{{exec}}

✅ After completing these steps, you have successfully deployed KubeBlocks in your cluster!

You can verify the installation by running:
```bash
kubectl get pods
```{{exec}}

You should see all pods in Running status.

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