require boxen::environment
require homebrew
require gcc

Exec {
  group       => 'staff',
  logoutput   => on_failure,
  user        => $boxen_user,

  path => [
    "${boxen::config::home}/rbenv/shims",
    "${boxen::config::home}/rbenv/bin",
    "${boxen::config::home}/rbenv/plugins/ruby-build/bin",
    "${boxen::config::home}/homebrew/bin",
    '/usr/bin',
    '/bin',
    '/usr/sbin',
    '/sbin'
  ],

  environment => [
    "HOMEBREW_CACHE=${homebrew::config::cachedir}",
    "HOME=/Users/${::boxen_user}"
  ]
}

File {
  group => 'staff',
  owner => $boxen_user
}

Package {
  provider => homebrew,
  require  => Class['homebrew'],
  install_options => ['--build-from-source']
}

Repository {
  provider => git,
  extra    => [
    '--recurse-submodules'
  ],
  require  => File["${boxen::config::bindir}/boxen-git-credential"],
  config   => {
    'credential.helper' => "${boxen::config::bindir}/boxen-git-credential"
  }
}

Service {
  provider => ghlaunchd
}

Homebrew::Formula <| |> -> Package <| |>

node default {
  # core modules, needed for most things
  # include dnsmasq   ### Not needed by SU ###
  include git
  include hub
  # include nginx   ### Not needed by SU ###

  # fail if FDE is not enabled
  if $::root_encrypted == 'no' {
    fail('Please enable full disk encryption and try again')
  }

  # openssl required since it was included in either dnsmasq or nginx
  include openssl

  # node versions
  include nodejs::v0_6
  include nodejs::v0_8
  include nodejs::v0_10

  # default ruby versions
  include ruby::1_8_7
  include ruby::1_9_2
  include ruby::1_9_3
  include ruby::2_0_0

  # common, useful packages
  package {
    [
      'ack',
      'findutils',
      'gnu-tar'
    ]:
  }

  #
  # Remove services SimpleUpdates does not need
  #
  service {"dev.nginx":
	ensure => "stopped"
  }

  service {"dev.dnsmasq":
	ensure => "stopped"
  }
  
  #
  # Install MySQL and supporting components and packages
  # pstree and watch provide feedback on MySQL installation
  # since it takes a long time
  #
  package { "pstree":
    ensure => present,
  }
 
  package { "watch":
    ensure => present,
  }
 
 package { "mtr":
    ensure => present,
  }

  exec { "tap-homebrew-dupes":
    command => "brew tap homebrew/dupes",
    creates => "${homebrew::config::tapsdir}/homebrew-dupes",
  }
 
  exec { "josegonzalez/homebrew-php":
    command => "brew tap josegonzalez/homebrew-php",
    creates => "${homebrew::config::tapsdir}/josegonzalez-php",
    require => Exec["tap-homebrew-dupes"],
  }

  package { "php55":
    ensure => present,
    require => [
        Exec["josegonzalez/homebrew-php"],
        Package["pstree"],
        Package["watch"],
        ],
  }
  file { "${boxen::config::srcdir}/our-boxen":
    ensure => link,
    target => $boxen::config::repodir
  }
}
