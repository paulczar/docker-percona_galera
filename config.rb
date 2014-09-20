# coreos-vagrant is configured through a series of configuration
# options (global ruby variables) which are detailed below. To modify
# these options, first copy this file to "config.rb". Then simply
# uncomment the necessary lines, leaving the $, and replace everything
# after the equals sign..

# Size of the CoreOS cluster created by Vagrant
$num_instances=3

# Developer mode?

# Log the serial consoles of CoreOS VMs to log/
# Enable by setting value to true, disable with false
# WARNING: Serial logging is known to result in extremely high CPU usage with
# VirtualBox, so should only be used in debugging situations
#$enable_serial_logging=false

# Enable port forwarding of Docker TCP socket
# Set to the TCP port you want exposed on the *host* machine, default is 4243
# If 4243 is used, Vagrant will auto-increment (e.g. in the case of $num_instances > 1)
# You can then use the docker tool locally by setting the folloing env var:
#   export DOCKER_HOST='tcp://127.0.0.1:4243'
$expose_docker_tcp=4243

# Setting for VirtualBox VMs
#$vb_gui = false
$vb_memory = 1024
$vb_cpus = 1

# enable port forwarding of etcd
$expose_etcd_tcp=4001

def write_user_data(num_instances)
    require 'erb'
    require 'net/http'
    require 'uri'
    if $num_instances == 1
      @etcd_discovery = '# single node no discovery needed.'
    else
      @etcd_discovery = "discovery: #{Net::HTTP.get(URI.parse('http://discovery.etcd.io/new'))}"
    end
    if ENV['dev']
        @command = 'stop'
        @debug = 1
    else
        @command = 'start'
        @debug = 0
    end
    template = File.join(File.dirname(__FILE__), 'user-data.erb')
    target = File.join(File.dirname(__FILE__), 'user-data')
    content = ERB.new File.new(template).read
    File.open(target, 'w') { |f| f.write(content.result(binding)) }
end
