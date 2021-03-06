class base::resolving (
    $domain_search = $::domain,
    $labs_additional_domains = [],
    $nameservers = $::nameservers,
){
    if ! $nameservers {
        fail('Variable $nameservers is not defined!')
    }

    if $::realm == 'labs' {
        $labs_tld = lookup('labs_tld')
        $labs_site = lookup('labs_site', {'default_value' => $::site})
        # Thanks to dhcp, resolvconf is constantly messing with our resolv.conf.  Disable it.
        file { '/sbin/resolvconf':
            owner  => 'root',
            group  => 'root',
            mode   => '0555',
            source => 'puppet:///modules/base/resolv/resolvconf.dummy',
        }

        file { '/etc/dhcp/dhclient-enter-hooks.d':
            ensure => 'directory',
        }

        # also stop dhclient from updating resolv.conf.
        file { '/etc/dhcp/dhclient-enter-hooks.d/nodnsupdate':
            owner   => 'root',
            group   => 'root',
            mode    => '0555',
            source  => 'puppet:///modules/base/resolv/nodnsupdate',
            require => File['/etc/dhcp/dhclient-enter-hooks.d'],
        }

        # Now, finally, we can just puppetize the damn file
        file { '/etc/resolv.conf':
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => template('base/resolv.conf.labs.erb'),
        }
    } else {
        file { '/etc/resolv.conf':
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => template('base/resolv.conf.erb'),
        }
    }
}
