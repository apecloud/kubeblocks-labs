# Deploy KubeBlocks

In this scenario, you'll learn how to deploy **KubeBlocks** in your Kubernetes cluster.

## Step 1 - Prepare Environment

Set up the following environment variables:

```bash
export KB_CLI_VERSION=v1.0.0-beta.8
export KB_VERSION=v1.0.0-beta.20
```{{exec}}

## Step 2 - Install KubeBlocks CLI

Install the KubeBlocks CLI tool:

```bash
curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash -s $KB_CLI_VERSION
```{{exec}}

## Step 3 - Install CRDs

Install the Custom Resource Definitions (CRDs) required by KubeBlocks:

```bash
kubectl create -f https://github.com/apecloud/kubeblocks/releases/download/$KB_VERSION/kubeblocks_crds.yaml
```{{exec}}

## Step 4 - Add the Helm Repository

Add the official KubeBlocks Helm repository and then update your local repo cache:

```bash
helm repo add kubeblocks https://apecloud.github.io/helm-charts
helm repo update
```{{exec}}

## Step 5 - Install KubeBlocks with Helm

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

To verify your installation, run:
```bash
kubectl get pods -n kb-system
```{{exec}}

> **Note**: It may take a few minutes for all pods to transition to Running status. Once you see output similar to the following, the deployment is complete:

```
controlplane $ kubectl get pods -n kb-system
NAME                                            READY   STATUS    RESTARTS   AGE
kb-addon-snapshot-controller-6d6b8486f5-68hsq   1/1     Running   0          5m51s
kubeblocks-746dcc597-crpcj                      1/1     Running   0          6m26s
kubeblocks-dataprotection-587bb588b4-wlwxw      1/1     Running   0          6m26s
```