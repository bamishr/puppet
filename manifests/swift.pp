# swift.pp

class swift::base {

	package { "swift":
		ensure => present;
	}

	file { "/etc/swift":
			ensure => directory,
			recurse => true,
			owner => swift,
			group => swift,
			mode => 0444;
		"/etc/swift/swift.conf":
			ensure => present,
			source => "puppet:///files/swift/etc.swift.conf",
			owner => swift,
			group => swift,
			mode => 0444;
	}

}

class swift::proxy {
	include swift::base
	system_role { "swift:base": description => "swift frontend proxy" }

	package { [ "swift-proxy", "memcached" ]:
		ensure => present;
	}

	file { "/etc/swift/cert.crt":
			ensure => present,
			source => "puppet:///private/swift/cert.crt",
			owner => swift,
			group => swift,
			mode => 0444;
		"/etc/swift/cert.key":
			ensure => present,
			source => "puppet:///private/swift/cert.key",
			owner => swift,
			group => swift,
			mode => 0444;
	}

	file { "/etc/memcached.conf":
			ensure => present,
			source => "puppet:///files/swift/memcached.conf",
			owner => root,
			group => root,
			mode => 0444;
	}
}

class swift::proxy::testclusterconf {
	# because I can't figure out how to aggregate a list of all proxy servers
	# within puppet and use that list in a template, I have a different config
	# file for each swift cluster so that they can use their own memcached 
	# instances.
	
	file { "/etc/swift/proxy-server.conf":
			ensure => present,
			source => "puppet:///files/swift/proxy-server.conf-testcluster",
			owner => swift,
			group => swift,
			mode => 0444;
	}
}

class swift::storage {
	include swift::base
	system_role { "swift::storage": description => "swift backend storage brick" }

	package { 
		[ "swift-account",
		  "swift-container",
		  "swift-object" ]:
		ensure => present;
	}

}


