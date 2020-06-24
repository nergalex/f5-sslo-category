	export CONSUL_VERSION="1.8.0"
	curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
	curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS
	curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig
	unzip consul_${CONSUL_VERSION}_linux_amd64.zip
	sudo chown root:root consul
	sudo mv consul /usr/bin/
	consul --version
	consul -autocomplete-install
	complete -C /usr/bin/consul consul
	sudo useradd --system --home /etc/consul.d --shell /bin/false consul
	sudo mkdir --parents /opt/consul
	sudo chown --recursive consul:consul /opt/consul
	sudo touch /etc/systemd/system/consul.service
