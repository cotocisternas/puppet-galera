# Class galera::repo

# Installs the appropriate repositories from which percona packages
# can be installed

class galera::repo {
  apt::source { 'percona':
    location    => 'http://repo.percona.com/apt/',
    release     => $::lsbdistcodename,
    repos       => 'main',
    key         => '430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A',
    key_server  => 'hkp://keys.gnupg.net',
    include_src => false,
  }

  apt::pin { 'percona':
    priority        => 1001,
    originator      => 'Percona Development Team',
  }  
}
