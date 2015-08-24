# = Class: galera
#
# Author: Coto Cisternas <cotocisternas@gmail.com>
class galera  (
  $galera_servers           = [$::ipaddress],
  $galera_master            = $::ipaddress,
  $local_ip                 = $::ipaddress,
  $bind_address             = '127.0.0.1',
  $mysql_port               = '3306',
  $wsrep_flow_desync        = 'OFF',
  $wsrep_cluster_name       = 'mycluster',
  $wsrep_group_comm_port    = '4567',
  $wsrep_sst_port           = '4444',
  $wsrep_ist_port           = '4568',
  $wsrep_sst_method         = 'xtrabackup-v2',
  $root_password            = 'password',
  $status_password          = 'password',
  $vendor_type              = 'percona',
  $deb_sysmaint_password    = 'sysmaint',
  $mysql_package_name       = undef,
  $galera_package_name      = undef,
  $client_package_name      = undef,
  $lib_package_name         = undef,
  $configure_repo           = true,
  $configure_firewall       = false,
  $validate_connection      = true,
  $status_check             = true,
  $override_options         = {},

) {

  $cluster_address = join($galera::galera_servers, ',')

  if $configure_repo {
    include ::galera::repo
    Class['::galera::repo'] -> Class['mysql::server']
  }

  if $status_check {
    include ::galera::status
  }

  if ($::osfamily == 'Debian') {
    include ::galera::debian
  }

  $default_options = {
    'mysqld' => {
      'bind-address'                      => $bind_address,
      'wsrep_node_address'                => $local_ip,
      'wsrep_node_name'                   => $::hostname,
      'wsrep_provider'                    => '/usr/lib/libgalera_smm.so',
      'wsrep_cluster_address'             => "gcomm://${cluster_address}",
      'wsrep_cluster_name'                => $wsrep_cluster_name,
      'wsrep_slave_threads'               => '8',
      'wsrep_sst_method'                  => $wsrep_sst_method,
      'wsrep_sst_auth'                    => "root:${root_password}",
      'binlog_format'                     => 'ROW',
      'default_storage_engine'            => 'InnoDB',
      'innodb_locks_unsafe_for_binlog'    => '1',
      'innodb_autoinc_lock_mode'          => '2',
      'query_cache_size'                  => '0',
      'query_cache_type'                  => '0',
      'wsrep_node_incoming_address'       => $local_ip,
      'wsrep_sst_receive_address'         => $local_ip,
      'wsrep_desync'                      => $wsrep_flow_sync
    }
  }

  if $::fqdn == $galera_master or $::hostname == $galera_master {
    $master_options = {
      'mysqld' => {
        'wsrep_desync'                      => 'OFF'
      }
    }
    $server_list = join($galera_servers, ' ')
    exec { 'bootstrap_galera_cluster':
      command  => '/etc/init.d/mysql bootstrap-pxc',
      onlyif   => "ret=1; for i in ${server_list}; do nc -z \$i ${wsrep_group_comm_port}; if [ \"\$?\" = \"0\" ]; then ret=0; fi; done; /bin/echo \$ret | /bin/grep 1 -q",
      require  => Class['mysql::server::config'],
      before   => [Class['mysql::server::service'], Service['mysqld']],
      provider => shell,
      path     => '/usr/bin:/bin:/usr/sbin:/sbin'
    }
  }

  if ($root_password != 'UNSET') {
    # Check if we can already login with the given password
    $my_cnf = "[client]\r\nuser=root\r\nhost=localhost\r\npassword='${root_password}'\r\n"

    exec { "create ${::root_home}/.my.cnf":
      command => "/bin/echo -e \"${my_cnf}\" > ${::root_home}/.my.cnf",
      onlyif  => [
        "/usr/bin/mysql --user=root --password=${root_password} -e 'select count(1);'",
        "/usr/bin/test `/bin/cat ${::root_home}/.my.cnf | /bin/grep -c \"password='${root_password}'\"` -eq 0",
        ],
      require => [Service['mysqld']],
      before  => [Class['mysql::server::root_password']],
    }
  }

  class { 'mysql::server':
    package_name      => 'percona-xtradb-cluster-server-5.5',
    override_options  => mysql_deepmerge($default_options, $override_options, $master_options),
    root_password     => $root_password,
    service_name      => 'mysql',
    require           => Exec['apt_update'],
  }

}