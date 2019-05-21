class role::dumps::generation::worker::dumper {
    include ::profile::standard
    include ::profile::base::firewall
    include ::profile::base::firewall::log

    include profile::dumps::generation::worker::common
    include profile::dumps::generation::worker::dumper
    include profile::dumps::generation::worker::crontester

    system::role { 'dumps::generation::worker::dumper':
        description => 'dumper of XML/SQL wiki content',
    }
}
