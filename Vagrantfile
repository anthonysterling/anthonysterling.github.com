$manifest = <<PUPPET

	Exec {
	    path => ['/usr/bin', '/bin', '/usr/sbin', '/sbin', '/usr/local/bin', '/usr/local/sbin']
	}

	exec { 'apt-get update':
	    command => 'apt-get -qq -y update --fix-missing',
	    unless  => 'grep -F `date +"%y-%m-%d"` /var/log/apt/history.log'
	}

	exec { 'locale':
	    command => 'locale-gen en_GB.UTF-8',
	    unless  => 'validlocale en_GB.UTF-8'
	}

	package { 'build-essential':
	    ensure  => present,
	    name    => 'build-essential',
	    require => Exec['apt-get update']
	}

	package { 'ruby-dev':
	    ensure  => present,
	    name    => 'ruby-dev',
	    require => Package['build-essential']
	}

	package { 'ruby':
	    ensure  => present,
	    name    => 'ruby1.9.3',
	    require => [Exec['locale'], Package['ruby-dev']]
	}

	package { 'node':
	    ensure  => present,
	    name    => 'nodejs',
	    require => Exec['apt-get update']
	}

	exec { 'jekyll':
	    command => 'gem install jekyll -v "=2.4.0" --no-rdoc --no-ri',
	    unless  => 'gem list --local | grep jekyll',
	    require => [Package['node'], Package['ruby']]
	}

	exec { 'jekyll serve':
	    command => 'nohup jekyll serve --force_polling > /dev/null 2>&1 &',
	    cwd     => '/vagrant',
	    unless  => 'pgrep jekyll',
	    require => Exec['jekyll']
	}

PUPPET

def inline_puppet(manifest)
	require 'base64'
	"TMPFILE=$(mktemp); echo '#{Base64.strict_encode64(manifest)}' | base64 --decode > $TMPFILE; puppet apply -v $TMPFILE"
end

Vagrant.configure("2") do |config|
    config.vm.box = "trusty64"
    config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"
    config.vm.hostname = "anthonysterling.local"
    config.vm.network :forwarded_port, guest: 4000, host: 4000
    config.vm.provision :shell, :inline => inline_puppet($manifest)
end