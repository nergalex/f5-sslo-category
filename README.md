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

![alt text][sslo_config_overview](https://youtu.be/fW9g4mvxNJc)

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

Install Guide
======
# SSL Orchestrator
## Authentication policy
### LDAP server
For LDAP server, Azure ADDS authentication
* Create and populate a `ldap server`

![alt text][sslo_ldap_azure_adds]

* Create a `Per Session Policy`

![alt text][sslo_psp_auth_ldap_overwiew]

* Add a `LDAP Auth` box

![alt text][sslo_psp_auth_ldap_box_ldap_auth]

* Add a `LDAP Query` box

![alt text][sslo_psp_auth_ldap_box_ldap_query]

### local DB
For local DB authentication
* Create and populate a `local DB`

![alt text][sslo_localdb_overview]

* Create a `Per Session Policy`

![alt text][sslo_psp_auth_localdb_overwiew]

* Add a `Local Database` box

![alt text][sslo_psp_auth_localdb_box_user_group]


## Explicit Forward Proxy Topology
* Create an Explicit Forward Proxy Topology as described in this [guide](https://clouddocs.f5.com/sslo-deployment-guide/chapter2/page2.4.html)
![alt text][sslo_config_overview]

* Specify Authentication policy previously created

![alt text][sslo-config-interception_rule]

* Create a Security Policy. Create a rule to intercept traffic - and forward it to a Security Service Chain as needed - for a specific category detected `Category Lookup (All)`. Another way is to use an existing Security Policy (Per Request Policy).

![alt text][sslo-config-security_rule]

* If a Security policy was created previously, unlock it in order to modify the Per Request Policy object.
* Edit the Per Request Policy object

![alt text][sslo_prp_overview]

* Rename the `empty box` "Category Branching" as desired

![alt text][sslo_prp_empty_box]

* Lookup for this `empty box` in BIG-IP REST UI `https://myhostname/mgmt/toc`

![alt text][sslo_prp_restui_locate]

![alt text][sslo_prp_restui_empty_box]

[sslo_config_overview]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_config_overview.png "sslo_config_overview"
[sslo_localdb_overview]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_localdb_overview.png "sslo_localdb_overview"
[sslo_psp_auth_localdb_overwiew]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_psp_auth_localdb_overwiew.png "sslo_psp_auth_localdb_overwiew"
[sslo_psp_auth_localdb_box_user_group]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_psp_auth_localdb_box_user_group.png "sslo_psp_auth_localdb_box_user_group"
[sslo_ldap_azure_adds]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_ldap_azure_adds.png "sslo_ldap_azure_adds"
[sslo_psp_auth_ldap_overwiew]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_psp_auth_ldap_overwiew.png "sslo_psp_auth_ldap_overwiew"
[sslo_psp_auth_ldap_box_ldap_auth]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_psp_auth_ldap_box_ldap_auth.png "sslo_psp_auth_ldap_box_ldap_auth"
[sslo_psp_auth_ldap_box_ldap_query]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_psp_auth_ldap_box_ldap_query.png "sslo_psp_auth_ldap_box_ldap_query"
[sslo-config-interception_rule]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo-config-interception_rule.png "sslo-config-interception_rule"
[sslo-config-security_rule]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo-config-security_rule.png "sslo-config-security_rule"
[sslo_prp_overview]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_prp_overview.png "sslo_prp_overview"
[sslo_prp_empty_box]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_prp_empty_box.png "sslo_prp_empty_box"
[sslo_prp_restui_locate]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_prp_restui_locate.png "sslo_prp_restui_locate"
[sslo_prp_restui_empty_box]: https://github.com/nergalex/f5-sslo-category/blob/master/image/sslo_prp_restui_empty_box.png "sslo_prp_restui_empty_box"


# Ansible (Tower)
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

# Consul
Choose your install guide: customized from [Consul install guide](https://learn.hashicorp.com/consul/datacenter-deploy/deployment-guide#install-consul) or automated (below) with Ansible

## Credential 
Create custom credential `cred_Consul` to manage access to Consul VMs

| CREDENTIAL TYPE | USERNAME      | SSH PRIVATE KEY     | SIGNED SSH CERTIFICATE         | PRIVILEGE ESCALATION METHOD    |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| `Machine` | `my_VM_admin_user` | `my_VM_admin_user_key` | `my_VM_admin_user_CRT` | `sudo` |

## Workflow and Job Templates
Create a worflow template `wf-create_create_cluster_consul` that includes each of those job template:

| Job template  | playbook      | activity      | inventory     | limit         | credential   |
| ------------- | ------------- | ------------- | ------------- | ------------- |------------- |
| `poc-azure_create-vm-consul`  | `playbooks/poc-azure.yaml`        | `create-vm-consul`    | `localhost`   | none | `your_azure_account` |
| `poc-consul_install`          | `playbooks/poc-consul.yaml`       | `install`             | `localhost`   | none | `cred_Consul` |
| `poc-consul_keygen`           | `playbooks/poc-consul_master.yaml`| `keygen`              | `localhost`   | none | `cred_Consul` |
| `poc-consul_onboard`          | `playbooks/poc-consul.yaml`       | `onboard`             | `localhost`   | none | `cred_Consul` |

## Extra variables
A dict contains Consul cluster configuration as desired
```yaml
extra_consul_cluster:
  members:
    <logical_name>:
      az: <AZ list>
      ip_mgt: <management IP>
      master: [true | false]
      role: [client | server]
      vm_name: <VM_name>
  version: <Consul version to download>
  vm_master_ip_mgt: <management IP of the master Consul VM>
```
Example:
```yaml
extra_consul_cluster:
  members:
    server-1:
      az:
        - 1
      ip_mgt: 10.100.0.60
      master: true
      role: server
      vm_name: consul-server-1
    server-2:
      az:
        - 2
      ip_mgt: 10.100.0.61
      master: false
      role: server
      vm_name: consul-server-2
  version: 1.8.3
  vm_master_ip_mgt: 10.100.0.60
```
Other variables:

| Extra variable    | Description   | Example of value |
| -------------     | ------------- | ------------- |
| `activity`                                | Refer to Job template above definition | `poc-azure_create-vm-consul` |
| `extra_key_data`                          | admin CRT         | `-----BEGIN  CERTIFICATE-----XXXXXXX-----END CERTIFICATE-----` |
| `extra_location`                          | region            | `eastus2` |
| `extra_platform_name`                     | logical platform_name | `myPlatform` |
| `extra_platform_tags`                     | logical platform_tags | `environment=DMO platform=Inbound project=CloudBuilderf5` |
| `extra_subnet_mgt_on_premise`             | Tower subnet      | `10.0.0.0/24` |
| `extra_vm_size`                           | VM type           | `Standard_DS1_v2` |
| `infra_admin_username`                    | Admin username    | `plop` |
| `extra_subnet_mgt_dataplane`              | Consul subnet     | `10.100.0.0/24` |

# data-group playbooks
## Job Templates
Create and launch a job template that include each of those playbooks:

| Job template  | playbook      | activity      | inventory     | limit         | credential   |
| ------------- | ------------- | ------------- | ------------- | ------------- |------------- |
| `poc-f5_sslo-subscription_create`             | `playbooks/poc-f5.yaml`       | `sslo-subscription_create`            | `localhost`  | `localhost` | none |
| `poc-f5_sslo-data_group-add_url`              | `playbooks/poc-f5.yaml`       | `sslo-data_group-add_url`             | `localhost`  | `localhost` | none |
| `poc-f5_sslo-data_group-remove_url`           | `playbooks/poc-f5.yaml`       | `sslo-data_group-remove_url`          | `localhost`  | `localhost` | none |
| `poc-f5_sslo-subscription_delete`             | `playbooks/poc-f5.yaml`       | `sslo-subscription_delete`            | `localhost`  | `localhost` | none |

## Survey
A survey is the change form, i.e. an INPUT form for extra variables requested to end user.

| Job template  | extra variable|
| ------------- | ------------- |
| `poc-f5_sslo-subscription_create`             | `extra_subscription_name`, `extra_service_account`     |
| `poc-f5_sslo-data_group-add_url`              | `extra_subscription_name`, `extra_allow_urls`       |
| `poc-f5_sslo-data_group-remove_url`           | `extra_subscription_name`, `extra_allow_urls`       |
| `poc-f5_sslo-subscription_delete`             | `extra_subscription_name`       |

## Extra variables

| Extra variable| Description | Example of value      |
| ------------- | ------------- | ------------- |
| `activity`                        | Refer to Job template above definition | `url_category-add_url` |
| `extra_admin_user`                | BIG IP admin username | `admin` |
| `extra_admin_password`            | BIG-IP admin password | `Ch4ngeMe!` |
| `extra_ip_mgt`                    | BIG-IP management IP | `10.228.234.11` |
| `extra_port_mgt`                  | BIG-IP management IP | `443` |
| `extra_consul_path_source_of_truth`   | Consul Source of Truth path | `poc_f5/outbound/sslo/subscriptions` |
| `extra_consul_agent_scheme`       | Consul scheme access | `http` |
| `extra_consul_agent_ip`           | Consul agent "client" IP to use | `10.100.0.60` |
| `extra_consul_agent_port`         | Consul agent "client" port to use | `8500` |
| `extra_consul_datacenter`         | Consul DC to store key/value | `pop` |

# URL Category playbooks
## Job Templates
Create and launch a job template that include each of those playbooks:

| Job template  | playbook      | activity      | inventory     | limit         | credential   |
| ------------- | ------------- | ------------- | ------------- | ------------- |------------- |
| `poc-f5_url_category-add_url`             | `playbooks/poc-f5.yaml`       | `url_category-add_url`            | `localhost`  | `localhost` | none |
| `poc-f5_url_category-remove_url`          | `playbooks/poc-f5.yaml`       | `url_category-remove_url`         | `localhost`  | `localhost` | none |
| `poc-f5_url_category-rollback_category`   | `playbooks/poc-f5.yaml`       | `url_category-rollback_category`  | `localhost`   | `localhost` | none |

## Extra variables

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
