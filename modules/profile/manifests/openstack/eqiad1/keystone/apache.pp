class profile::openstack::eqiad1::keystone::apache(
    String $version = lookup('profile::openstack::eqiad1::version'),
    Stdlib::Port $admin_bind_port = lookup('profile::openstack::eqiad1::keystone::admin_bind_port'),
    Stdlib::Port $public_bind_port = lookup('profile::openstack::eqiad1::keystone::public_bind_port'),
) {

    class {'::profile::openstack::base::keystone::apache':
        version          => $version,
        admin_bind_port  => $admin_bind_port,
        public_bind_port => $public_bind_port,
    }
}
