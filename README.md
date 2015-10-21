### What is this repository for? ###

This is a minimal Foreman environment, including a discovery image, to give you a feel of the system.

### Setting up the environment ###

To setup a Foreman env, run the following:

* vagrant up chef
* vagrant up infra
* vagrant up foreman
* vagrant up client1

This will setup all satellite services such as DHCP, DNS and TFTP on the "infra" VM. Foreman itself will run on the "foreman" VM.
The VMs "client1" and "client2" are used to test the provisioning process, hence run with UI enabled.

At any stage you can run "vagrant destroy infra" or "vagrant destroy foreman" to erase any trace of these VMs and recreate them using "vagrant up" again.
You probably don't need to destroy client VMs (unless you're getting errors on partition creation) - running "vagrant reload client1" to should suffice.


### Accessing the Foreman web interface ###

First you must add the following to your /etc/hosts file:

127.0.0.1 foreman.example.com

Once you've done that and got the env up and running, point your browser to "https://foreman.example.com:9443".
The username is "admin" and the password is "password".


### Foreman and HTTPS ###

By default, foreman requires users connect via HTTPS. However, as you're using Vagrant to provision disposable hosts, once you've created a VM, destroyed it and created it again, your SSL keys will change. This will cause your browser to refuse connecting to the newly provisioned VM. To get around it, you must remove the old SSL key and restart the browser. Here are the steps to get this done in Firefox:

* Go to Firefox preferences
* Click on the "advanced" tab
* Choose the "certificates" sub-tab
* Click on "view certificates"
* Scroll till you find your server's certificate name (for example, foreman.example.com)
* Select it, click "delete", "OK" and "OK" again
* Exit preferences and FULLY QUIT the browser (on Mac, right click the Firefox icon and choose "quit")
* Relaunch Firefox and go to the foreman URL - you should be prompted to accept the new SSL cert


### Provisioning hosts ###

First, make sure you set up an "Operating System" and associate a "Template" with it. Once that's done, you're ready to go.

The first time you boot up "client1" or "client2", they will run the discovery image, and will be lised under "Hosts" -> "Discovered hosts" in the Foreman web interface.

To provision a discovered host, go into "Hosts" -> "Discovered hosts" and click on "provision" next to the host you want to provision. You will be presented with a config screen, where you'll need to enter a hostname and select the "Operating System" and "Provisioning template" you configured previously.

After a host is set to be provisioned, it will no longer appear under "Discovered hosts", and instead will show up under "Hosts" -> "All hosts".

To return a host into discoevry mode, delete it from "All hosts" and reboot it using "vagrant reload".

NOTE: The first time you provision a host, installer image files will be pulled into the TFTP server (infra node) from the repo. This could take a couple of minutes, so you may find that the first couple of times provisioning fails with a "VFS error". Wait a minute or two and retry.

