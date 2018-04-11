#!/bin/bash
SCRIPTDIR=$(dirname "$0")
DATE=$( date +%d-%m-%y )

# Clean all cached metadate. Update the repos & packages.
yum clean metadata
yum clean all
yum check-update
yum update

# Install needed packages
yum -y install \
    httpd \
    php \
    wget \
    yum-plugin-priorities \
    deltarpm


###################################
#
# Set up Shibboleth
#
###################################

# Set up repository
wget \
    https://shibboleth.net/cgi-bin/sp_repo.cgi?platform=CentOS_7 \
    -O /etc/yum.repos.d/shibboleth.repo

# Install shibboleth
yum -y install shibboleth.x86_64

# Shibboleth is using some custom versions of a couple of
# libraries. Make sure the get used.
if ( shibd -t | grep "libcurl lacks OpenSSL-specific options" )
then
    echo "Include Shibboleth's custom libraries."
    echo "/opt/shibboleth/lib64" | tee "/etc/ld.so.conf.d/opt-shibboleth.conf"
    ldconfig

    shibd -t | grep "libcurl lacks OpenSSL-specific options" \
        && "Including libraries failed. Continuing anyway."
fi

# Create a backup of the config files we will change
cp "/etc/shibboleth/shibboleth2.xml" "/etc/shibboleth/shibboleth2.backup-$DATE.xml"
cp "/etc/shibboleth/attribute-map.xml" "/etc/shibboleth/attribute-map.xml.backup-$DATE.xml"

# Overwrite the config files with our settings
cp "$SCRIPTDIR/conf/shibboleth2.xml"  "/etc/shibboleth/shibboleth2.xml"
cp "$SCRIPTDIR/conf/attribute-map.xml"  "/etc/shibboleth/attribute-map.xml"


###################################
#
# Set up SSL for Apache
#
###################################

# Install Apache's mod_ssl
yum -y install mod_ssl openssl

# Debianize CentOs' Apache config a little:
# Create folders for sites / vhost configuration files. Copy
# SSL config and enable it by soft linking it from sites-available
# sites-enabled
mkdir -p "/etc/httpd/sites-available"
mkdir -p "/etc/httpd/sites-enabled"
cp "$SCRIPTDIR/conf/001-default-ssl.conf" "/etc/httpd/sites-available"
ln -s "../sites-available/001-default-ssl.conf" "/etc/httpd/sites-enabled/002-default-ssl.conf"

# Add including the sites' configurations in the main configuration
# file. Check if that has not been done before.
if ( grep "sites-enabled" "/etc/httpd/conf/httpd.conf" )
then
    # Create a backup of the original configuration
    cp "/etc/httpd/conf/httpd.conf" "/etc/httpd/conf/httpd.backup-$DATE.conf"

    # Add IncludeOptional statement
    echo "" >> "/etc/httpd/conf/httpd.conf"
    echo "# Include sites / vhosts" >> "/etc/httpd/conf/httpd.conf"
    echo "IncludeOptional sites-enabled/*.conf" >> "/etc/httpd/conf/httpd.conf"
fi

# Create the test certificates
mkdir -p "/etc/httpd/ssl-certs"
/etc/ssl/certs/make-dummy-cert "/etc/httpd/ssl-certs/server-ca.crt"

# Make a test folter
mkdir -p "/var/www/html/secure"
echo "Hello world." | tee "/var/www/html/secure/index.html"


###################################
#
# Restart the services
#
###################################

apachectl start
systemctl start shibd.service


###################################
#
# Print out some extra
# information
#
###################################
