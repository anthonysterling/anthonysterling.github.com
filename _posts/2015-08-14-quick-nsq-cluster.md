---
layout: post
title: Quick NSQ Cluster
date: 2015-08-14
---

I've been meaning to look at [Bitly][1]'s realtime distributed messaging platform [NSQ][2] for a while now. It's written in [Go][3] so it's easy to deploy, and comes with a built-in HTTP interface for statistics, administration, and producers.

I thought I'd quickly share this Bash script to start a little NSQ cluster with 2 `nsqlookupd` hosts, 5 `nsqd` nodes, and an instance of `nsqadmin` running on port 9000.

{% highlight bash %}
#!/usr/bin/env bash
NSQ_VERSION=0.3.5
NSQ_PACKAGE="nsq-$NSQ_VERSION.linux-amd64.go1.4.2"
NSQLOOKUPD_LOG=/var/log/nsqlookupd.log
NSQD_LOG=/var/log/nsqd.log
NSQADMIN_LOG=/var/log/nsqadmin.log

wget -nc -qP /usr/src "https://s3.amazonaws.com/bitly-downloads/nsq/$NSQ_PACKAGE.tar.gz"

if [ ! -d "/opt/$NSQ_PACKAGE" ]
then
    tar -xzvf "/usr/src/$NSQ_PACKAGE.tar.gz" -C /opt/
    for FILE in "/opt/$NSQ_PACKAGE/bin/*";
    do
        ln -s $FILE /usr/local/bin/
    done
fi

for PROCESS in nsqlookupd nsqd nsqadmin;
do
    pkill "$PROCESS"
done

for NODE in {1..2};
do
    /usr/local/bin/nsqlookupd \
        -broadcast-address="nsqlookupd-0$NODE" \
        -tcp-address="127.0.0.1:900$NODE" \
        -http-address="127.0.0.1:901$NODE" >> "$NSQLOOKUPD_LOG" 2>&1 &
done

for NODE in {1..5};
do
    /usr/local/bin/nsqd \
        -broadcast-address="nsqd-0$NODE" \
        -tcp-address="127.0.0.1:903$NODE" \
        -http-address="127.0.0.1:904$NODE" \
        -lookupd-tcp-address="127.0.0.1:9001" \
        -lookupd-tcp-address="127.0.0.1:9002" >> "$NSQD_LOG" 2>&1 &
done

/usr/local/bin/nsqadmin \
    -http-address="0.0.0.0:9000" \
    -lookupd-http-address="127.0.0.1:9011" \
    -lookupd-http-address="127.0.0.1:9012" >> "$NSQADMIN_LOG" 2>&1 &

{% endhighlight %}

I'm really looking forward to learning more about NSQ, its [features][4] look impressive and it's pretty simple to understand.

[1]: https://bitly.com
[2]: http://nsq.io
[3]: https://golang.org
[4]: http://nsq.io/overview/features_and_guarantees.html
