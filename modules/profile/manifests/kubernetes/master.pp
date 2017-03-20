class profile::kubernetes::master(
    $etcd_urls=hiera('profile::kubernetes::master::etcd_urls'),
    $kubenodes=hiera('profile::kubernetes::master::kubenodes'),
    $docker_registry=hiera('profile::kubernetes::master::docker_registry'),
    $service_cluster_ip_range=hiera('profile::kubernetes::master::service_cluster_ip_range'),
    $apiserver_count=hiera('profile::kubernetes::master::apiserver_count'),
    $admission_controllers=hiera('profile::kubernetes::master::admission_controllers'),
    $expose_puppet_certs=hiera('profile::kubernetes::master::use_puppet_certs'),
    $ssl_cert_path=hiera('profile::kubernetes::master::ssl_cert_path'),
    $ssl_key_path=hiera('profile::kubernetes::master::ssl_cert_path'),
    $authz_mode=hiera('profile::kubernetes::master::authz_mode'),
    $host_automounts=hiera('profile::kubernetes::master::host_automounts'),
    $host_path_prefixes_allowed=hiera('profile::kubernetes::master::host_path_prefixes_allowed'),
){
    if $expose_puppet_certs {
        base::expose_puppet_certs { '/etc/kubernetes':
            provide_private => true,
            user            => 'kubernetes',
            group           => 'kubernetes',
        }
    }

    $etcd_servers = join($etcd_urls, ',')
    class { '::k8s::apiserver':
        use_package                => true,
        etcd_servers               => $etcd_servers,
        docker_registry            => $docker_registry,
        ssl_cert_path              => $ssl_cert_path,
        ssl_key_path               => $ssl_key_path,
        authz_mode                 => $authz_mode,
        service_cluster_ip_range   => $service_cluster_ip_range,
        apiserver_count            => $apiserver_count,
        admission_controllers      => $admission_controllers,
        host_path_prefixes_allowed => $host_path_prefixes_allowed,
        host_automounts            => $host_automounts,
    }

    class { '::k8s::scheduler': use_package => true }
    class { '::k8s::controller': use_package => true }

    $kubenodes_ferm = join($kubenodes, ' ')

    ferm::service { 'apiserver-https':
        proto  => 'tcp',
        port   => '6443',
        srange => "(@resolve((${kubenodes_ferm})))",
    }

    diamond::collector { 'Kubernetes':
        source => 'puppet:///modules/diamond/collector/kubernetes.py',
    }
}
