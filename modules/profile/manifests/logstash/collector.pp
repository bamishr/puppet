# vim:sw=4 ts=4 sts=4 et:
# == Class: profile::logstash::collector
#
# Provisions Logstash and an Elasticsearch node to proxy requests to ELK stack
# Elasticsearch cluster.
#
# == Parameters:
# - $prometheus_nodes: List of prometheus nodes to allow connections from
# - $input_kafka_ssl_truststore_passwords:
#   Hash of kafka cluster name to password for jks truststore used by logstash kafka input plugin,
#   e.g. $input_kafka_ssl_truststore_passwords['logging-eqiad'] == 'XXXXXX', etc.
#
# filtertags: labs-project-deployment-prep
class profile::logstash::collector (
    $prometheus_nodes = hiera('prometheus_nodes', []),
    $input_kafka_ssl_truststore_passwords = hiera('profile::logstash::collector::input_kafka_ssl_truststore_passwords'),
    $input_kafka_consumer_group_id = hiera('profile::logstash::collector::input_kafka_consumer_group_id', undef),
    $jmx_exporter_port = hiera('profile::logstash::collector::jmx_exporter_port', 7800),
    $maintenance_hosts = hiera('maintenance_hosts', []),
) {

    require ::profile::java

    $config_dir = '/etc/prometheus'
    $jmx_exporter_config_file = "${config_dir}/logstash_jmx_exporter.yaml"

    # Prometheus JVM metrics
    profile::prometheus::jmx_exporter { "logstash_collector_${::hostname}":
        hostname         => $::hostname,
        port             => $jmx_exporter_port,
        prometheus_nodes => $prometheus_nodes,
        config_file      => $jmx_exporter_config_file,
        config_dir       => $config_dir,
        source           => 'puppet:///modules/profile/logstash/jmx_exporter.yaml',
    }

    class { '::logstash':
        jmx_exporter_port   => $jmx_exporter_port,
        jmx_exporter_config => $jmx_exporter_config_file,
        pipeline_workers    => $::processorcount * 2,
    }

    sysctl::parameters { 'logstash_receive_skbuf':
        values => {
            'net.core.rmem_default' => 8388608,
        },
    }

    ## Inputs (10)

    logstash::input::udp2log { 'mediawiki':
        port => 8324,
        tags => ['input-udp2log-mediawiki-8324'],
    }

    ferm::service { 'logstash_udp2log':
        proto   => 'udp',
        port    => '8324',
        notrack => true,
        srange  => '$DOMAIN_NETWORKS',
    }

    logstash::input::syslog { 'syslog':
        port => 10514,
        tags => ['input-syslog-10514'],
    }

    ferm::service { 'logstash_syslog_udp':
        proto   => 'udp',
        port    => '10514',
        notrack => true,
        srange  => '($DOMAIN_NETWORKS $NETWORK_INFRA $MGMT_NETWORKS)',
    }

    ferm::service { 'logstash_syslog_tcp':
        proto   => 'tcp',
        port    => '10514',
        notrack => true,
        srange  => '($DOMAIN_NETWORKS $NETWORK_INFRA $MGMT_NETWORKS)',
    }
    nrpe::monitor_service { 'logstash_syslog_tcp':
        description  => 'logstash syslog TCP port',
        nrpe_command => '/usr/lib/nagios/plugins/check_tcp -H 127.0.0.1 -p 10514',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Logstash',
    }

    ferm::service { 'grafana_dashboard_definition_storage':
        proto  => 'tcp',
        port   => '9200',
        srange => '@resolve((grafana1002.eqiad.wmnet))',
    }

    $maintenance_hosts_str = join($maintenance_hosts, ' ')
    ferm::service { 'logstash_canary_checker_reporting':
        proto  => 'tcp',
        port   => '9200',
        srange => "(\$DEPLOYMENT_HOSTS ${maintenance_hosts_str})",
    }

    logstash::input::gelf { 'gelf':
        port => 12201,
        tags => ['input-gelf-12201'],
    }

    ferm::service { 'logstash_gelf':
        proto   => 'udp',
        port    => '12201',
        notrack => true,
        srange  => '$DOMAIN_NETWORKS',
    }

    logstash::input::udp { 'logback':
        port  => 11514,
        codec => 'json',
        tags  => ['input-udp-logback-11514'],
    }

    ferm::service { 'logstash_udp':
        proto   => 'udp',
        port    => '11514',
        notrack => true,
        srange  => '$DOMAIN_NETWORKS',
    }

    logstash::input::tcp { 'json_lines':
        port  => 11514,
        codec => 'json_lines',
        tags  => ['input-tcp-json_lines-11514'],
    }

    ferm::service { 'logstash_json_lines':
        proto   => 'tcp',
        port    => '11514',
        notrack => true,
        srange  => '$DOMAIN_NETWORKS',
    }
    nrpe::monitor_service { 'logstash_json_lines_tcp':
        description  => 'logstash JSON linesTCP port',
        nrpe_command => '/usr/lib/nagios/plugins/check_tcp -H 127.0.0.1 -p 11514',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Logstash',
    }

    # Logstash collectors in both sites pull messages
    # from logging kafka clusters in both DCs.
    logstash::input::kafka { 'rsyslog-shipper-eqiad':
        kafka_cluster_name      => 'logging-eqiad',
        topics_pattern          => 'rsyslog-.*',
        group_id                => $input_kafka_consumer_group_id,
        type                    => 'syslog',
        tags                    => ['input-kafka-rsyslog-shipper', 'rsyslog-shipper', 'kafka', 'es'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-eqiad'],
        consumer_threads        => 3,
    }

    logstash::input::kafka { 'rsyslog-shipper-codfw':
        kafka_cluster_name      => 'logging-codfw',
        topics_pattern          => 'rsyslog-.*',
        group_id                => $input_kafka_consumer_group_id,
        type                    => 'syslog',
        tags                    => ['rsyslog-shipper','kafka', 'es'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-codfw'],
    }

    logstash::input::kafka { 'rsyslog-udp-localhost-eqiad':
        kafka_cluster_name      => 'logging-eqiad',
        topics_pattern          => 'udp_localhost-.*',
        group_id                => $input_kafka_consumer_group_id,
        type                    => 'syslog',
        tags                    => ['input-kafka-rsyslog-udp-localhost', 'rsyslog-udp-localhost', 'kafka', 'es'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-eqiad'],
    }

    logstash::input::kafka { 'rsyslog-udp-localhost-codfw':
        kafka_cluster_name      => 'logging-codfw',
        topics_pattern          => 'udp_localhost-.*',
        group_id                => $input_kafka_consumer_group_id,
        type                    => 'syslog',
        tags                    => ['rsyslog-udp-localhost','kafka', 'es'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-codfw'],
        consumer_threads        => 3,
    }

    logstash::input::kafka { 'rsyslog-logback-eqiad':
        kafka_cluster_name      => 'logging-eqiad',
        topics_pattern          => 'logback.*',
        group_id                => $input_kafka_consumer_group_id,
        type                    => 'logback',
        tags                    => ['input-kafka-rsyslog-logback', 'kafka-logging-eqiad', 'kafka', 'es'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-eqiad'],
        consumer_threads        => 3,
    }

    logstash::input::kafka { 'rsyslog-logback-codfw':
        kafka_cluster_name      => 'logging-codfw',
        topics_pattern          => 'logback.*',
        group_id                => $input_kafka_consumer_group_id,
        type                    => 'logback',
        tags                    => ['input-kafka-rsyslog-logback', 'kafka-logging-codfw', 'kafka', 'es'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-codfw'],
        consumer_threads        => 3,
    }

    logstash::input::kafka { 'clienterror-eqiad':
        kafka_cluster_name      => 'logging-eqiad',
        topics_pattern          => 'eqiad\.mediawiki\.client\.error|eqiad\.kaios_app\.error',
        group_id                => $input_kafka_consumer_group_id,
        type                    => 'clienterror',
        tags                    => ['input-kafka-clienterror-eqiad', 'kafka', 'es'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-eqiad'],
        consumer_threads        => 3,
    }

    logstash::input::kafka { 'clienterror-codfw':
        kafka_cluster_name      => 'logging-codfw',
        topics_pattern          => 'codfw\.mediawiki\.client\.error|codfw\.kaios_app\.error',
        group_id                => $input_kafka_consumer_group_id,
        type                    => 'clienterror',
        tags                    => ['input-kafka-clienterror-codfw', 'kafka', 'es'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-codfw'],
        consumer_threads        => 3,
    }

    logstash::input::kafka { 'networkerror-eqiad':
        kafka_cluster_name      => 'logging-eqiad',
        topic                   => 'eqiad.w3c.reportingapi.network_error',
        group_id                => $input_kafka_consumer_group_id,
        tags                    => ['input-kafka-networkerror-eqiad', 'kafka', 'es', 'w3creportingapi'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-eqiad'],
        consumer_threads        => 3,
    }

    logstash::input::kafka { 'networkerror-codfw':
        kafka_cluster_name      => 'logging-codfw',
        topic                   => 'codfw.w3c.reportingapi.network_error',
        group_id                => $input_kafka_consumer_group_id,
        tags                    => ['input-kafka-networkerror-codfw', 'kafka', 'es', 'w3creportingapi'],
        codec                   => 'json',
        security_protocol       => 'SSL',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-codfw'],
        consumer_threads        => 3,
    }

    # Collect all EventGate instance error.validation topics into logstash.
    # Maps logstash::input::kafka title to a kafka cluster and topic to consume.
    $eventgate_validation_error_logstash_inputs = {

        # eventgate-main uses both Kafka main-eqiad and main-codfw
        'eventgate-main-validation-error-eqiad' => {
            'kafka_cluster_name' => 'main-eqiad',
            'topic' => 'eqiad.eventgate-main.error.validation'
        },
        'eventgate-main-validation-error-codfw' => {
            'kafka_cluster_name' => 'main-codfw',
            'topic' => 'codfw.eventgate-main.error.validation'
        },

        # eventgate-analytics uses only Kafka jumbo-eqiad
        'eventgate-analytics-validation-error-eqiad' => {
            'kafka_cluster_name' => 'jumbo-eqiad',
            'topic' => 'eqiad.eventgate-analytics.error.validation'
        },
        'eventgate-analytics-validation-error-codfw' => {
            'kafka_cluster_name' => 'jumbo-eqiad',
            'topic' => 'codfw.eventgate-analytics.error.validation'
        },

        # eventgate-analytics-external uses only Kafka jumbo-eqiad
        'eventgate-analytics-external-validation-error-eqiad' => {
            'kafka_cluster_name' => 'jumbo-eqiad',
            'topic' => 'eqiad.eventgate-analytics-external.error.validation'
        },
        'eventgate-analytics-external-validation-error-codfw' => {
            'kafka_cluster_name' => 'jumbo-eqiad',
            'topic' => 'codfw.eventgate-analytics-external.error.validation'
        },

        # eventgate-logging-external uses both Kafka logging-eqiad and logging-codfw
        'eventgate-logging-external-validation-error-eqiad' => {
            'kafka_cluster_name' => 'logging-eqiad',
            'topic' => 'eqiad.eventgate-logging-external.error.validation'
        },
        'eventgate-logging-external-validation-error-codfw' => {
            'kafka_cluster_name' => 'logging-codfw',
            'topic' => 'codfw.eventgate-logging-external.error.validation'
        },
    }
    $eventgate_validation_error_logstash_inputs.each |String $input_title, $input_params| {
        logstash::input::kafka { $input_title:
            kafka_cluster_name      => $input_params['kafka_cluster_name'],
            topic                   => $input_params['topic'],
            group_id                => $input_kafka_consumer_group_id,
            type                    => 'eventgate_validation_error',
            tags                    => ["input-kafka-${input_title}", 'kafka', 'es', 'eventgate'],
            codec                   => 'json',
            security_protocol       => 'SSL',
            ssl_truststore_password => $input_kafka_ssl_truststore_passwords[$input_params['kafka_cluster_name']],
            consumer_threads        => 3,
        }
    }


    # TODO: Rename this, this is the EventLogging event error topic input.
    $kafka_topic_eventlogging        = 'eventlogging_EventError'
    logstash::input::kafka { $kafka_topic_eventlogging:
        kafka_cluster_name => 'jumbo-eqiad',
        group_id           => $input_kafka_consumer_group_id,
        tags               => [$kafka_topic_eventlogging, 'kafka', 'input-kafka-eventlogging', 'es'],
        type               => 'eventlogging',
        codec              => 'json'
    }

    ## Global pre-processing (15)

    # move files into module?
    # lint:ignore:puppet_url_without_modules
    logstash::conf { 'filter_strip_ansi_color':
        source   => 'puppet:///modules/profile/logstash/filter-strip-ansi-color.conf',
        priority => 15,
    }

    # Enforce a maximum length on "message" and "msg" fields
    logstash::conf { 'filter_truncate':
        source   => 'puppet:///modules/profile/logstash/filter-truncate.conf',
        priority => 15,
    }

    ## Input specific processing (20)

    logstash::conf { 'filter_syslog':
        source   => 'puppet:///modules/profile/logstash/filter-syslog.conf',
        priority => 20,
    }

    logstash::conf { 'filter_syslog_network':
        source   => 'puppet:///modules/profile/logstash/filter-syslog-network.conf',
        priority => 20,
    }

    logstash::conf { 'filter_udp2log':
        source   => 'puppet:///modules/profile/logstash/filter-udp2log.conf',
        priority => 20,
    }

    logstash::conf { 'filter_gelf':
        source   => 'puppet:///modules/profile/logstash/filter-gelf.conf',
        priority => 20,
    }

    logstash::conf { 'filter_log4j':
        source   => 'puppet:///modules/profile/logstash/filter-log4j.conf',
        priority => 20,
    }

    logstash::conf { 'filter_logback':
        source   => 'puppet:///modules/profile/logstash/filter-logback.conf',
        priority => 20,
    }

    logstash::conf { 'filter_json_lines':
        source   => 'puppet:///modules/profile/logstash/filter-json-lines.conf',
        priority => 20,
    }

    # rsyslog-shipper processing might tweak/adjust some generic syslog fields
    # thus process this filter after all inputs
    logstash::conf { 'filter_rsyslog_shipper':
        source   => 'puppet:///modules/profile/logstash/filter-rsyslog-shipper.conf',
        priority => 25,
    }

    # Process nested JSON from Docker -> Kubernetes -> rsyslog
    logstash::conf { 'filter_kubernetes_docker':
        source   => 'puppet:///modules/profile/logstash/filter-kubernetes-docker.conf',
        priority => 30,
    }

    ## Application specific processing (50)

    logstash::conf { 'filter_mediawiki':
        source   => 'puppet:///modules/profile/logstash/filter-mediawiki.conf',
        priority => 50,
    }

    logstash::conf { 'filter_striker':
        source   => 'puppet:///modules/profile/logstash/filter-striker.conf',
        priority => 50,
    }

    logstash::conf { 'filter_ores':
        source   => 'puppet:///modules/profile/logstash/filter-ores.conf',
        priority => 50,
    }

    logstash::conf { 'filter_mjolnir':
        source   => 'puppet:///modules/profile/logstash/filter-mjolnir.conf',
        priority => 50,
    }

    logstash::conf { 'filter_webrequest':
        source   => 'puppet:///modules/profile/logstash/filter-webrequest.conf',
        priority => 50,
    }

    logstash::conf { 'filter_apache2_error':
        source   => 'puppet:///modules/profile/logstash/filter-apache2-error.conf',
        priority => 50,
    }

    logstash::conf { 'filter_rsyslog_multiline':
        source   => 'puppet:///modules/profile/logstash/filter-rsyslog-multiline.conf',
        priority => 50,
    }

    logstash::conf { 'filter_eventlogging':
        source   => 'puppet:///modules/profile/logstash/filter-eventlogging.conf',
        priority => 50,
    }

    logstash::conf { 'filter_icinga':
        source   => 'puppet:///modules/profile/logstash/filter-icinga.conf',
        priority => 50,
    }

    logstash::conf { 'filter_ulogd':
        source   => 'puppet:///modules/profile/logstash/filter-ulogd.conf',
        priority => 50,
    }

    logstash::conf { 'filter_clienterror':
        source   => 'puppet:///modules/profile/logstash/filter-clienterror.conf',
        priority => 50,
    }

    logstash::conf { 'filter_w3creportingapi':
        source   => 'puppet:///modules/profile/logstash/filter-w3creportingapi.conf',
        priority => 50,
    }

    ## Global post-processing (70)

    logstash::conf { 'filter_add_normalized_message':
        source   => 'puppet:///modules/profile/logstash/filter-add-normalized-message.conf',
        priority => 70,
    }

    logstash::conf { 'filter_normalize_log_levels':
        source   => 'puppet:///modules/profile/logstash/filter-normalize-log-levels.conf',
        priority => 70,
    }

    logstash::conf { 'filter_de_dot':
        source   => 'puppet:///modules/profile/logstash/filter-de_dot.conf',
        priority => 70,
    }

    logstash::conf { 'filter_es_index_name':
        source   => 'puppet:///modules/profile/logstash/filter-es-index-name.conf',
        priority => 70,
    }

    ## Throttles (rate limiting) (75) (rate limit after filtering for consistency with field conventions)

    logstash::conf { 'filter_throttle':
        source   => 'puppet:///modules/profile/logstash/filter-throttle.conf',
        priority => 75,
    }

    ## Outputs (90)
    # Template for Elasticsearch index creation
    file { '/etc/logstash/elasticsearch-template.json':
        ensure => present,
        source => 'puppet:///modules/profile/logstash/elasticsearch-template.json',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
    }
    # lint:endignore

    logstash::output::elasticsearch { 'logstash':
        host            => '127.0.0.1',
        guard_condition => '"es" in [tags]',
        index           => '%{[@metadata][index_name]}-%{+YYYY.MM.dd}',
        manage_indices  => true,
        priority        => 90,
        template        => '/etc/logstash/elasticsearch-template.json',
        require         => File['/etc/logstash/elasticsearch-template.json'],
    }


    # Output logs tagged "deprecated-input" to eqiad Kafka for ingest by elk7.
    # These are logs that have arrived via a "legacy" (non-kafka) logstash input.
    # The elk7 cluster ingests via Kafka only.
    $kafka_config_eqiad = kafka_config('logging-eqiad')
    logstash::output::kafka{ 'deprecated':
        guard_condition         => '"deprecated-input" in [tags] and "es" in [tags]',
        codec                   => 'json',
        priority                => 90,
        bootstrap_servers       => $kafka_config_eqiad['brokers']['ssl_string'],
        ssl_truststore_location => '/etc/logstash/kafka-logging-truststore-eqiad.jks',
        ssl_truststore_password => $input_kafka_ssl_truststore_passwords['logging-eqiad'],
    }

    # TODO: cleanup -- T256418
    package { 'prometheus-statsd-exporter':
        ensure => 'absent'
    }

    # Alerting
    monitoring::check_prometheus { 'logstash-udp-loss-ratio':
        description     => 'Packet loss ratio for UDP',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/logstash'],
        query           => "sum(rate(node_netstat_Udp_InErrors{instance=\"${::hostname}:9100\"}[5m]))/(sum(rate(node_netstat_Udp_InErrors{instance=\"${::hostname}:9100\"}[5m]))+sum(rate(node_netstat_Udp_InDatagrams{instance=\"${::hostname}:9100\"}[5m])))",
        warning         => 0.05,
        critical        => 0.10,
        method          => 'ge',
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/ops",
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Logstash',
    }

    # Ship logstash server logs to ELK using startmsg_regex pattern to join multi-line events based on datestamp
    # example: [2018-11-30T16:13:48,043]
    rsyslog::input::file { 'logstash-multiline':
        path           => '/var/log/logstash/logstash-plain.log',
        startmsg_regex => '^\\\\[[0-9,-\\\\ \\\\:]+\\\\]',
    }

    mtail::program { 'logstash':
        ensure => present,
        notify => Service['mtail'],
        source => 'puppet:///modules/mtail/programs/logstash.mtail',
    }

    $prometheus_nodes_ferm = join($prometheus_nodes, ' ')
    ferm::service { 'mtail':
        proto  => 'tcp',
        port   => '3903',
        srange => "(@resolve((${prometheus_nodes_ferm})) @resolve((${prometheus_nodes_ferm}), AAAA))",
    }
}
