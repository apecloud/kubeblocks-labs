
Install kbcli:
```bash
curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash
```{{exec}}

Install Kubeblocks:
```bash
helm -n kb-system upgrade -i kubeblocks kb-jh/kubeblocks --version="$kb_version" \
  --set image.registry=docker.io \
  --set dataProtection.image.registry=docker.io \
  --set addonChartsImage.registry=docker.io \
```{{exec}}