# 01 – Ansible hardening Debian serveru

Automatizované zabezpečení domácího NASu: SSH jen klíčem, UFW firewall,
fail2ban, automatické bezpečnostní aktualizace. Notebook = control node.

    ansible nas -m ping
    ansible-playbook site.yml --check --diff -K
    ansible-playbook site.yml -K
