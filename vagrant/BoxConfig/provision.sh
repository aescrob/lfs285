#!/usr/bin/env bash
# Script settings
# ---------------
host=`hostname`
controlplane='^cp-[0-9]+$'
apiserver="k8scp"
workernode='^wn-[0-9]+$'

create_user () {
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> create user 'k8sop' <<<<"
	export K8SUSER="k8sop"
	export K8SGROUP="k8steam"
	export USERHOME="/home/${K8SUSER}"

	sudo groupadd -g 1099 ${K8SGROUP}
	sudo useradd -s "/bin/bash" -m -g ${K8SGROUP} -u 1099 ${K8SUSER}
	install -m 550 -o root -g root -p /vagrant/BoxConfig/${K8SUSER}/sudoers /etc/sudoers.d/${K8SUSER}
	# Supplement the .bash_profile
	# cat /vagrant/BoxConfig/general/bash_profile >> /home/${K8SUSER}/.bash_profile
	# Install the ssh files
	install -m 700 -o ${K8SUSER} -g ${K8SGROUP} -d ${USERHOME}/.ssh/
	install -m 600 -o ${K8SUSER} -g ${K8SGROUP} -p /vagrant/BoxConfig/${K8SUSER}/config ${USERHOME}/.ssh/
	install -m 600 -o ${K8SUSER} -g ${K8SGROUP} -p /vagrant/BoxConfig/${K8SUSER}/authorized_keys ${USERHOME}/.ssh/
	install -m 600 -o ${K8SUSER} -g ${K8SGROUP} -p /vagrant/BoxConfig/${K8SUSER}/id_rsa ${USERHOME}/.ssh/
	install -m 600 -o ${K8SUSER} -g ${K8SGROUP} -p /vagrant/BoxConfig/${K8SUSER}/id_rsa.pub ${USERHOME}/.ssh/
}

install_CRIO () {
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
}

install_k8s_tools () {
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> INSTALL Kubernetes <<<<"
	install -m 600 -o root -g root -p /vagrant/BoxConfig/cri-o/kubernetes.list /etc/apt/sources.list.d/kubernetes.list
	curl -s \
		https://packages.cloud.google.com/apt/doc/apt-key.gpg \
		| apt-key add -
	apt-get update
	apt-get install -y kubeadm=1.22.1-00 kubelet=1.22.1-00 kubectl=1.22.1-00
	apt-get install bash-completion -y
	echo "source <(kubectl completion bash)" >> $USERHOME/.bashrc
	apt-mark hold kubelet kubeadm kubectl

}

install_cni () {
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> INSTALL CNI <<<<"
	mkdir $USERHOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $USERHOME/.kube/config
	sudo chown ${K8SUSER}:${K8SGROUP} $USERHOME/.kube/config
	install -m 600 -o ${K8SUSER} -g ${K8SGROUP} -p /vagrant/BoxConfig/CNI/calico.yaml $USERHOME/calico.yaml
	sudo -u ${K8SUSER} kubectl apply -f $USERHOME/calico.yaml
}

# MAIN
# ----------------------------
echo ">>>>>>>>>>>>>>>>>>>>>>>>>> Update the system <<<<"
apt-get update
apt-get install -y apache2
apt-get install vim

create_user


if [[ $host =~ $controlplane ]]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> Control plane: $host <<<<"
	install_CRIO
	install_k8s_tools	

	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> INIT Control Plane <<<<"
	install -m 600 -o root -g root -p /vagrant/BoxConfig/cri-o/kubeadm-crio.yaml /root/kubeadm-crio.yaml
	sudo kubeadm init --config=/root/kubeadm-crio.yaml --upload-certs | tee kubeadm-init.out

	install_cni
	
elif [[ $host =~ $workernode ]]; then
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> Worker node: $host <<<<"
	install_CRIO
	install_k8s_tools

	token=$(sudo -u ${K8SUSER} ssh k8scp "sudo kubeadm token create")
	hash=$(sudo -u ${K8SUSER} ssh k8scp "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
	sudo kubeadm join --token ${token} k8scp:6443 --discovery-token-ca-cert-hash sha256:${hash}

else
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>> Unknown Node type $host <<<<"
fi