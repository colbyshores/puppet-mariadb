#
# = Class: mariadb
#
# This class installs and manages mariadb
#
#
# == Parameters
#
# [*root_password*]
#   The mysql password of the root user.
#   If blank, no password is set
#   If 'auto' a random (weak) password is generated
#
# Refer to https://github.com/stdmod for official documentation
# on the stdmod parameters used
#
class mariadb (
  
  $datadir                   = '/var/lib/mysql',
 
  $root_password             = hiera('mariadb::root_password'),  #get default root password from hiera, but still allow for programatic overrides by passing a value
  $version                   = '10.0',

  $package_name              = '',
  $package_ensure            = 'present',

  $service_name              = 'mysql',
  $service_ensure            = 'running',
  $service_enable            = true,
  $config_file_path          = '/etc/my.cnf',
  $config_file_require       = '',
  $config_file_notify        = 'class_default',
  $config_file_source        = undef,
  $config_file_template      = 'mariadb/my.cnf.erb',
  $config_file_content       = undef,
  $config_file_owner         = 'root',
  $config_file_group         = 'root',
  $config_file_mode          = '0644',
  $config_file_options_hash  = undef,

  $config_dir_path           = '',
  $config_dir_source         = undef,
  $config_dir_purge          = false,
  $config_dir_recurse        = true,

  $repo_class                = 'mariadb::repo',

  $monitor_class             = undef,
  $monitor_options_hash      = { } ,

  $firewall_class            = undef,
  $firewall_options_hash     = { } ,

  $scope_hash_filter         = '(uptime.*|timestamp)',

  $tcp_port                  = undef,
  $udp_port                  = undef,

  $cluster                   = undef,    #pass cluster ip array list to template
  ) {

  if $cluster {
    $galera_install = true
  }else{
    $galera_install = false
  }

  #get the salt from hiera
  $root_password_salt = hiera('mariadb::root_password_salt')

  # Class variables validation and management
  case $::osfamily {
    'Debian','RedHat','Amazon': { }
    default: {
      fail("${::operatingsystem} not supported. Review init.pp for extending support.")
    }
  }

  validate_bool($galera_install)
  validate_bool($service_enable)
  validate_bool($config_dir_recurse)
  validate_bool($config_dir_purge)
  if $config_file_options_hash { validate_hash($config_file_options_hash) }
  if $monitor_options_hash { validate_hash($monitor_options_hash) }
  if $firewall_options_hash { validate_hash($firewall_options_hash) }

  $manage_config_file_content = default_content($config_file_content, $config_file_template)

  $manage_config_file_notify  = $config_file_notify ? {
    'class_default' => 'Service[mysql]',
    ''              => undef,
    default         => $config_file_notify,
  }

  $manage_package_ensure = pickx($package_ensure)

  $galera_package_name = $galera_install ? {
    true  => 'MariaDB-Galera-server',
    false => 'MariaDB-server',
  }

  $manage_package_name = $::osfamily ? {
    'Debian' => downcase($galera_package_name),
    default  => $galera_package_name,
  }

  $manage_config_file_path = $config_file_path ? {
    ''  => $version ? {
      '5.5'   => $::osfamily ? {
        'RedHat' => '/etc/my.cnf',
        default  => '/etc/mysql/my.cnf',
      },
      default => '/etc/mysql/my.cnf',
    },
    default => $config_file_path,
  }

  $manage_config_dir_path = $config_dir_path ? {
    ''  => $version ? {
      '5.5'   => $::osfamily ? {
        'RedHat' => '/etc/my.cnf.d/',
        default  => '/etc/mysql/',
      },
      default => '/etc/mysql/',
    },
    default => $config_dir_path,
  }

  $manage_config_file_require = $config_file_require ? {
    ''      => "Package[$manage_package_name]",
    default => $config_file_require,
  }

  if $package_ensure == 'absent' {
    $manage_service_enable = undef
    $manage_service_ensure = stopped
    $manage_service_require = undef
    $config_dir_ensure = absent
    $config_file_ensure = absent
  } else {
    $manage_service_enable = $service_enable
    $manage_service_ensure = $service_ensure
    $manage_service_require = "Package[$manage_package_name]"
    $config_dir_ensure = directory
    $config_file_ensure = present
  }

  $random_password = fqdn_rand(100000000000,$root_password_salt)

  $real_root_password = $root_password ? {
    ''      => '',
    auto    => $random_password,
    default => $root_password,
  }

  if $real_root_password != '' { include mariadb::password }
  
  if $mariadb::manage_package_name {





########################################################
#         I NEED TO FIGURE OUT FUTRE PARSER AND PUPPET 4
########################################################
    if $datadir != '/var/lib/mysql'{
#      $directories = split($datadir, '/')
#      each($directories) |$directory| {
#      if ! defined (File[$directory]) {
#        file { $directory: ensure => directory }
#      }
#      file { '/var/lib/mysql':
#        ensure  => link,
#        target  => $datadir,
#        require => File[$datadir],
#        before  => Package[$mariadb::manage_package_name],
#      }
      exec { "mkdir -p $datadir":
        before => File['/var/lib/mysql'],
      }
      exec { "chown mysql:mysql $datadir":
        require => Exec["mkdir -p $datadir"],
      }
      file { '/var/lib/mysql':
        ensure  => link,
        target  => $datadir,
        require => Exec["chown mysql:mysql $datadir"],
        before  => Package[$mariadb::manage_package_name],
      }
    }




    package { $mariadb::manage_package_name:
      ensure   => $mariadb::manage_package_ensure,
    }
  }

  if $mariadb::manage_config_file_path {
    file { 'mariadb.conf':
      ensure  => $mariadb::config_file_ensure,
      path    => $mariadb::manage_config_file_path,
      mode    => $mariadb::config_file_mode,
      owner   => $mariadb::config_file_owner,
      group   => $mariadb::config_file_group,
      source  => $mariadb::config_file_source,
      content => $mariadb::manage_config_file_content,
      notify  => $mariadb::manage_config_file_notify,
      require => $mariadb::manage_config_file_require,
    }
  }

  user { 'mysql':
    ensure => present,
    home   => '/home',
  }
  group { 'mysql':
    ensure => present,
  }
  file { '/etc/mysql':
    ensure => directory,
    owner => 'mysql',
    group => 'mysql',
    require => [User['mysql'],Group['mysql']],
  }
  file { '/etc/mysql/conf.d':
    owner => 'mysql',
    group => 'mysql',
    ensure  => directory,
    require => File['/etc/mysql'],
  }

  if $mariadb::service_name {
    if $mariadb::cluster{
      include mariadb::cluster
      exec { "creating wsrep_sst-usr":
        command => "echo 'rep_sst_auth = wsrep_sst-user:wsrep' > /etc/mysql/conf.d/wsrep.conf",
        require => File['/etc/mysql/conf.d'],
        before  => Service[$mariadb::service_name],
      }
      if $mariadb::cluster[0] == $::ipaddress {
        service { $mariadb::service_name:
          ensure     => $mariadb::manage_service_ensure,
          enable     => $mariadb::manage_service_enable,
          start   => "/etc/init.d/mysql restart --wsrep-new-cluster",
          stop    => "/etc/init.d/mysql stop",
          require    => [$mariadb::manage_service_require,File['/etc/mysql/conf.d']]
        }
      }else{
        service { $mariadb::service_name:
          ensure     => $mariadb::manage_service_ensure,
          enable     => $mariadb::manage_service_enable,
          start   => "/etc/init.d/mysql start",
          stop    => "/etc/init.d/mysql stop",
          require    => [$mariadb::manage_service_require,File['/etc/mysql/conf.d']]
        }
      }
    }else{
      service { $mariadb::service_name:
        ensure     => $mariadb::manage_service_ensure,
        enable     => $mariadb::manage_service_enable,
        start   => "/etc/init.d/mysql start",
        stop    => "/etc/init.d/mysql stop",
        require    => [$mariadb::manage_service_require,File['/etc/mysql/conf.d']]
      }
    }
  }


  if $mariadb::config_dir_source {
    file { 'mariadb.dir':
      ensure  => $mariadb::config_dir_ensure,
      path    => $mariadb::manage_config_dir_path,
      source  => $mariadb::config_dir_source,
      recurse => $mariadb::config_dir_recurse,
      purge   => $mariadb::config_dir_purge,
      force   => $mariadb::config_dir_purge,
      notify  => $mariadb::config_file_notify,
      require => $mariadb::config_file_require,
    }
  }

  # Extra classes

  if $mariadb::repo_class {
    include $mariadb::repo_class
  }

  if $mariadb::my_class {
    include $mariadb::my_class
  }

  if $mariadb::monitor_class {
    class { $mariadb::monitor_class:
      options_hash => $mariadb::monitor_options_hash,
      scope_hash   => {}, # TODO: Find a good way to inject class' scope
    }
  }

  if $mariadb::firewall_class {
    class { $mariadb::firewall_class:
      options_hash => $mariadb::firewall_options_hash,
      scope_hash   => {},
    }
  }

}

