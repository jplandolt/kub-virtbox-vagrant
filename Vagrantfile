#
# vagrant up
# vagrant destroy [-f]
#

# Configuration parameters
VAGRANT_BASE_OS = "bento/ubuntu-24.04"
PRIVATE_NETWORK = "private_network"    # For Host -> VM and VM <-> VM (within the network)

# Create list of one or more Control Plane Nodes (but one is sufficient)
CPLANE_NODES = [
  { name: "cplane",  box: VAGRANT_BASE_OS, network: PRIVATE_NETWORK, ip: "192.168.63.11" }
]

# Create list of one or more worker nodes
# Mindful of the 'name' and 'ip' values for each
WORKER_NODES = [
  { name: "worker1", box: VAGRANT_BASE_OS, network: PRIVATE_NETWORK, ip: "192.168.63.12" }
#  { name: "worker1", box: VAGRANT_BASE_OS, network: PRIVATE_NETWORK, ip: "192.168.63.12" },
#  { name: "worker2", box: VAGRANT_BASE_OS, network: PRIVATE_NETWORK, ip: "192.168.63.13" }
]

# Work out the "/etc/hosts" values to be copied in each node (cplanes and workers)
ALL_NODES = CPLANE_NODES + WORKER_NODES
ETC_HOSTS = ALL_NODES.map { |n| "#{n[:ip]} #{n[:name]}" }.join("\n") + "\n"

#
# Wrap the Vagrant configure up in an "if" clause which allows for
# both the expected processing of the Vagrantfile via "vagrant",
# and running of functions (below) with ruby
#
if defined?(Vagrant)
  Vagrant.configure("2") do |config|
    # Define Control Plane Nodes
    CPLANE_NODES.each do |node|
      config.vm.box_download_insecure = true
      config.vm.define node[:name] do |cplane|
        cplane.vm.box = node[:box]
        cplane.vm.network node[:network], ip: node[:ip]

        cplane.vm.hostname = node[:name]
        cplane.vm.provider "virtualbox" do |v|
          v.name = node[:name]
          v.memory = 2048
          v.cpus = 2
        end
        cplane.vm.provision "shell",
          env: { "ETC_HOSTS" => ETC_HOSTS },
          inline: <<-SHELL
            # Provision the Control Plane (Base and Specific)
            /vagrant/scripts/provision/provision_base.sh
            [ -f "/vagrant/scripts/provision/provision_cplane.sh" ] && /vagrant/scripts/provision/provision_cplane.sh

            cp -f /vagrant/scripts/cplane/*.sh . 2>/dev/null || true
          SHELL
      end
    end

    # Define Worker Nodes
    WORKER_NODES.each do |node|
      config.vm.box_download_insecure = true
      config.vm.define node[:name] do |worker|
        worker.vm.box = node[:box]
        worker.vm.network node[:network], ip: node[:ip]
        worker.vm.hostname = node[:name]
        worker.vm.provider "virtualbox" do |v|
          v.name = node[:name]
          v.memory = 2048
          v.cpus = 2
        end
        worker.vm.provision "shell",
          env: {"ETC_HOSTS" => ETC_HOSTS},
          inline: <<-SHELL
            # Provision the Worker (Base and Specific)
            /vagrant/scripts/provision/provision_base.sh
            [ -f "/vagrant/scripts/provision/provision_worker.sh" ] && /vagrant/scripts/provision/provision_worker.sh

            cp -f /vagrant/scripts/worker/*.sh . 2>/dev/null || true
          SHELL
      end
    end
  end
else
  #
  # Ruby Functions supporting Cluster management from Bash Scripts
  # Based upon the Vagrantfile *_NODES lists
  #
  def list_names(nodes);  nodes.map { |n| "#{n[:name]}" }; end
  def list_ips(nodes);    nodes.map { |n| "#{n[:ip]}" }; end
  def list_nameip(nodes); nodes.map { |n| "#{n[:name].ljust(10)} #{n[:ip]}" }; end

  # Select List (Control Plane, Worker, or All) from Param
  case ARGV[1] ? ARGV[1].downcase : nil
    when "cplane" then nodelist = CPLANE_NODES
    when "worker" then nodelist = WORKER_NODES
  else
    nodelist = ALL_NODES
  end

  # Command-line mode
  case ARGV[0] ? ARGV[0].downcase : nil
    when "list_names"  then puts list_names(nodelist)
    when "list_ips"    then puts list_ips(nodelist)
    when "list_nameip" then puts list_nameip(nodelist)
  else
    warn "Usage: ruby Vagrantfile [ list_names | list_ips | list_nameip ]"
  end
end
