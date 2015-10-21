# -*- mode: ruby -*-
# vi: set ft=ruby :

foreman_version = "1.9"
chef_version = "11.1.7-1"

### hostnames & ips
foreman_hostname = "foreman.example.com"
foreman_ip = "172.16.16.100"
infra_hostname = "infra.example.com"
infra_ip = "172.16.16.101"
chef_hostname = "chef.example.com"
chef_ip = "172.16.16.102"

set_host = <<-EOF
  ## hostname, DNS, just get connectivity working
  if [[ `hostname` != "$1" ]];
  then
    echo "$1" > /etc/hostname
    hostname "$1"
    echo '127.0.0.1 localhost' > /etc/hosts
    echo "$2 $1" >> /etc/hosts
  fi

  ## allow passwordless ssh between machines
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  cp /vagrant/ssh/id_rsa /root/.ssh/id_rsa
  cat /vagrant/ssh/id_rsa.pub > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/*
EOF


Vagrant.configure('2') do |config|

  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  ## Foreman
  config.vm.define :foreman do |node|
    node.vm.network :private_network, ip: foreman_ip, virtualbox__intnet: 'pxe'
    node.vm.network "forwarded_port", guest: 8443, host: 8443
    node.vm.network "forwarded_port", guest: 8140, host: 8140
    node.vm.network "forwarded_port", guest: 80, host: 9080
    node.vm.network "forwarded_port", guest: 443, host: 9443
    node.vm.provider :virtualbox do |vb|
      vb.cpus = 2
    end
  
    node.vm.provision :shell do |s|
      s.inline = set_host
      s.args = "#{foreman_hostname} #{foreman_ip}"
    end
    node.vm.provision :shell, inline: <<-EOF

      apt-get update

      # install Foreman (and Puppet)
      apt-get -y install ca-certificates
      wget https://apt.puppetlabs.com/puppetlabs-release-precise.deb
      dpkg -i puppetlabs-release-precise.deb
  
      # foreman repos
      echo "deb http://deb.theforeman.org/ precise #{foreman_version}" > /etc/apt/sources.list.d/foreman.list
      echo "deb http://deb.theforeman.org/ plugins #{foreman_version}" >> /etc/apt/sources.list.d/foreman.list
      wget -q http://deb.theforeman.org/pubkey.gpg -O- | apt-key add -
      
      # ruby passenger packages - http://projects.theforeman.org/issues/11069
      apt-get -y install python-software-properties
      add-apt-repository -y ppa:brightbox/passenger-legacy

      apt-get update

      # foreman installer + discovery plugin for hammer
      apt-get -y install foreman-installer ruby-hammer-cli-foreman-discovery
  
      # enable ip forwarding - we're the router
      egrep '^net.ipv4.ip_forward' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
      sysctl -p
      echo > /etc/rc.local <<< echo '#!/bin/sh -e'
      echo >> /etc/rc.local <<< echo '/sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE'
      echo >> /etc/rc.local <<< echo '/sbin/iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT'
      echo >> /etc/rc.local <<< echo '/sbin/iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT'
      bash /etc/rc.local

      # run the foreman installer
      foreman-installer -v \
        --no-enable-foreman-proxy \
        --enable-foreman-plugin-discovery \
        --foreman-passenger-prestart='true' \
        --foreman-admin-password='password'

      # copy chef validation key
      ping -c 1 #{chef_ip}
      if [ $? -eq 0 ]
      then
        scp -o StrictHostKeyChecking=no #{chef_ip}:/etc/chef-server/chef-validator.pem /var/www/validation.pem
        chmod 755 /var/www/validation.pem
      fi

      # allow http access to /var/www at port 81
      sed -i 's?:80?:81?g' /etc/apache2/sites-available/15-default.conf
      echo "Listen 81" >> /etc/apache2/sites-available/15-default.conf
      service apache2 restart

      # configure some basic params in foreman
      /vagrant/configure.rb
    EOF
  end

  ## Infra
  config.vm.define :infra do |node|
    node.vm.network :private_network, ip: infra_ip, virtualbox__intnet: 'pxe'
    node.vm.provider :virtualbox do |vb|
      vb.cpus = 2
      vb.customize ['modifyvm', :id, '--nicpromisc2', 'allow-vms']
    end
  
    node.vm.provision :shell do |s|
      s.inline = set_host
      s.args = "#{infra_hostname} #{infra_ip}"
    end
    node.vm.provision :shell, inline: <<-EOF

      # copy chef validation key
      mkdir -p /etc/chef
      ping -c 1 #{chef_ip}
      if [ $? -eq 0 ]
      then
        scp -o StrictHostKeyChecking=no #{chef_ip}:/etc/chef-server/admin.pem /etc/chef/
      fi

      # needed by foreman-installer
      apt-get -y install ca-certificates
      wget https://apt.puppetlabs.com/puppetlabs-release-precise.deb
      dpkg -i puppetlabs-release-precise.deb

      # foreman repos
      echo "deb http://deb.theforeman.org/ precise #{foreman_version}" > /etc/apt/sources.list.d/foreman.list
      echo "deb http://deb.theforeman.org/ plugins #{foreman_version}" >> /etc/apt/sources.list.d/foreman.list
      wget -q http://deb.theforeman.org/pubkey.gpg -O- | apt-key add -

      apt-get update

      # infra services
      apt-get -y install bind9 isc-dhcp-server tftpd-hpa syslinux
      # foreman proxy
      apt-get -y install foreman-installer foreman-proxy ruby-smart-proxy-discovery ruby-smart-proxy-chef

      # ruby 1.9 for smart_proxy_chef
      apt-get -y install ruby1.9 ruby-odbc ruby-odbc-dbg
      update-alternatives --set ruby /usr/bin/ruby1.9.1

      # dhcpd config (for this Vagrantfile)
      cp /vagrant/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf
      touch /etc/dhcp/dhcpd.hosts

      # syslinux for pxe boot
      cp /usr/lib/syslinux/chain.c32 /var/lib/tftpboot/
      cp /usr/lib/syslinux/menu.c32 /var/lib/tftpboot/
      cp /usr/lib/syslinux/pxelinux.0 /var/lib/tftpboot/
      cp /usr/lib/syslinux/memdisk /var/lib/tftpboot/

      # foreman discovery image + default pxelinux template
      mkdir /var/lib/tftpboot/boot /var/lib/tftpboot/pxelinux.cfg
      wget http://downloads.theforeman.org/discovery/releases/latest/fdi-image-latest.tar \
        -O - | tar x --overwrite -C /var/lib/tftpboot/boot
      cp -a /vagrant/tftpboot/pxelinux.cfg /var/lib/tftpboot

      # ensure foreman-proxy has permissions to modify tftpboot
      chown -R foreman-proxy /var/lib/tftpboot

      # foreman proxy configs
      cp -r /vagrant/foreman-proxy/* /etc/foreman-proxy/

      # dns config
      cp -a /vagrant/dns/* /
      chown -R bind.root /etc/bind
      chown -R bind.root /var/cache/bind
      chmod o+r /etc/bind/rndc.key

      # chef proxy config
      echo -e "---\n:enabled: true\n:chef_authenticate_nodes: true\n:chef_server_url: 'https://#{chef_ip}'\n:chef_smartproxy_clientname: 'admin'\n:chef_smartproxy_privatekey: '/etc/chef/admin.pem'\n:chef_ssl_verify: false" > /etc/foreman-proxy/settings.d/chef.yml

      chown -R foreman-proxy /etc/chef/

      service bind9 restart
      service tftpd-hpa restart
      service isc-dhcp-server start
      service foreman-proxy restart
    EOF
  end

  ## Chef server
  config.vm.define :chef do |node|
    node.vm.network :private_network, ip: chef_ip, virtualbox__intnet: 'pxe'
  
    node.vm.provision :shell do |s|
      s.inline = set_host
      s.args = "#{chef_hostname} #{chef_ip}"
    end
    node.vm.provision :shell, inline: <<-EOF

      # download & install chef server
      wget https://web-dl.packagecloud.io/chef/stable/packages/ubuntu/precise/chef-server_#{chef_version}_amd64.deb -O /tmp/chef-server_#{chef_version}_amd64.deb
      dpkg -i /tmp/chef-server_#{chef_version}_amd64.deb
      chef-server-ctl reconfigure

      # download ohai cookbook & upload to sever
      apt-get install -y git
      git clone https://github.com/chef-cookbooks/ohai.git
      cat <<<'
        node_name "admin"
        client_key "/etc/chef-server/admin.pem"
        chef_server_url "https://localhost"
      '>/etc/chef/knife.rb
      /opt/chef-server/embedded/bin/knife cookbook upload ohai -o . -c /etc/chef/knife.rb
    EOF
  end

  ## Client 1
  config.vm.define :client1, autostart: false do |node|
    node.vm.network :private_network, type: 'dhcp', virtualbox__intnet: 'pxe'

    node.vm.provider :virtualbox do |vb|
      vb.cpus = 2
      vb.memory = 1024
      vb.customize ['modifyvm', :id, '--boot1', 'net']
      vb.customize ['modifyvm', :id, '--boot2', 'disk']
      vb.customize ['modifyvm', :id, '--nicpromisc2', 'allow-vms']
      vb.customize ['modifyvm', :id, '--nic1', 'none']
      vb.customize ['modifyvm', :id, '--macaddress2', '080027BA2DAE']
      vb.gui = true
    end
  end

  ## Client 2
  config.vm.define :client2, autostart: false do |node|
    node.vm.network :private_network, type: 'dhcp', virtualbox__intnet: 'pxe'

    node.vm.provider :virtualbox do |vb|
      vb.cpus = 2
      vb.customize ['modifyvm', :id, '--boot1', 'net']
      vb.customize ['modifyvm', :id, '--boot2', 'disk']
      vb.customize ['modifyvm', :id, '--nicpromisc2', 'allow-vms']
      vb.customize ['modifyvm', :id, '--nic1', 'none']
      vb.customize ['modifyvm', :id, '--macaddress2', '080027BA2DCA']
      vb.gui = true
    end
  end

end
