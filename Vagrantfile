# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'

CLOUD_CONFIG_PATH = './user-data'
CONFIG = 'config.rb'

# Defaults for config options defined in CONFIG
$num_instances = 1
$enable_serial_logging = false
$vb_gui = false
$vb_memory = 512
$vb_cpus = 1

# Attempt to apply the deprecated environment variable NUM_INSTANCES to
# $num_instances while allowing config.rb to override it
if ENV['NUM_INSTANCES'].to_i > 0 && ENV['NUM_INSTANCES']
  $num_instances = ENV['NUM_INSTANCES'].to_i
end

require_relative CONFIG if File.exist?(CONFIG)

if ARGV.include? 'up'
  puts 'rewriting userdata'
  write_user_data($num_instances)
end

Vagrant.configure('2') do |config|
  config.vm.box = 'coreos-beta'
  config.vm.box_version = '>= 308.0.1'
  config.vm.box_url = 'http://storage.core-os.net/coreos/amd64-usr/beta/coreos_production_vagrant.json'

  config.vm.provider :vmware_fusion do |_, override|
    override.vm.box_url = 'http://storage.core-os.net/coreos/amd64-usr/beta/coreos_production_vagrant_vmware_fusion.json'
  end

  # plugin conflict
  config.vbguest.auto_update = false if Vagrant.has_plugin?('vagrant-vbguest')

  (1..$num_instances).each do |i|
    config.vm.define vm_name = format('core-%02d', i) do |c|
      c.vm.hostname = vm_name

      if $enable_serial_logging
        logdir = File.join(File.dirname(__FILE__), 'log')
        FileUtils.mkdir_p(logdir)

        serial_file = File.join(logdir, format('%s-serial.txt', vm_name))
        FileUtils.touch(serial_file)

        c.vm.provider :vmware_fusion do |v, _|
          v.vmx['serial0.present'] = 'TRUE'
          v.vmx['serial0.fileType'] = 'file'
          v.vmx['serial0.fileName'] = serialFile
          v.vmx['serial0.tryNoRxLoss'] = 'FALSE'
        end

        c.vm.provider :virtualbox do |vb, _|
          vb.customize ['modifyvm', :id, '--uart1', '0x3F8', '4']
          vb.customize ['modifyvm', :id, '--uartmode1', serialFile]
        end
      end

      if $expose_docker_tcp
        c.vm.network 'forwarded_port', guest: 4243, host: $expose_docker_tcp, auto_correct: true
        c.vm.network 'forwarded_port', guest: 4001, host: $expose_etcd_tcp, auto_correct: true
        c.vm.network 'forwarded_port', guest: 3306, host: 3306, auto_correct: true
      end

      c.vm.provider :virtualbox do |vb|
        vb.gui = $vb_gui
        vb.memory = $vb_memory
        vb.cpus = $vb_cpus
      end

      ip = "172.17.8.#{i + 100}"
      c.vm.network :private_network, ip: ip

      if ENV['dev']
        c.vm.synced_folder '.', '/home/core/share', id: 'core', nfs: true, mount_options: ['nolock,vers=3,udp']
      end

      if File.exist?(CLOUD_CONFIG_PATH)
        c.vm.provision :file, source: "#{CLOUD_CONFIG_PATH}", destination: '/tmp/vagrantfile-user-data'
        c.vm.provision :shell, inline: 'mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/', privileged: true

      end

      if ENV['dev']
        c.vm.provision :shell, inline: 'docker build -t paulczar/percona-galera /home/core/share'
      end
    end
  end
end
