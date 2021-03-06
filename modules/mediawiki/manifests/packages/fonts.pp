# == Class: mediawiki::packages::fonts
#
# Provisions font packages used by MediaWiki.
#
class mediawiki::packages::fonts {

    if os_version('debian == jessie') {
        require_package('fonts-noto') # T184664
    }

    if os_version('debian > jessie') {
        require_package(
            'fonts-noto-hinted',  # T184664
            'fonts-noto-unhinted' # T184664
        )
    }

    require_package(
        'fonts-arabeyes',
        'fonts-arphic-ukai',
        'fonts-arphic-uming',
        'fonts-farsiweb',
        'fonts-kacst',
        'fonts-khmeros',
        'fonts-lao',
        'fonts-liberation',
        'fonts-linuxlibertine',
        'fonts-manchufont',
        'fonts-nafees',
        'fonts-sil-abyssinica',
        'fonts-sil-ezra',
        'fonts-sil-padauk',
        'fonts-sil-scheherazade',
        'fonts-takao-gothic',
        'fonts-takao-mincho',
        'fonts-thai-tlwg',
        'fonts-tibetan-machine',
        'fonts-unfonts-core',
        'fonts-unfonts-extra',
        'texlive-fonts-recommended',
        'ttf-alee',
        'ttf-ubuntu-font-family',    # Not in Debian. T32288, T103325
        'ttf-wqy-zenhei',
        'xfonts-100dpi',
        'xfonts-75dpi',
        'xfonts-base',
        'xfonts-mplus',
        'xfonts-scalable',
        'fonts-sil-nuosusil',        # T83288
        'culmus',                    # T40946
        'culmus-fancy',              # T40946
        'fonts-lklug-sinhala',       # T57462
        'fonts-vlgothic',            # T66002
        'fonts-dejavu-core',         # T65206
        'fonts-dejavu-extra',        # T65206
        'fonts-lyx',                 # T40299
        'fonts-crosextra-carlito',   # T84842
        'fonts-crosextra-caladea',   # T84842
        'fonts-smc',                 # T33950
        'fonts-hosny-amiri',         # T135347
        'fonts-taml-tscu',           # T117919
        'fonts-beng',
        'fonts-deva',
        'fonts-gujr',
        'fonts-knda',
        'fonts-mlym',
        'fonts-orya',
        'fonts-guru',
        'fonts-taml',
        'fonts-telu',
        'fonts-gujr-extra',
        'fonts-noto-cjk',
        'fonts-sil-lateef',
        'fonts-ipafont-gothic',
        'fonts-ipafont-mincho',
    )

    # On Ubuntu, fontconfig-config provided a config file which forced antialiasing. This is no
    # longer present in the versions in Debian, so provide it manually since otherwise some fonts
    # look distorted in smaller resolutions: T139543
    file { '/etc/fonts/conf.d/10-antialias.conf':
        source => 'puppet:///modules/mediawiki/fontconfig-antialias.conf',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
    }
}
