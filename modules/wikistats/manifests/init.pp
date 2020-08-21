# wikistats - a mediawiki statistics site
#
# https://wikistats.wmcloud.org
#
# This sets up a site with statistics about
# as many public MediaWiki installs as possible.
#
# It runs on instance in the 'cloud VPS' project 'wikistats'.
#
# You can control this instance via https://horizon.wikimedia.org
# if you are a member or admin of the project.
#
#
# I will likely stay a labs project forever although
# results from it are used for some statistic tables
# inside Wikipedia and other WMF wikis.
#
# If it goes down it would be missed but it will not cause
# any issues for production wikis. Just some outdated tables.
#
# The matching software is in another repo:
# operations/debs/wikistats which you can clone from Gerrit.
#
# git clone "https://gerrit.wikimedia.org/r/operations/debs/wikistats"
#
# Despite the repo name it is not an actual deb package any longer.
# It gets deployed by simple git clone of PHP files and a local
# deployment script that is also in the repo itself.
#
# This started out as an external project to create
# wiki syntax tables for pages like "List of largest wikis"
# on meta and several similar ones for other projects
#
# Not to be confused with stats.wikimedia.org and wikistats2
# run by the WMF Analytics team.
#
# To report bugs use https://phabricator.wikimedia.org and
# tag a ticket with 'VPS-project-Wikistats'.
#
class wikistats (
    Stdlib::Fqdn $wikistats_host,
) {

    group { 'wikistatsuser':
        ensure => present,
        name   => 'wikistatsuser',
        system => true,
    }

    user { 'wikistatsuser':
        home       => '/usr/lib/wikistats',
        groups     => 'wikistatsuser',
        managehome => true,
        system     => true,
    }

    file { '/srv/wikistats':
        ensure => 'directory',
        owner  => 'wikistatsuser',
        group  => 'wikistatsuser',
    }

    # directory used by deploy-script to store backups
    file { '/usr/lib/wikistats/backup':
        ensure  => 'directory',
        owner   => 'wikistatsuser',
        group   => 'wikistatsuser',
        require => User['wikistatsuser'],
    }

    file { '/usr/local/bin/wikistats':
        ensure => 'directory',
    }

    # deployment script that copies files in place after puppet git clones to /srv/
    file { '/usr/local/bin/wikistats/deploy-wikistats':
        ensure => 'present',
        owner  => 'root',
        group  => 'root',
        mode   => '0544',
        source => 'puppet:///modules/wikistats/deploy-wikistats.sh',
    }

    # FIXME rename repo, it was a deb in the past
    # but not anymore and also not operations
    git::clone { 'operations/debs/wikistats':
        ensure    => 'latest',
        directory => '/srv/wikistats',
        branch    => 'master',
        owner     => 'wikistatsuser',
        group     => 'wikistatsuser',
    }

    # webserver setup for wikistats
    class { 'wikistats::web':
        wikistats_host => $wikistats_host,
    }

    $db_pass = fqdn_rand_string(23, 'Random9Fn0rd8Seed')

    # install a db on localhost
    class { 'wikistats::db':
        db_pass => $db_pass,
    }

    # scripts and crons to update data and dump XML files
    file { '/var/www/wikistats/xml':
        ensure => directory,
        owner  => 'wikistatsuser',
        group  => 'wikistatsuser',
        mode   => '0644',
    }

    class { 'wikistats::updates':
        db_pass => $db_pass,
    }
}

