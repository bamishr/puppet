# Shared profile for front- and back-end puppetmasters.
#
# $config:  Dict merged with front- or back- specifics and then passed
#           to ::puppetmaster as $config
#
# $storeconfigs: Accepts values of 'puppetdb', 'activerecord', and 'none'
#
class profile::puppetmaster::common (
                        $base_config,
                        $storeconfigs      = lookup('profile::puppetmaster::common::storeconfigs'),
    Array[Stdlib::Host] $puppetdb_hosts    = lookup('profile::puppetmaster::common::puppetdb_hosts'),
    Boolean             $command_broadcast = lookup('profile::puppetmaster::common::command_broadcast'),
    Integer[1,2]        $ssl_verify_depth  = lookup('profile::puppetmaster::common::ssl_verify_depth')
) {
    include passwords::puppet::database

    $env_config = {
        'environmentpath'  => '$confdir/environments',
        'default_manifest' => '$confdir/manifests',
    }

    $activerecord_config =   {
        'storeconfigs'      => true,
        'thin_storeconfigs' => true,
    }
    $active_record_db = {
        'dbadapter'         => 'mysql',
        'dbuser'            => 'puppet',
        'dbpassword'        => $passwords::puppet::database::puppet_production_db_pass,
        'dbserver'          => 'm1-master.eqiad.wmnet',
        'dbconnections'     => '256',
    }

    $puppetdb_config = {
        storeconfigs         => true,
        storeconfigs_backend => 'puppetdb',
        reports              => 'puppetdb',
    }

    if $storeconfigs == 'puppetdb' {
        class { 'puppetmaster::puppetdb::client':
            hosts             => $puppetdb_hosts,
            command_broadcast => $command_broadcast,
        }
        $config = merge($base_config, $puppetdb_config, $env_config)
    } elsif $storeconfigs == 'activerecord' {
            $config = merge($base_config, $activerecord_config, $active_record_db, $env_config)
    } else {
            $config = merge($base_config, $env_config)
    }

    # Don't attempt to use puppet-master service on stretch, we're using passenger.
    if os_version('debian >= stretch') {
        service { 'puppet-master':
            ensure  => stopped,
            enable  => false,
            require => Package['puppet'],
        }
    }
}
