#
# Utility Functions for privisioning container hosts
#

def block_start(instance_num)
  instance_num < $num_instances ? " --no-block" : ""
end

def forward_cockpit(vm, instance_num)
  # export the ports for cockpit on each instance
  vm.network :forwarded_port, guest: 9090, host: 9090 + instance_num
end

def enable_eth1(vm)
  # bring up the private/container network
  vm.provision :shell, :name => "enable eth1",
              :inline => "ifup eth1",
              :privileged => true
end


def configure_etcd(vm, instance_num)
# resolve the etcd configuration from the template and host list
  vm.provision :shell, :name => "gen config",
               :inline => "python3 sync/transform.py sync/etcd.conf.j2 %s < sync/hosts.yml > etcd.conf" % vm.hostname

  # place the etcd configuration
  vm.provision :shell, :name => "set config",
               :inline => "cp etcd.conf /etc/etcd",
               :privileged => true

  vm.provision :shell,
               :name => "start etcd" + block_start(instance_num),
               :inline => "systemctl start etcd" + block_start(instance_num),
               :privileged => true

  vm.provision :shell,
               :name => "enable etcd",
               :inline => "systemctl enable etcd",
               :privileged => true
end

def configure_flanneld(vm, instance_num)
  vm.provision :shell, :name => "set flannel iface",
               :inline => "sed -i '$aFLANNEL_OPTIONS=\"--ip-masq=true --iface=eth1\"' /etc/sysconfig/flanneld",
               :privileged => true
      
  # Only set the flannel configuration in etcd once
  if instance_num == $num_instances then
    vm.provision :shell, :name => "set flannel cfg",
                 :inline => "etcdctl set /atomic.io/network/config \'{ \"Network\": \"172.44.0.0/16\", \"Backend\": {\"Type\": \"vxlan\"}}\'"
  end

  vm.provision :shell, :name => "flannel service" + block_start(instance_num),
               :inline => "systemctl start flanneld" + block_start(instance_num),
               :privileged => true

  vm.provision :shell,
               :name => "enable flanneld",
               :inline => "systemctl enable flanneld",
               :privileged => true

  vm.provision :shell, :name => "docker service" + block_start(instance_num),
               :inline => "systemctl restart docker" + block_start(instance_num),
               :privileged => true

  vm.provision :shell, :name => "iptables FORWARD ACCEPT",
               :inline => "iptables -P FORWARD ACCEPT",
               :privileged => true
end
