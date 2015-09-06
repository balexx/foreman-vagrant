# -*- mode: ruby -*-
# vi: set ft=ruby :


set_host = <<-EOF
  ## hostname, DNS, just get connectivity working
  if [[ `hostname` != "$1" ]];
  then
    echo "$1" > /etc/hostname
    hostname "$1"
    echo '127.0.0.1 localhost' > /etc/hosts
    echo "$2 $1" >> /etc/hosts
  fi
EOF


Vagrant.configure('2') do |config|

  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  ## Foreman
  foreman_hostname = "foreman.example.com"
  foreman_ip = "172.16.16.100"
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
      echo "deb http://deb.theforeman.org/ precise 1.8" > /etc/apt/sources.list.d/foreman.list
      echo "deb http://deb.theforeman.org/ plugins 1.8" >> /etc/apt/sources.list.d/foreman.list
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

      # configure some basic params in foreman
      /vagrant/configure.rb
    EOF
  end


  ## Infra
  infra_hostname = "infra.example.com"
  infra_ip = "172.16.16.101"
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

      # needed by foreman-installer
      apt-get -y install ca-certificates
      wget https://apt.puppetlabs.com/puppetlabs-release-precise.deb
      dpkg -i puppetlabs-release-precise.deb

      # foreman repos
      echo "deb http://deb.theforeman.org/ precise 1.8" > /etc/apt/sources.list.d/foreman.list
      echo "deb http://deb.theforeman.org/ plugins 1.8" >> /etc/apt/sources.list.d/foreman.list
      wget -q http://deb.theforeman.org/pubkey.gpg -O- | apt-key add -

      apt-get update

      # infra services
      apt-get -y install bind9 isc-dhcp-server tftpd-hpa syslinux
      # foreman proxy
      apt-get -y install foreman-installer foreman-proxy ruby-smart-proxy-discovery ruby-smart-proxy-chef

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

      service bind9 restart
      service tftpd-hpa restart
      service isc-dhcp-server start
      service foreman-proxy restart
    EOF
  end


  ## Client 1
  config.vm.define :client1, autostart: false do |node|
    node.vm.network :private_network, type: 'dhcp', virtualbox__intnet: 'pxe'

    node.vm.provider :virtualbox do |vb|
      vb.cpus = 2
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
