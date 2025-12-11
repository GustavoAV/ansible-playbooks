# Ansible Playbooks

Repository with many Ansible playbooks.

- [Ansible Playbooks](#ansible-playbooks)
  - [Requirements](#requirements)
  - [Usage](#usage)
  - [Development](#development)

## Requirements

Requirements for the playbooks:

- Operational system: Debian 11+, Ubuntu 22+, RedHat 9+
- Internet connection

## Usage

Clone this project and apply a playbook using your inventory file

```bash
git clone https://github.com/GustavoAV/ansible-playbooks.git
cd ansible-playbooks/

ansible-playbook -i inventory setup_uv.yml
```

## Development

> First, install **docker**.

To setup your development environment, run the commands below.

```bash
# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env

# Install Ansible tools
uv tool install ansible-dev-tools \
  --with-executables-from=ansible-core,ansible-lint \
  --with-requirements requirements.txt

# Validate
ansible --version
molecule --version
```

And then, to test a playbook:

```bash
MOLECULE_PLAYBOOK=setup_uv.yml molecule -v test
```
