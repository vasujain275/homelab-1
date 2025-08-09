# Homelab Infrastructure

This repository contains the configuration for a personal homelab setup, designed to run various services on a dedicated machine within a local network. The services are containerized using Docker and can be easily managed with `docker-compose`.

## Services

For a quick overview of all available services and how to connect to them, please see the [Services README](services/README.md).

This repository also includes a complete [Observability Stack](observability/README.md) to monitor the health and performance of your applications.

## Encrypting Secrets

To safely back up environment configurations to this Git repository, all `.env` files should be encrypted into a `.env.vault` file using `ansible-vault`. This prevents sensitive information like passwords and API keys from being stored in plain text.

### Prerequisites

You must have Ansible installed. If you don't have it, you can install it with pip:
```bash
pip install ansible
```

### Creating the Vault Password File

It is recommended to store your vault password in a file to avoid typing it repeatedly. **This file must not be committed to Git.**

1.  Create a file named `.vault_pass` in the root of this repository.
2.  Add your desired vault password to this file.
3.  Add `.vault_pass` to the global `.gitignore` file to prevent it from being committed.

### Encryption Command

To encrypt an environment file (e.g., `services/postgresql/.env`), run the following command from the service's directory:

```bash
ansible-vault encrypt .env --output .env.vault --vault-password-file ../../.vault_pass
```

This will create an encrypted `.env.vault` file. You can now safely delete the plaintext `.env` file.

### Decryption Command

To restore a plaintext `.env` file from its encrypted vault, run the following command from the service's directory:

```bash
ansible-vault decrypt .env.vault --output .env --vault-password-file ../../.vault_pass
```

This is typically done after cloning the repository to a new machine.
