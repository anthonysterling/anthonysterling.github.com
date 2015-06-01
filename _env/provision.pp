Exec {
    path => ['/usr/bin', '/bin', '/usr/sbin', '/sbin', '/usr/local/bin', '/usr/local/sbin']
}

exec { 'apt-get update':
    command => 'apt-get -qq -y update --fix-missing'
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

package { 'ruby1.9.3':
    ensure  => present,
    name    => 'ruby1.9.3',
    require => Package['ruby-dev']
}

exec { 'jekyll':
    command => "gem install jekyll -v '=1.5.1' --no-rdoc --no-ri",
    unless  => 'gem list --local | grep jekyll',
    require => Package['ruby1.9.3']
}
