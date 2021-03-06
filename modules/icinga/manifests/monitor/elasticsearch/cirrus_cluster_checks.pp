# == Class icinga::monitor::elasticsearch::cirrus_cluster_checks
class icinga::monitor::elasticsearch::cirrus_cluster_checks{
    $ports = [9243, 9443, 9643]
    $sites = ['eqiad', 'codfw']
    $scheme = 'https'

    $sites.each |$site| {
        $host = "search.svc.${site}.wmnet"
        icinga::monitor::elasticsearch::base_checks { $host:
            host   => $host,
            scheme => $scheme,
            ports  => $ports,
        }

        icinga::monitor::elasticsearch::cirrus_checks { $host:
            host   => $host,
            scheme => $scheme,
            ports  => $ports,
        }

        # Alert on mjolnir daemons - T214494
        monitoring::check_prometheus { "mjolnir_bulk_update_failure_${site}":
            description     => "Mjolnir bulk update failure check - ${site}",
            dashboard_links => ['https://grafana.wikimedia.org/d/000000591/elasticsearch-mjolnir-bulk-updates?orgId=1&from=now-7d&to=now&panelId=1&fullscreen'],
            query           => 'sum(irate(mjolnir_bulk_action_total{result="failed"}[5m]))/sum(irate(mjolnir_bulk_action_total[5m]))',
            prometheus_url  => "http://prometheus.svc.${site}.wmnet/ops",
            nan_ok          => true,
            method          => 'gt',
            critical        => 0.01, # 1%
            warning         => 0.005, # 0.5%
            contact_group   => 'admins,team-discovery',
            notes_link      => 'https://phabricator.wikimedia.org/T214494',
        }

        # this is checking for update rate over the last 60 minutes. Ideally, we'd like a shorter window for this
        # check, but T224425 makes it generate too much noise.
        # FIXME: reduce moving average to 10 minutes once T224425 is fixed.
        monitoring::graphite_threshold { "mediawiki_cirrus_update_rate_${site}":
            description     => "Mediawiki Cirrussearch update rate - ${site}",
            dashboard_links => ['https://grafana.wikimedia.org/d/JLK3I_siz/elasticsearch-indexing?panelId=44&fullscreen&orgId=1'],
            host            => $host,
            metric          => "movingAverage(transformNull(MediaWiki.CirrusSearch.${site}.updates.all.sent.rate),\"60minutes\")",
            warning         => 80,
            critical        => 50,
            under           => true,
            contact_group   => 'admins,team-discovery',
            notes_link      => 'https://wikitech.wikimedia.org/wiki/Search#No_updates',
        }
    }
}
