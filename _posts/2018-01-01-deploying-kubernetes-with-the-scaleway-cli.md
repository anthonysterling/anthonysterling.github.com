---
layout: post
title: Deploying Kubernetes with the Scaleway CLI
date: 2018-01-01
tags: [Kubernetes, Scaleway, kubeadm, scw]
---

Following my [Using kubeadm to deploy Kubernetes to Scaleway]({% post_url 2017-12-31-using-kubeadm-to-deploy-kubernetes-to-scaleway %}) post, I wanted to be able to create a script to aid the Kubernetes cluster creation.

[Scaleway][2] provide a CLI tool to interact with their service called [scw][1], and the latest stable version is installable with a quick `brew install scw` to which is nice and handy.

Once `scw` was installed I authenticated with Scaleway by running `scw login` and supplying my control panel credentials.

I've posted the script I ended up with below, but I'll give you a quick run through of it.

To create the servers I ran the `scw create --bootscript="8fd15f37" --name="<name>" --commercial-type="VC1S" Ubuntu_Xenial` command. You'll notice the `--bootscript` option which allowed me to specify which bootscript to use when provisioning the instance, I obtained the correct bootscript identifier by running `scw images -f type=bootscript` and finding the `x86_64 4.10.8` script.

If you had read the previously mentioned post you would've have seen why this was important.

It would've been nice if I could use the `tag` functionality provided by the control panel UI to address instances, but this doesn't appear to be supported in an intuitive way with the CLI - so I used the `--name` option as a surrogate.

Once the servers were created I then needed to be started, to do this I ran `scw start --wait <identifier>` against each of the servers.

To prepare the servers I used the `scw exec <identifier> <command>` command to update and install the required packages

Once those were prepared I configured the Kubernetes master using `kubeadm`, and obtained a join token to use on the nodes - the `token create --print-join-command` functionality was introduced in 1.9 and it very handy.

Strangely, when I tried to use the output of `scw exec -w "$master" 'kubeadm token create --print-join-command'` directly I get an error from `kubeadm` on the node stating `couldn't validate the identity of the API Server: encoding/hex: odd length hex string`. After piping the content into `xxd`, I noticed that the string ended in an `\r\n` pair so I removed this with `tr`.

I need to investigate whether this was expected functionality or introduced by accident in either `scw` or `kubeadm`.

Finally, to destroy the cluster, I issued the `scw stop -t <identifier>` command which terminated the server and destroys attached resources.

{% highlight bash linenos %}
#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

test -z "${DEBUG:-}" || {
    set -x
}

function log {
    local now=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$now] $1"
}

function create_server {
    scw create --bootscript="8fd15f37" --name="$1" --commercial-type="VC1S" Ubuntu_Xenial
}

function create_and_start_server {
    scw start --wait $(create_server "$1")
}

function delete_server {
    scw stop -t "$1"
}

case "${1:-}" in
    create)
        log "Creating k8s-master"
        create_and_start_server "k8s-master"

        for idx in $(seq 1 3); do
            log "Creating k8s-node-$idx"
            create_and_start_server "k8s-node-$idx"
        done
    ;;
    install)
        for server in $(scw ps | grep "k8s" | awk '{ print $1 }'); do
            log  "Installing components on server #$server"
            scw exec -w $server <<HEREDOC
            curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
            echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
            echo "deb https://download.docker.com/linux/ubuntu xenial stable" > /etc/apt/sources.list.d/docker-ce.list
            export DEBIAN_FRONTEND=noninteractive
            apt-get install apt-transport-https
            apt-get update -yq --fix-missing && apt-get dist-upgrade -yq
            apt-get install -yq docker-ce=17.03.0~ce-0~ubuntu-xenial kubelet kubeadm kubectl kubernetes-cni
            apt-mark hold docker-ce
HEREDOC
        done;
    ;;
    configure)
        log "Configuring master"
        master=$(scw ps | grep "k8s-master" | awk '{ print $1 }')
        scw exec "$master" 'kubeadm init --pod-network-cidr=192.168.0.0/16'

        log "Installing Calico Pod Network on master"
        scw exec "$master" 'kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml'

        log "Getting node join token"
        token=$(scw exec -w "$master" 'kubeadm token create --print-join-command' | tr -d '\r\n')

        for node in $(scw ps | grep "k8s-node" | awk '{ print $1 }'); do
            log "Joining node server #$node to master server #$master"
            scw exec "$node" "$token"
        done
    ;;
    destroy)
        for server in $(scw ps | grep "k8s" | awk '{ print $1 }'); do
            log  "Deleting server #$server"
            delete_server $server
        done;
    ;;
    *)
        echo "Usage: cluster {create|install|configure|destroy}" >&2
        exit 3
    ;;
esac

{% endhighlight %}

[1]: https://www.scaleway.com/
[2]: https://github.com/scaleway/scaleway-cli
