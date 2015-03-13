define cluster_permissions {
  exec { "post processing cluster configuration_$name":
    command => "mysql -uroot -p$mariadb::root_password -e  'GRANT ALL ON *.* to 'root'@'$name';'",
  }
}

class mariadb::cluster {

  require mariadb
  require mariadb::password

  exec { "post processing cluster configuration":
    command => "mysql -uroot -p$mariadb::root_password -e \"DELETE FROM mysql.user WHERE User=''; GRANT ALL ON *.* to 'wsrep_sst-user'@'%' IDENTIFIED BY 'wsrep';\"",
  }
  if $mariadb::cluster[0] == $::ipaddress {
    cluster_permissions { $mariadb::cluster:
      require => Exec['post processing cluster configuration'],
    }
    exec { '/etc/init.d/mysql restart --wsrep-new-cluster': 
      require => Cluster_permissions[$mariadb::cluster],
    }
  }else{
    cluster_permissions { $mariadb::cluster:
      require => Exec['post processing cluster configuration'],
    }
  }
}
