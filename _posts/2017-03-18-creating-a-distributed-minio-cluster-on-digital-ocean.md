---
layout: post
title: Creating a Distributed Minio Cluster on Digital Ocean
date: 2017-03-18
tags: [Minio, Digital Ocean, Storage]
---

If you've not heard of [Minio][1] before, Minio is an object storage server that has a Amazon S3 compatible interface. I've previously deployed the standalone version to production, but I've never used the [Distribted Minio][2] functionality [released in November 2016][3]. When Minio in distributed mode, it lets you pool multiple drives across multiple nodes into a single object storage server. As drives are distributed across several nodes, distributed Minio can withstand multiple node failures and yet ensure full data protection.

With the recent release of [Digital Ocean][4]'s [Block Storage][5] and [Load Balancer][6] functionality, I thought I'd spend a few hours attempting to set up a Distribted Minio cluster backed by Digital Ocean Block Storage behind a Load Balancer.

The plan is to provision 4 Droplets, each running an instance of Minio, and attach a unique Block Storage Volume to each Droplet which is to used as persistent storage by Minio. We'll then create a Load Balancer to Round Robin HTTP traffic across the Droplets.

I initially started to manually create the Droplets through Digitial Ocean's Web UI, but then remembered that they have a CLI tool which I may be able to use. After a quick Google I found [doctl][7] which is a command line interface for the DigitalOcean API, it's installable via [Brew][8] too which is super handy.

To use `doctl` I needed a Digital Ocean API Key, which I created via their [Web UI][9], and made sure I selected "read" and "write" scopes/permissions for it - I then installed and configured `doctl` with the following commands:-

{% highlight bash linenos %}
brew install doctl
doctl auth init
{% endhighlight %}

Once configured I confirmed that `doctl` was working by running `doctl account get` and it presented my Digital Ocean account information.

After an hour or two of provisioning and destroying Droplets, Volumes, and Load Balancers I ended up with the following script:-

{% highlight bash linenos %}
#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

function log {
    local now=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$now] $1"
}

function create_droplet {
    doctl compute droplet create "$1" --wait --size "$2" --image "$3" --region "$4" --ssh-keys "$5" --tag-names "$6"
}

function create_volume {
    doctl compute volume create "$1" --region "$2" --size "$3" --desc "Volume for $1"
}

function attach_volume_to_droplet {
    local volume=$(doctl compute volume list | grep "$1" | awk '{ print $1 }')
    local droplet=$(doctl compute droplet list | grep "$2" | awk '{ print $1 }')
    doctl compute volume-action attach "$volume" "$droplet"
}

function create_load_balancer {
    doctl compute load-balancer create --name "$1" --region "$2" --tag-name "$3" --forwarding-rules "entry_protocol:http,entry_port:80,target_protocol:http,target_port:9000"
}

function delete_droplet {
    doctl compute droplet delete --force "$1"
}

function delete_volume {
    doctl compute volume delete "$1"
}

function delete_load_balancer {
    doctl compute load-balancer delete --force "$1"
}

DROPLET_SIZE="512mb"
DROPLET_IMAGE=$(doctl compute image list | grep "16.04.2 x64" | awk '{ print $1 }')
DROPLET_REGION="fra1"
DROPLET_SSHKEY=$(doctl compute ssh-key list | grep "mail@anthonysterling.com.pub" | awk '{ print $1 }')
DROPLET_TAG="minio-cluster"
VOLUME_SIZE="100GiB"

case "$1" in
    install)

        for idx in $(seq 1 4); do

            log "Creating minio-node-$idx in $DROPLET_REGION tagged with $DROPLET_TAG"
            create_droplet "minio-node-$idx" "$DROPLET_SIZE" "$DROPLET_IMAGE" "$DROPLET_REGION" "$DROPLET_SSHKEY" "$DROPLET_TAG"
            
            log "Creating Volume for minio-node-$idx"
            create_volume "$DROPLET_TAG-volume-node-$idx" $DROPLET_REGION "$VOLUME_SIZE"
            
            log "Attaching Volume for minio-node-$idx to Droplet"
            attach_volume_to_droplet "$DROPLET_TAG-volume-node-$idx" "minio-node-$idx"

        done;

        log "Creating $DROPLET_TAG load balancer for Droplets tagged with $DROPLET_TAG"
        create_load_balancer "$DROPLET_TAG" "$DROPLET_REGION" "$DROPLET_TAG"
    ;;
    uninstall)

        log "Deleting all Droplets tagged with $DROPLET_TAG"
        for droplet in $(doctl compute droplet list | grep "$DROPLET_TAG" | awk '{ print $1 }'); do
            log "Deleting Droplet $droplet"
            delete_droplet "$droplet";
        done;

        log "Deleting all Volumes with $DROPLET_TAG in their name"
        for volume in $(doctl compute volume list | grep "$DROPLET_TAG" | awk '{ print $1 }'); do
            log "Deleting Volume $volume"
            delete_volume "$volume";
        done;

        log "Deleting all Load Balancers named $DROPLET_TAG"
        for lb in $(doctl compute load-balancer list | grep "$DROPLET_TAG" | awk '{ print $1 }'); do
            log "Deleting Load Balancer $lb"
            delete_load_balancer "$lb";
        done;
    ;;
    *)
        echo "Usage: cluster {install|uninstall}" >&2
        exit 3
    ;;
