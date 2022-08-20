### Install ansible
https://docs.ansible.com/ansible/2.9/installation_guide/intro_installation.html

### Install boto3
https://crunchify.com/how-to-install-boto3-and-set-amazon-keys-a-python-interface-to-amazon-web-services/

### Start all servers

```bash
./scripts/aws/start_all_servers.sh
```

### Stop all servers

```bash
./scripts/aws/stop_all_servers.sh
```

### Generate proto file
```bash
./scripts/proto/sync_proto.sh DEPENDENCY_FILE=./scripts/proto/protodep.yaml
```
