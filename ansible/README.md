# Ansible Automation for Enterprise Docker Registry

This directory contains Ansible automation for managing secure Docker registry certificates across Kubernetes clusters.

## Structure

```
ansible/
├── ansible.cfg                    # Ansible configuration
├── inventory/
│   └── k8s-cluster.yml           # Kubernetes cluster inventory
├── playbooks/
│   ├── deploy-registry-certificates.yml  # Main playbook
│   └── templates/
│       ├── containerd-hosts.toml.j2      # Containerd configuration
│       └── deployment-report.md.j2       # Deployment report
└── README.md                      # This file
```

## Prerequisites

1. **Ansible installed** on control machine
2. **SSH access** to all Kubernetes nodes with ansible user
3. **Registry certificate** available at `/opt/registry/certs/domain.crt`
4. **Sudo privileges** for ansible user on target nodes

## Usage

### Deploy Registry Certificates

```bash
# Navigate to ansible directory
cd ansible/

# Test connectivity to all nodes
ansible all -m ping

# Deploy certificates (dry run)
ansible-playbook playbooks/deploy-registry-certificates.yml --check

# Deploy certificates
ansible-playbook playbooks/deploy-registry-certificates.yml

# Deploy to specific host group
ansible-playbook playbooks/deploy-registry-certificates.yml --limit k8s_workers
```

### Verification

```bash
# Check containerd service status on all nodes
ansible k8s_cluster -a "systemctl status containerd" --become

# Verify certificate installation
ansible k8s_cluster -a "ls -la /etc/containerd/certs.d/192.168.0.100:5000/" --become

# Test registry connectivity
ansible k8s_cluster -m uri -a "url=https://192.168.0.100:5000/v2/ validate_certs=no"
```

## Configuration Variables

Key variables in `inventory/k8s-cluster.yml`:

- `registry_host`: Registry server IP
- `registry_port`: Registry server port
- `local_cert_path`: Path to certificate on control machine
- `containerd_cert_dir`: Target directory for containerd certificates
- `system_ca_dir`: System CA certificate directory

## Security Features

- ✅ **TLS certificate distribution**
- ✅ **Containerd configuration**
- ✅ **System CA trust store**
- ✅ **Backup of existing configurations**
- ✅ **Connectivity testing**
- ✅ **Deployment reporting**

## Troubleshooting

### SSH Issues
```bash
# Test SSH connectivity
ansible all -m setup --limit k8s-worker-1

# Check SSH configuration
ssh -v ansible@192.168.0.190
```

### Certificate Issues
```bash
# Verify certificate format
openssl x509 -in /opt/registry/certs/domain.crt -text -noout

# Check certificate on remote nodes
ansible k8s_cluster -a "openssl x509 -in /etc/containerd/certs.d/192.168.0.100:5000/ca.crt -subject -dates -noout" --become
```

### Containerd Issues
```bash
# Restart containerd on all nodes
ansible k8s_cluster -a "systemctl restart containerd" --become

# Check containerd logs
ansible k8s_cluster -a "journalctl -u containerd --since '5 minutes ago' --no-pager" --become
```

## Enterprise Best Practices

1. **Version Control**: All playbooks are version controlled
2. **Idempotency**: Playbooks can be run multiple times safely
3. **Backup**: Existing configurations are backed up automatically
4. **Reporting**: Detailed deployment reports generated
5. **Testing**: Connectivity tests included
6. **Security**: Certificates have proper ownership and permissions

## Integration with CI/CD

This playbook can be integrated into CI/CD pipelines:

```yaml
# GitLab CI example
deploy_certificates:
  stage: deploy
  script:
    - cd ansible/
    - ansible-playbook playbooks/deploy-registry-certificates.yml
  only:
    - main
```

---
**Enterprise DevOps - HeyCard Crypto Rates Project**