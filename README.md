Summary
======
# Use Case
* __Web Proxy__: Protect consumption of URLs from Application servers by using a Web Proxy [F5 BIG-IP SSL Orchestrator](https://www.f5.com/products/security/ssl-orchestrator)
* __Authentication__: SSLO acts as an explicit Proxy to authenticate servers by using a service account. Application's service account is verified by SSLO from an AAA server (local DB, LDAP server, Azure ADFS...) and its belonging server's group is also retrieved
* __Authorization__: SSLO allows a list of URLs per server group, based on the service account used to connect
* __Automation__: automate changes on SSLO via BIG-IP API
1. _Create a subscription_: Authorize a new server group to access to Internet limited to a default allowed URL list
2. _Update >> Add allow URL_: Authorize an existing server group to access to new URLs
3. _Update >> Remove allow URL_: Remove allowed URLs for an existing server group
4. _Delete a subscription_: Remove an authorized server group to access to Internet
* __Source of Truth__: INPUT form issued from changes are stored in an Highly Available "Source of Truth" system.

# Benefit
* __Resiliency__: Miminal data (subscription's service account, URL allowed list) are stored in a Highly Available "Source of Truth" system through a multi-region/multi-cloud environment.
* __Time to market__: To be more reliable and faster in your Service Request deployment, changes on a Custom URL Category can be automated.
* __Reliable__: "Source of Truth" (Control Plane) can be used by a Ticketing system or a Cloud Management Platform to retrieve current configuration, displayed to end-users before requesting a change, in spite of impacting Data Plane devices.

# Eco-system
* [SSLO Security Policy](https://techdocs.f5.com/en-us/bigip-15-1-0/big-ip-access-policy-manager-visual-policy-editor/per-request-policy-item-reference/about-per-request-classification-items/about-category-lookup.html) based on [Custom URL Categories](https://techdocs.f5.com/en-us/bigip-15-1-0/big-ip-access-policy-manager-implementations/custom-url-categorization.html) or [data-group](https://techdocs.f5.com/kb/en-us/products/big-ip_ltm/manuals/product/bigip-system-irules-concepts-11-6-0/6.html).
* [Ansible](https://docs.ansible.com/ansible/latest/modules/uri_module.html) is used to update Security Policy, custom URL category or data-group by API calls on F5 BIG-IP device.
* [Consul](https://www.consul.io/api/kv.html) is used to store form INPUT or custom URL categories (URLs list) as a backup configuration.

# Proof of Concept
This configuration has been done for a POC, do not use it as-is in a Production environment. Use of custom URL category have performance impacts, technical recommendation bellow must be taken in consideration. 
* `glob-match` URL type: Custom categories consume CPU just by existing, categories with `glob-match` patterns doubly so. Try to avoid `glob-match` categories if you can.
* max URLs: if a custom URL category start to exceed 200 URLs, consider switching to a `data group` design

# Quick install
## Ansible (Tower)
Create a virtualenv, follow [Tower admin guide](https://docs.ansible.com/ansible-tower/latest/html/administration/tipsandtricks.html#preparing-a-new-custom-virtualenv).
Install ansible version >= 2.9
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
Choose your install guide: customized or automated
### Customized
Follow [Consul install guide](https://learn.hashicorp.com/consul/datacenter-deploy/deployment-guide#install-consul)

### Quick... and not so dirty
* Create 1 VM for consul agent "client". 1 vCPU, 4GB RAM, 20GB Disk, CentOS 7.5, 1 NIC
* Create 2 VMs for consul agent "server". 1 vCPU, 4GB RAM, 20GB Disk, CentOS 7.5, 1 NIC
* Private IP of each VM is noted `<VM_ip>` in this guide
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
