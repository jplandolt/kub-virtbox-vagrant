#!/usr/bin/env ruby

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
# Wrap the Vagrangt configure up in an "if" clause which allows for
# both the expected processing of the Vagrantfile via "vagrant",
# and running of functions (below) with ruby
#
if defined?(Vagrant)
  Vagrant.configure("2") do |config|
    # Define Control Plane Nodes
    CPLANE_NODES.each do |node|
      config.vm.define node[:name] do |cplane|
        cplane.vm.box = node[:box]
        cplane.vm.network node[:network], ip: node[:ip]
        cplane.vm.hostname = node[:name]
        cplane.vm.provider "virtualbox" do |v|
          v.name = node[:name]
          v.memory = 2048
          v.cpus = 2
        end
        cplane.vm.provision "file", source: "scripts/cplane", destination: "."
        cplane.vm.provision "shell",
          env: { "ETC_HOSTS" => ETC_HOSTS },
          inline: <<-SHELL
          # Add Nodes to /etc/hosts
          sudo echo "# Added by Vagrant" >> /etc/hosts
          sudo echo "#" >> /etc/hosts
          echo -e "${ETC_HOSTS}" | while read -r hline; do
            sudo echo ${hline} >> /etc/hosts
          done

          # Apt Stuff for Docker Install
          sudo apt update
          sudo apt install ca-certificates curl
          sudo install -m 0755 -d /etc/apt/keyrings
          sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
          sudo chmod a+r /etc/apt/keyrings/docker.asc

          # Install Docker and ContainerD as the container manamgment tool
          # Add the repository to Apt sources:
          echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
          sudo apt update
          sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
          sudo systemctl enable docker
          sudo ufw disable
          sudo swapoff -a
          sudo apt update && sudo apt install -y apt-transport-https
          curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
          sudo apt update

          # Install Helm Deployment Manager
          # apt-transport-https may be a dummy package; if so, you can skip that package
          sudo apt install -y apt-transport-https ca-certificates curl gpg
          curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
          echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
          sudo apt update
          sudo apt install -y helm

          # Install the main Kubernetes components
          curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
          echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
          sudo apt update
          sudo apt install -y kubelet kubeadm kubectl
          sudo apt-mark hold kubelet kubeadm kubectl
          sudo systemctl enable --now kubelet

          # Configure Containerd Daemon
          sudo containerd config default | sudo tee /etc/containerd/config.toml
          sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml
          sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.9"|g' /etc/containerd/config.toml
          sudo systemctl restart containerd
          SHELL
      end
    end

    # Define Worker Nodes
    WORKER_NODES.each do |node|
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
          # Add Nodes to /etc/hosts
          sudo echo "# Added by Vagrant" >> /etc/hosts
          sudo echo "#" >> /etc/hosts
          echo -e "${ETC_HOSTS}" | while read -r hline; do
            sudo echo ${hline} >> /etc/hosts
          done

          # Apt Stuff for Docker Install
          sudo apt update
          sudo apt install ca-certificates curl
          sudo install -m 0755 -d /etc/apt/keyrings
          sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
          sudo chmod a+r /etc/apt/keyrings/docker.asc

          # Install Docker and ContainerD as the container manamgment tool
          # Add the repository to Apt sources:
          echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
          sudo apt update
          sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
          sudo systemctl enable docker
          sudo ufw disable
          sudo swapoff -a
          sudo apt update && sudo apt install -y apt-transport-https
          curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
          sudo apt update

          # Install the main Kubernetes components
          # apt-transport-https may be a dummy package; if so, you can skip that package
          sudo apt install -y apt-transport-https ca-certificates curl gpg
          curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
          echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
          sudo apt update
          sudo apt install -y kubelet kubeadm kubectl
          sudo apt-mark hold kubelet kubeadm kubectl
          sudo systemctl enable --now kubelet

          # Configure Containerd Daemon
          sudo containerd config default | sudo tee /etc/containerd/config.toml
          sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml
          sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.9"|g' /etc/containerd/config.toml
          sudo systemctl restart containerd
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
