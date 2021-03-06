class profile::openstack::codfw1dev::cloudgw (
    Array[String]                 $dmz_cidr       = lookup('profile::openstack::codfw1dev::cloudgw::dmz_cidr',         {default_value => ['0.0.0.0/0 . 0.0.0.0/0']}),
    Stdlib::IP::Address           $routing_source = lookup('profile::openstack::codfw1dev::cloudgw::routing_source_ip',{default_value => '185.15.57.1'}),
    Stdlib::IP::Address::V4::CIDR $virt_subnet    = lookup('profile::openstack::codfw1dev::cloudgw::virt_subnet_cidr', {default_value => '172.16.128.0/24'}),
    Array[String]                 $all_phy_nics   = lookup('profile::openstack::codfw1dev::cloudgw::all_phy_nics',     {default_value => ['eno1']}),
    Stdlib::IP::Address           $host_addr      = lookup('profile::openstack::codfw1dev::cloudgw::host_addr',        {default_value => '127.0.0.2'}),
    Integer                       $host_netm      = lookup('profile::openstack::codfw1dev::cloudgw::host_netm',        {default_value => 8}),
    Stdlib::IP::Address           $host_gw        = lookup('profile::openstack::codfw1dev::cloudgw::host_gw',          {default_value => '127.0.0.1'}),
    String                        $host_prefixv6  = lookup('profile::openstack::codfw1dev::cloudgw::host_prefixv6',    {default_value => 'fe00:'}),
    Integer                       $virt_vlan      = lookup('profile::openstack::codfw1dev::cloudgw::virt_vlan',        {default_value => 2107}),
    Stdlib::IP::Address           $virt_addr      = lookup('profile::openstack::codfw1dev::cloudgw::virt_addr',        {default_value => '127.0.0.3'}),
    Integer                       $virt_netm      = lookup('profile::openstack::codfw1dev::cloudgw::virt_netm',        {default_value => 8}),
    Stdlib::IP::Address           $virt_peer      = lookup('profile::openstack::codfw1dev::cloudgw::virt_peer',        {default_value => '127.0.0.5'}),
    Stdlib::IP::Address::V4::CIDR $virt_floating  = lookup('profile::openstack::codfw1dev::cloudgw::virt_floating',    {default_value => '127.0.0.5/24'}),
    Integer                       $wan_vlan       = lookup('profile::openstack::codfw1dev::cloudgw::wan_vlan',         {default_value => 2120}),
    Stdlib::IP::Address           $wan_addr       = lookup('profile::openstack::codfw1dev::cloudgw::wan_addr',         {default_value => '127.0.0.4'}),
    Integer                       $wan_netm       = lookup('profile::openstack::codfw1dev::cloudgw::wan_netm',         {default_value => 8}),
    Stdlib::IP::Address           $wan_gw         = lookup('profile::openstack::codfw1dev::cloudgw::wan_gw',           {default_value => '127.0.0.1'}),
) {
    class { '::profile::openstack::base::cloudgw':
        host_addr     => $host_addr,
        host_netm     => $host_netm,
        host_gw       => $host_gw,
        host_prefixv6 => $host_prefixv6,
        virt_vlan     => $virt_vlan,
        virt_addr     => $virt_addr,
        virt_netm     => $virt_netm,
        virt_peer     => $virt_peer,
        virt_floating => $virt_floating,
        wan_vlan      => $wan_vlan,
        wan_addr      => $wan_addr,
        wan_netm      => $wan_netm,
        wan_gw        => $wan_gw,
        all_phy_nics  => $all_phy_nics,
    }
    contain '::profile::openstack::base::cloudgw'

    $nic_host = 'eno1'
    $nic_virt = "eno2.${virt_vlan}"
    $nic_wan  = "eno2.${wan_vlan}"

    nftables::file { 'cloudgw':
        ensure  => present,
        order   => 1,
        content => template('profile/openstack/codfw1dev/cloudgw.nft.erb'),
    }
}
