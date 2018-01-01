---
layout: post
title: Using kubeadm to deploy Kubernetes to Scaleway
date: 2017-12-31
tags: [Kubernetes, Scaleway, kubeadm]
---

I've seen [Scaleway][1] mentioned a few times on Twitter, mainly surrounding their cheap ARM64 hosting, so I thought I'd use the festive break to check them out and tinker with the latest version of [kubeadm][2].

They've got some excellent [pricing][3] for their X86-64 instances too, for €2.99 per month you can get 2 cores, 2GB of RAM, and a local 50GB SSD which means for €11.96 (~£10.60) per month I could launch a X86-64 [Kubernetes][4] cluster (1 master and 3 nodes) with 8GB of RAM, 8 cores, and 150GB of storage to play with.

This post is not meant the be a replacement for the [official documentation][5] for installing Kubernetes with `kubeadm`, but more a log of the steps I took and the issue(s) I encountered along the way.

So here we go...

I registered for a Scaleway account, provided some credit card details, and headed on over to the control panel. Before creating the servers I added an SSH key in the credentials section of my profile, once that was done I created four Ubuntu 16.04 LTS (Xenial) instances with the default settings and this is where I hit an issue.

The default [Scaleway bootscript][6] for the Ubuntu 16.04 LTS (Xenial) instance uses `x86_64 4.4.105` which doesn't have the `xt_set` Kernel module enabled, and this module is required for pod networking later on. So if, like I did, you manage to reach this point you'll find some odd `iptables` related errors that incurred some head scratching.

Thankfully, Scaleway have enabled this module in their `x86_64 4.10.8` bootscript, you can edit the server in the control panel and select this then reboot the server. You can check if the module is enabled with `zcat /proc/config.gz | grep XT_S` which should return `CONFIG_NETFILTER_XT_SET=y` or `CONFIG_NETFILTER_XT_SET=m` - sadly you cannot select this bootscript in the the control panel when creating a server so there's a bit of messing about to be done.

Once the servers were created (with the correct bootscript!) I SSH'd in to each server and ran the following commands:-

{% highlight bash linenos %}
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo "deb https://download.docker.com/linux/ubuntu xenial stable" > /etc/apt/sources.list.d/docker-ce.list

export DEBIAN_FRONTEND=noninteractive
apt-get install apt-transport-https
apt-get update -yq --fix-missing && apt-get dist-upgrade -yq
apt-get install -yq docker-ce=17.03.0~ce-0~ubuntu-xenial kubelet kubeadm kubectl kubernetes-cni
apt-mark hold docker-ce
{% endhighlight %}

These commands install the Kubernetes and Docker repositories, update the base system, then installs the `kubelet`, `kubeadm`, `kubectl`, `kubernetes-cni`, and `docker-ce` packages. [Officially][7], Kubernetes only supports Docker `17.03` so I installed the `17.03.0~ce-0~ubuntu-xenial` version supplied by the repository and used `apt-mark hold` to prevent any updates/upgrades from automatically upgrading the `docker-ce` package without manual intervention.

Once each server was updated and had all the required packages installed, I SSH'd in to the server which I was going to be the Kubernetes master. Once in, I ran `kubeadm init --pod-network-cidr=192.168.0.0/16` to bring up Kubernetes. I used the `--pod-network-cidr=192.168.0.0/16` option as I wanted to use [Calico][8] for pod networking and the documentation required this option.

You can see the steps `kubeadm` makes when invoking `init` in [Lucas Käldström][9]'s excellent ["kubeadm Cluster Creation Internals: From Self-Hosting to Upgradability and HA"][10] presentation.

`kubedm` completed and provided me with some instructions to configure `kubectl`, and a command to run on each of the other servers to add them to this cluster, it was somewhat similar to the following:-

{% highlight bash linenos %}
Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join --token 602414.e8ab1c628aecea66 10.4.123.75:6443 --discovery-token-ca-cert-hash sha256:df302c574bf82a6feb9b43f70d12cb323c661585f6fa59b10a9b78f0f035c67c
{% endhighlight %}

Before running the join command on the other servers I installed the Calico pod network by executing the following command on the master:-

{% highlight bash linenos %}
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml
{% endhighlight %}

I then checked the status of the `kube-system` pods by running `kubectl --kubeconfig=/etc/kubernetes/admin.conf -n kube-system get pods` and waited for all the pods to be in the running state which will look something like:-

{% highlight bash linenos %}
NAMESPACE     NAME                                      READY     STATUS    RESTARTS   AGE
kube-system   calico-etcd-sql6b                         1/1       Running   0          2m
kube-system   calico-kube-controllers-d669cc78f-6hqwk   1/1       Running   0          2m
kube-system   calico-node-j2mw4                         1/2       Running   0          46s
kube-system   calico-node-j4t9l                         2/2       Running   0          1m
kube-system   calico-node-nd4f9                         2/2       Running   0          2m
kube-system   etcd-k8s-master                           1/1       Running   0          2m
kube-system   kube-apiserver-k8s-master                 1/1       Running   0          1m
kube-system   kube-controller-manager-k8s-master        1/1       Running   0          2m
kube-system   kube-dns-6f4fd4bdf-cfptf                  3/3       Running   0          2m
kube-system   kube-proxy-fx29m                          1/1       Running   0          2m
kube-system   kube-proxy-s9mxx                          1/1       Running   0          1m
kube-system   kube-proxy-tj26q                          1/1       Running   0          46s
kube-system   kube-scheduler-k8s-master                 1/1       Running   0          2m
{% endhighlight %}

After running the `kubeadm join ...` command on each of the other servers, I SSH'd back in to the master and ran `kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes` to confirm that they had joined, and for completion that looked like:-

{% highlight bash linenos %}
NAME         STATUS    ROLES     AGE       VERSION
k8s-master   Ready     master    2m        v1.9.0
k8s-node-1   Ready     <none>    1m        v1.9.0
k8s-node-2   Ready     <none>    52s       v1.9.0
k8s-node-3   Ready     <none>    46s       v1.9.0
{% endhighlight %}

... and there we can have it, a Kubernetes cluster on Scaleway.

When picking up something new I tend to script it in some way, this helps me understand the required steps a little better and ensures that I haven't missed anything. If you're interested in how I did that, you can head on over to [Deploying Kubernetes with the Scaleway CLI]({% post_url 2018-01-01-deploying-kubernetes-with-the-scaleway-cli %}) as this post is getting a little lengthy and you could probably stop here if you're not interested.

[1]: https://www.scaleway.com/
[2]: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/
[3]: https://www.scaleway.com/pricing/
[4]: https://kubernetes.io/
[5]: https://kubernetes.io/docs/setup/independent/install-kubeadm/
[6]: http://devhub.scaleway.com/#/bootscripts
[7]: https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-docker
[8]: https://docs.projectcalico.org/v3.0/getting-started/kubernetes/
[9]: https://twitter.com/kubernetesonarm
[10]: https://docs.google.com/presentation/d/1Gp-2blk5WExI_QR59EUZdwfO2BWLJqa626mK2ej-huo/edit#slide=id.g287a267c17_0_247
