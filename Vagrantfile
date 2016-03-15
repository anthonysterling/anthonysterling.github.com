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
	    name    => 'ruby2.0-dev',
	    require => Package['build-essential']
	}

	package { 'ruby':
	    ensure  => present,
	    name    => 'ruby2.0',
	    require => [Exec['locale'], Package['ruby-dev']]
	}

	exec { 'ruby-update-alternatives':
	    command => 'update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby2.0 10 && update-alternatives --install /usr/bin/gem gem /usr/bin/gem2.0 10',
	    unless  => 'update-alternatives --query ruby | grep ruby2.0',
	    require => [Package['node'], Package['ruby']]
	}

	package { 'node':
	    ensure  => present,
	    name    => 'nodejs',
	    require => Exec['apt-get update']
	}

	exec { 'jekyll':
	    command => 'gem install jekyll -v "=3.1.1" --no-rdoc --no-ri',
	    unless  => 'gem list --local | grep jekyll',
	    require => [Package['node'], Package['ruby'], Exec['ruby-update-alternatives']]
	}

	exec { 'jekyll-paginate':
	    command => 'gem install jekyll-paginate --no-rdoc --no-ri',
	    unless  => 'gem list --local | grep jekyll-paginate',
	    require => [Package['node'], Package['ruby'], Exec['jekyll']]
	}

	exec { 'jekyll serve':
	    command => 'jekyll serve --incremental --force_polling --detach --host 0.0.0.0',
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
    config.vm.hostname = "anthonysterling.local"
    config.vm.network :forwarded_port, guest: 4000, host: 4000
    config.vm.provision :shell, :inline => inline_puppet($manifest)
end
