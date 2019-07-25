class profile::openstack::codfw1dev::nova::compute::service(
    $version = hiera('profile::openstack::codfw1dev::version'),
    $network_flat_interface = hiera('profile::openstack::codfw1dev::nova::network_flat_interface'),
    $network_flat_tagged_base_interface = hiera('profile::openstack::codfw1dev::nova::network_flat_tagged_base_interface'),
    $network_flat_interface_vlan = hiera('profile::openstack::codfw1dev::nova::network_flat_interface_vlan'),
    $network_flat_name = hiera('profile::openstack::codfw1dev::neutron::network_flat_name'),
    $physical_interface_mappings = hiera('profile::openstack::codfw1dev::nova::physical_interface_mappings'),
    ) {

    require ::profile::openstack::codfw1dev::neutron::common
    class {'::profile::openstack::base::neutron::linuxbridge_agent':
        version                     => $version,
        physical_interface_mappings => $physical_interface_mappings,
    }
    contain '::profile::openstack::base::neutron::linuxbridge_agent'

    require ::profile::openstack::codfw1dev::nova::common
    class {'::profile::openstack::base::nova::compute::service':
        version                            => $version,
        network_flat_interface             => $network_flat_interface,
        network_flat_tagged_base_interface => $network_flat_tagged_base_interface,
        network_flat_interface_vlan        => $network_flat_interface_vlan,
        all_cloudvirts                     => unique(concat(query_nodes('Class[profile::openstack::codfw1dev::nova::compute::service]'), [$::fqdn])),
        require                            => Class['::profile::openstack::base::neutron::linuxbridge_agent'],
    }
    contain '::profile::openstack::base::nova::compute::service'

    # For OpenStack configure unconditional flushes of the L1 cache during VMENTER
    # https://www.kernel.org/doc/html/latest/admin-guide/hw-vuln/l1tf.html
    if os_version('debian == stretch') and (versioncmp($::kernelrelease, '4.9.0-9-amd64') >= 0) {
        kmod::options { 'kvm_intel':
            options => 'vmentry_l1d_flush=always',
        }
    }
}
