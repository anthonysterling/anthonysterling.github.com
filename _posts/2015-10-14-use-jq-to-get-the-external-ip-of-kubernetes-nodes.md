---
layout: post
title: Use jq to get the external IP of Kubernetes Nodes
date: 2015-10-14
---

Following a brief [Twitter conversation][1] with [Alexandre González][2], one of the organisers of the excellent [Golang UK Conference][3], who asked if there was a better way of finding the External IP of a [Kubernetes][4] Node instead of using

{% highlight bash %}
    kubectl get nodes -o json|grep ExternalIP -A1|tail -n1|cut -d: -f2|tr "\"" " "|tr -d '[[:space:]]'
{% endhighlight %}

I figured [jq][5] should be be suitable, to quote the author of jq

> jq is like sed for JSON data - you can use it to slice and filter and map and transform structured data with the same ease that sed, awk, grep and friends let you play with text.

Here's how you can use JQ to obtain the External IP of one or many Kubernetes Node(s).

{% highlight bash %}
    kubectl get nodes -o json | jq '.items[] | .status .addresses[] | select(.type=="ExternalIP") | .address' 
{% endhighlight %}

Neat.

[1]: https://twitter.com/agonzalezro/status/654349270456369153
[2]: http://agonzalezro.github.io/pages/about.html
[3]: http://golanguk.com
[4]: http://kubernetes.io
[5]: https://stedolan.github.io/jq/
