	sudo mkdir --parents /etc/consul.d
	sudo touch /etc/consul.d/server.hcl
	sudo chown --recursive consul:consul /etc/consul.d
	sudo chmod 640 /etc/consul.d/server.hcl
