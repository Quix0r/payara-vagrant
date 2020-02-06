# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
   config.vm.box = "ubuntu/trusty64"
   
   config.vm.provider "virtualbox" do |vb|
     vb.memory = "4096"
   end
   
   config.vm.provision "shell", path: "provision.sh"
   config.vm.network :forwarded_port, guest: 3700, host: 13700   # IIOP ORB
   config.vm.network :forwarded_port, guest: 3820, host: 13820   # IIOP SSL
   config.vm.network :forwarded_port, guest: 3920, host: 13920   # IIOP SSL mutual auth
   config.vm.network :forwarded_port, guest: 4848, host: 14848   # Admin listener
   config.vm.network :forwarded_port, guest: 5900, host: 15900   # Hazelcast
   config.vm.network :forwarded_port, guest: 7676, host: 17676   # JMS
   config.vm.network :forwarded_port, guest: 8080, host: 18080   # HTTP
   config.vm.network :forwarded_port, guest: 8181, host: 18181   # HTTPS
   config.vm.network :forwarded_port, guest: 8686, host: 18686   # JMX
   config.vm.network :forwarded_port, guest: 9009, host: 19009   # JVM debug

end
