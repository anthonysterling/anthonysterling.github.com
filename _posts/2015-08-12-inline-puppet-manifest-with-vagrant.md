---
layout: post
title: Inline Puppet Manifest with Vagrant
date: 2015-08-12
tags: [Puppet, Vagrant]
---

I'm a huge fan of [Vagrant][1], it allows me to quickly test applications and proposed architectures with minimal fuss and, with a provisioner, in a way that's reproducible for myself and others.

Vagrant supports many [provisioners][2], but I tend to stick with [shell][3] and [Puppet][4]. Shell provides a nice quick way of hacking together something that Just Works™, but it's hard to get shell to be robust and idempotent which is why I prefer Puppet.

Sadly Vagrant doesn't provide a way to supply an inline [manifest][5] like it does with the shell provisioner. This means that for simple environments you have to create/specify a location for the manifest file or have it within the root of the project.

If you're looking for a quick way to get a simple inline Puppet manifest in Vagrant, here's a simple (albeit [Fugly][6]) way to do this.

{% highlight ruby %}
$manifest = <<PUPPET

    Exec {
        path => ['/usr/bin', '/bin', '/usr/sbin', '/sbin', '/usr/local/bin', '/usr/local/sbin']
    }

    exec { 'apt-get update':
        command => 'apt-get -qq -y update --fix-missing',
        unless  => 'grep -F `date +"%y-%m-%d"` /var/log/apt/history.log'
    }

    package { 'build-essential':
        ensure  => present,
        name    => 'build-essential',
        require => Exec['apt-get update']
    }

PUPPET

def inline_puppet(manifest)
	require 'base64'
	"TMPFILE=$(mktemp); echo '#{Base64.strict_encode64(manifest)}' | base64 --decode > $TMPFILE; puppet apply -v $TMPFILE"
end

Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/trusty64"
    config.vm.provision :shell, :inline => inline_puppet($manifest)
end
{% endhighlight %}

Let me walk you though what happens.

We create a variable in the Vagrantfile to hold the Puppet manifest, and then define a function called `inline_puppet`, we then use this function to create a shell command that:-

1. Base64 encodes the content of `$manifest` using the Base64 module in Ruby so we don't have to worry about escaping it for the shell
2. Uses `base64` to decode the encoded manifest
3. Writes the decoded content to a temporary file, using `mktemp`, within the Vagrant box
4. Instructs Puppet to apply the manifest to the Vagrant box

We then use the built-in inline shell functionality of Vagrant to execute this shell command.

It's not great, but it's a simple way to have a standalone Vagrantfile with Puppet functionality.

[1]: https://www.vagrantup.com
[2]: https://docs.vagrantup.com/v2/provisioning/index.html
[3]: https://en.wikipedia.org/wiki/Unix_shell
[4]: https://puppetlabs.com/puppet/what-is-puppet
[5]: https://docs.puppetlabs.com/pe/latest/puppet_modules_manifests.html#manifests
[6]: http://www.urbandictionary.com/define.php?term=Fugly
