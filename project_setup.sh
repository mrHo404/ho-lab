#!/usr/bin/env bash
set -euo pipefail

if [[ ${TRACE:-0} == 1 ]]; then
    set -o xtrace
fi

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

if ! command -v python3 >/dev/null; then
    echo "python3 not found on PATH"
    exit 1
fi

source project.env

rm -rf ansible_env
python3 -m venv ansible_env
source ansible_env/bin/activate

python3 -m pip install --upgrade pip
python3 -m pip install --upgrade \
    "ansible==${ANSIBLE_VERSION}" \
    "ansible-core==${ANSIBLE_CORE_VERSION}" \
    "ansible-lint==${ANSIBLE_LINT_VERSION}"

mkdir -p ansible/collections
ansible-galaxy collection install -r requirements.yml -p ansible/collections

printf '\nSuccess!\n'
printf 'Next steps:\n'
printf '  cp inventory.ini.example inventory.ini\n'
printf '  cp group_vars/homelab/vault.yml.example group_vars/homelab/vault.yml\n'
printf '  ansible-vault encrypt group_vars/homelab/vault.yml\n'
printf '  echo "your-passphrase" > vault_password.txt && chmod 600 vault_password.txt\n'