esac
{% endhighlight %}

The script creates 4 Droplets (the minimum number of nodes required by Minio) and performs the following actions to each Droplet:-

- Assigns my previously registered SSH key
- Applies a tag named `minio-cluster`
- Creates, and mounts, a unique 100GiB Volume

Once the Droplets are provisioned it then uses the `minio-cluster` tag and creates a Load Balancer that forwards HTTP traffic on port 80 to port 9000 on any Droplet with the `minio-cluster` tag. Sadly I couldn't figure out a way to configure the Heath Checks on the Load Balancer via `doctl` so I did this via the Web UI. By default the Health Check is configured to perform a HTTP request to port 80 using a path of `/`, I changed this to use port 9000 and set the path to `/minio/login`.

Once the 4 nodes were provisioned I SSH'd into each and ran the following commands to install Minio and mount the assigned Volume:-

{% highlight bash linenos %}
wget -O /usr/sbin/minio https://dl.minio.io/server/minio/release/linux-amd64/minio && chmod +x /usr/sbin/minio
mkdir -p /mnt/minio
parted /dev/disk/by-id/scsi-0DO_Volume_minio-cluster-volume-node-1 mklabel gpt
parted -a opt /dev/disk/by-id/scsi-0DO_Volume_minio-cluster-volume-node-1 mkpart primary ext4 0% 100%
mkfs.ext4 -F /dev/disk/by-id/scsi-0DO_Volume_minio-cluster-volume-node-1
echo '/dev/disk/by-id/scsi-0DO_Volume_minio-cluster-volume-node-1 /mnt/minio ext4 defaults,nofail,discard 0 2' | sudo tee -a /etc/fstab
mount -a
{% endhighlight %}

The disk name was different on each node, `scsi-0DO_Volume_minio-cluster-volume-node-1`, `scsi-0DO_Volume_minio-cluster-volume-node-2`, ,`scsi-0DO_Volume_minio-cluster-volume-node-3`, and `scsi-0DO_Volume_minio-cluster-volume-node-4` for example but the Volume mount point `/mnt/minio` was the same on all the nodes.

Next up was running the Minio server on each node, on each node I ran the following command:-

{% highlight bash linenos %}
MINIO_ACCESS_KEY=super MINIO_SECRET_KEY=doopersecret /usr/sbin/minio server http://node1/mnt/minio http://node2/mnt/minio http://node3/mnt/minio http://node4/mnt/minio
{% endhighlight %}

It's worth noting that you supply the Access Key and Secret Key in this case, when running in standalone server mode one is generated for you. The Access Key should be 5 to 20 characters in length, and the Secret Key should be 8 to 40 characters in length.

Once Minio was started I seen the following output whilst it waited for all the defined nodes to come online:-

{% highlight bash linenos %}
Created minio configuration file successfully at /root/.minio
Initializing data volume. Waiting for minimum 3 servers to come online. (elapsed 25s)
Initializing data volume. Waiting for minimum 3 servers to come online. (elapsed 38s)
Initializing data volume. Waiting for minimum 3 servers to come online. (elapsed 56s)

Endpoint:  http://node1:9000  http://node1:9000  http://127.0.0.1:9000
AccessKey: super 
SecretKey: doopersecret 
Region:    us-east-1
SQS ARNs:  <none>

Browser Access:
   http://node1:9000  http://node1:9000  http://127.0.0.1:9000

Command-line Access: https://docs.minio.io/docs/minio-client-quickstart-guide
   $ mc config host add myminio http://node1:9000 super doopersecret

Object API (Amazon S3 compatible):
   Go:         https://docs.minio.io/docs/golang-client-quickstart-guide
   Java:       https://docs.minio.io/docs/java-client-quickstart-guide
   Python:     https://docs.minio.io/docs/python-client-quickstart-guide
   JavaScript: https://docs.minio.io/docs/javascript-client-quickstart-guide

Drive Capacity: 180.0 GiB Free, 192 GiB Total
Status:         4 Online, 0 Offline. We can withstand [2] more drive failure(s).
{% endhighlight %}

Success! I visited the public IP Address on the Load Balancer and was greeted with the Minio login page when I could log in with the Access Key and Secret Key I used to start the cluster.

This was a fun little experiment, moving forward I'd like to replicate this set up in multiple regions and maybe just use DNS to Round Robin the requests as Digital Ocean only let you Load Balance to Droplets in the same region in which the Load Balancer was provisioned.

[1]: https://minio.io/
[2]: http://docs.minio.io/docs/distributed-minio-quickstart-guide
[3]: https://github.com/minio/minio/releases/tag/RELEASE.2016-11-24T02-09-08Z
[4]: https://www.digitalocean.com/
[5]: https://www.digitalocean.com/company/blog/block-storage-more-space-to-scale/
[6]: https://www.digitalocean.com/company/blog/load-balancers-simplifying-high-availability/
[7]: https://www.digitalocean.com/community/tutorials/how-to-use-doctl-the-official-digitalocean-command-line-client
[8]: https://brew.sh/
[9]: https://cloud.digitalocean.com/settings/api/tokens

