# Vagrant Kubernetes Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Vagrant](https://img.shields.io/badge/vagrant-%231563FF.svg?style=for-the-badge&logo=vagrant&logoColor=white)](https://www.vagrantup.com/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)

This project sets up a local Kubernetes cluster using Vagrant and VirtualBox. It creates two Ubuntu 24.04 virtual machines: one control plane node and one worker node with automatic installation of Docker, Kubernetes components, and necessary configurations.

## Local (Host) Scripts

🛠 These scripts are designed to run ON the local host and speak TO the Control Plane or Worker Nodes

<table>
<tr>
    <td valign="top">⚙️&nbsp;mgmt_copy_kubecfg.sh</td>
    <td>
        Copy the "${HOME}/.kube/config" file from the Control Plane into
        the ${HOME} directory of the host user.</br></br>RUN THIS SCRIPT FIRST
    </td>
</tr>
<tr>
    <td valign="top">🛠&nbsp;mgmt_worker_join.sh </td>
    <td>Once the Control Plane is running, use this script to join each of the workers to the Cluster</td>
</tr>
<tr>
    <td valign="top">✨&nbsp;mgmt_kube_state.sh</td>
    <td>
        Simple script to show the up/down state of the Cluster, and the state 
        of each of the nodes.</br></br>Will need the 'mgmt_copy_kubecfg.sh' script first
    </td>
</tr>
</table>

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2024 Vagrant Kubernetes Cluster

## 📫 Support & Contribution

If you encounter any issues or need assistance:

[![Create Issue](https://img.shields.io/badge/Create-Issue-green.svg)](https://github.com/yourusername/vagrant-kubernetes/issues/new)
[![Pull Request](https://img.shields.io/badge/Pull-Request-blue.svg)](https://github.com/yourusername/vagrant-kubernetes/pulls)

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
Made with ❤️ for the Kubernetes community
</div>
