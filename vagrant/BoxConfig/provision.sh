#!/usr/bin/env bash
# Script settings
# ---------------
host=`hostname`
controlplane='^cp-[0-9]+$'
workernode='^wn-[0-9]+$'

# Install Kubernetes
# ----------------------------
echo ">>>>>>>>>>>>>>>>>>>>>>>>>> Update the system <<<<"
apt-get update
apt-get install -y apache2
apt-get install vim


if [[ $host =~ $controlplane ]]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> Control plane: $host <<<<"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> INSTALL CRI-O <<<<"
	modprobe overlay
	modprobe br_netfilter
	install -m 600 -o root -g root -p /vagrant/BoxConfig/cri-o/99-kubernetes-cri.conf /etc/sysctl.d/99-kubernetes-cri.conf
	sysctl --system
	export OS=xUbuntu_20.04
	export VER=1.22
	export WEBSITE=http://download.opensuse.org
	echo \
		"deb $WEBSITE/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VER/$OS/ /" \
		| tee -a /etc/apt/sources.list.d/cri-O.list
	curl -L \
		$WEBSITE/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VER/$OS/Release.key \
		| apt-key add -
	echo \
		"deb $WEBSITE/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" \
		| tee -a /etc/apt/sources.list.d/libcontainers.list
	curl \
		-L $WEBSITE/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key \
		| apt-key add -
	apt-get update
	apt-get install -y cri-o cri-o-runc
	systemctl daemon-reload; systemctl enable crio; systemctl start crio; systemctl status
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> INSTALL Kubernetes <<<<"
	install -m 600 -o root -g root -p /vagrant/BoxConfig/cri-o/kubernetes.list /etc/apt/sources.list.d/kubernetes.list
	curl -s \
		https://packages.cloud.google.com/apt/doc/apt-key.gpg \
		| apt-key add -
	apt-get update
	apt-get install -y kubeadm=1.22.1-00 kubelet=1.22.1-00 kubectl=1.22.1-00
	apt-get install bash-completion -y
	echo "source <(kubectl completion bash)" >> $HOME/.bashrc
	apt-mark hold kubelet kubeadm kubectl

	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> INIT Control Plane <<<<"
	install -m 600 -o root -g root -p /vagrant/BoxConfig/cri-o/kubeadm-crio.yaml /root/kubeadm-crio.yaml
	sudo kubeadm init --config=/root/kubeadm-crio.yaml --upload-certs | tee kubeadm-init.out

	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> INSTALL CNI <<<<"
	echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  Whoami? $(whoami)m Where am i? $(pwd) >>>>>>>>>>>>><"
	export USERHOME="/home/vagrant"
	mkdir $USERHOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $USERHOME/.kube/config
	sudo chown vagrant:vagrant $USERHOME/.kube/config
	install -m 600 -o vagrant -g vagrant -p /vagrant/BoxConfig/CNI/calico.yaml $USERHOME/calico.yaml
	sudo -u vagrant kubectl apply -f $USERHOME/calico.yaml
	sudo kubeadm config print init-defaults

elif [[ $host =~ $workernode ]]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> Worker node: $host <<<<"
else
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> Unknown Node type $host <<<<"
fi