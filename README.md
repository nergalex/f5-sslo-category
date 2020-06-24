# Use Case
[F5 BIG-IP SSL Orchestrator](https://www.f5.com/products/security/ssl-orchestrator) can use a [Security Policy](https://techdocs.f5.com/en-us/bigip-15-1-0/big-ip-access-policy-manager-visual-policy-editor/per-request-policy-item-reference/about-per-request-classification-items/about-category-lookup.html) based on [Custom URL Categories](https://techdocs.f5.com/en-us/bigip-15-1-0/big-ip-access-policy-manager-implementations/custom-url-categorization.html).
Current URL lists of Custom URL Categories are stored in a Highly Available "Source of Truth" system.
This "Source of Truth" can be used by a Ticketing system or a Cloud Management Platform to retrieve current URL list of a custom URL category, displayed to end-users before requesting a change.
To be more reliable and faster in your Service Request deployment, changes on a Custom URL Category can be automated.
If a business impact occurs after a deployment, an automated rollback action can be raised to deploy the previous URL list of a Custom URL Category.

# How does it work?
* A custom URL category is updated by API calls on a F5 BIG-IP device with [Ansible](https://docs.ansible.com/ansible/latest/modules/uri_module.html).
* Before apply a change on a BIG-IP device, current custom URL category value (URLs list) is saved in a remote system [Consul](https://www.consul.io/api/kv.html) as a backup configuration.
* After apply a change on a BIG-IP device, current custom URL category value is saved in Consul system as a "Source of Truth".
* Current URL list value of a custom URL category can be requested through Consul by any source, if an ACL allows it.
* A rollback for a custom URL category is done using the backup custom URL category value stored in Consul.

# Quick install
## Ansible (Tower)
Create a virtualenv, follow [Tower admin guide](https://docs.ansible.com/ansible-tower/latest/html/administration/tipsandtricks.html#preparing-a-new-custom-virtualenv)
Install ansible >= 2.9
```bash
$ sudo yum groupinstall -y "development tools"
$ sudo virtualenv /var/lib/awx/venv/my_env
$ sudo /var/lib/awx/venv/my_env/bin/pip install python-memcached psutil python-consul requests
$ sudo /var/lib/awx/venv/my_env/bin/pip install -U ansible
```

Ensure that your virtualenv have the rights 755, else:
```bash
$ chmod 755 -R /var/lib/awx/venv/my_env
```

## Consul
Consul is used as a "Source of Truth" system.
Choose your install guide: customized or quick :o)
### Customized
Follow [Consul install guide](https://learn.hashicorp.com/consul/datacenter-deploy/deployment-guide#install-consul)

### Quick
* Create 1 VM for consul agent "client". 1 vCPU, 4GB RAM, 20GB Disk, CentOS 7.5, 1 NIC
* Create 2 VMs for consul agent "server". 1 vCPU, 4GB RAM, 20GB Disk, CentOS 7.5, 1 NIC
* Private IP of each VM is noted `<VM_ip>` in this guideT
* Choose a "server" VM as Master. The private IP of Master VM is noted `<VM_master_ip>` in this guide
* Copy or `git clone` .sh script in `consul_install` directory
* On all VMs, execute:
```bash
$ bash ./install_consul.sh
$ 	vi /etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/bin/consul reload
ExecStop=/usr/bin/consul leave
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
* On all VMs, execute:
```bash
$ bash ./config_consul_agent.sh
```
* Pick one generate key (example `XjnschM8RGlRA4dusLUpZARqcYk6XQ5QxhrGOa9FAw0=`), noted as `<consul_keygen_value>` in this guide.
* On all VMs, execute:
```bash
$ vi /etc/consul.d/consul.hcl
datacenter = "cloudbuilder"
data_dir = "/opt/consul"
encrypt = "<consul_keygen_value>"
bind_addr = "<VM_ip>"
client_addr = "<VM_ip>"
```
* On all VMs, except MASTER VM, add this line at the end of `/etc/consul.d/consul.hcl` file:
```bash
retry_join = ["<VM_master_ip>"]
```
* On "server" VMs, execute:
```bash
$ vi /etc/consul.d/consul.hcl
server = true
bootstrap_expect = 2
ui = true
```
* Start Master VM and then all VMs:
```bash
sudo systemctl enable consul
sudo systemctl start consul
sudo systemctl status consul
```

# URL Category playbooks
Create and launch a job template that include each of those playbooks:

| Job template  | playbook      | activity      | inventory     | limit         | credential   |
| ------------- | ------------- | ------------- | ------------- | ------------- |------------- |
| `poc-f5_url_category-add_url`             | `playbooks/poc-f5.yaml`       | `url_category-add_url`            | `localhost`  | `localhost` | none |
| `poc-f5_url_category-remove_url`          | `playbooks/poc-f5.yaml`       | `url_category-remove_url`         | `localhost`  | `localhost` | none |
| `poc-f5_url_category-rollback_category`   | `playbooks/poc-f5.yaml`       | `url_category-rollback_category`  | `localhost`   | `localhost` | none |

| Extra variable| Description | Example of value      |
| ------------- | ------------- | ------------- |
| `activity`               | Refer to Job template above definition | `url_category-add_url` |
| `extra_admin_user`               | BIG IP admin username | `admin` |
| `extra_admin_password`  | BIG-IP admin password | `Ch4ngeMe!` |
| `extra_ip_mgt`  | BIG-IP management IP | `10.228.234.11` |
| `extra_port_mgt`   | BIG-IP management IP | `443` |
| `extra_category`   | Custom URL category to update | `custom_cat_a` |
| `extra_url_name`   | Custom URL to add or remove | `*www.test7.com*` |
| `extra_url_type`   | Custom URL type associated to the URL to add or remove | `glob-match` |
| `extra_consul_path_backup`   | Consul backup path | `poc_f5/outbound/sslo/custom_category/pre-mep` |
| `extra_consul_path_source_of_truth`   | Consul Source of Truth path | `poc_f5/outbound/sslo/custom_category/current` |
| `extra_consul_agent_scheme`   | Consul scheme access | `http` |
| `extra_consul_agent_ip`   | Consul agent "client" IP to use | `10.0.0.20` |
| `extra_consul_agent_port`   | Consul agent "client" port to use | `8500` |
| `extra_consul_datacenter`   | Consul DC to store key/value | `8500` |

