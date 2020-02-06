#!/bin/bash

##########################################
#
# Setting properties
#

# Which JDK to use (OPENJDK or ORACLE)
JDK="OPENJDK"

# Payara Version
PAYARA_VERSION="4.1.2.181"

# Payara directory
PAYARA_HOME="/opt/payara/payara-${PAYARA_VERSION}"

# Payara Edition URLs
case "${PAYARA_VERSION}" in 
	4.1.2.181)
		# The below links are to 4.1.2.181
		FULL="https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/4.1.2.181/payara-4.1.2.181.zip"
		WEB="https://search.maven.org/remotecontent?filepath=fish/payara/blue/distributions/payara-web/4.1.2.181/payara-web-4.1.2.181.zip"
		MINIMAL=""
		MICRO=""
		EMBEDDED_FULL=""
		EMBEDDED_WEB=""
		MULTI_LANGUAGE_FULL="https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara-ml/4.1.2.181/payara-ml-4.1.2.181.zip"
		MULTI_LANGUAGE_WEB="https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara-web-ml/4.1.2.181/payara-web-ml-4.1.2.181.zip"
	;;
	\*)
		echo "unknown version number"
esac

# Payara edition (Full, Web, Micro, etc., from above list)
PAYARA_ED="${FULL}"

#
#
##########################################


# Configure the operating system environment
configureOSE() {
	echo "Configuring operating system"

	echo "running update..."
	apt-get -qqy update                           # Update the repos

	echo "installing unzip"
	apt-get -qqy install unzip                    # Install unzip
}


# Install OpenJDK7 from Ubuntu repos
installOpenJDK7() {
	echo "Installing OpenJDK 7"
	apt-get -qqy install openjdk-7-jdk            # Install OpenJDK 7
}


# Install Oracle JDK8 via PPA from webupd8.org
installOracleJDK8() {
	echo "Installing OracleJDK 8"

        # Automate the Oracle JDK license acceptence
	echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections

	add-apt-repository -y ppa:webupd8team/java    # Register the PPA
	apt-get -qqy update                           # Update the repos
	apt-get -qqy install oracle-java8-installer   # Install Oracle JDK 8
}


# Download and unzip to /opt/payara
installPayara() {
	echo "Provisioning Payara-$PAYARA_VERSION $PAYARA_ED to $PAYARA_HOME"

	echo "Downloading Payara $PAYARA_VERSION"
	wget -q $PAYARA_ED -O temp.zip > /dev/null    # Download Payara
	mkdir -p $PAYARA_HOME                         # Make dirs for Payara
	unzip -qq temp.zip -d $PAYARA_HOME            # unzip Payara to dir
	rm temp.zip                                   # cleanup temp file

	echo "Enabling secure admin mode for domains (u/p = admin/payara0payara)"
	PWDFILE=/tmp/pwdfile
	DOMAINS_DIR="${PAYARA_HOME}/payara41/glassfish/domains"
	echo "AS_ADMIN_PASSWORD=payara0payara" > ${PWDFILE}
	for DOMAIN in domain1 payaradomain; do
		echo "admin;{SSHA256}Rzyr/2/C1Zv+iZyIn/VnL0zDYESs8nTH8t/OMlOpazehMGn5L9ejkg==;asadmin" > "${DOMAINS_DIR}/${DOMAIN}/config/admin-keyfile"
		${PAYARA_HOME}/payara41/bin/asadmin start-domain ${DOMAIN}
		${PAYARA_HOME}/payara41/bin/asadmin --user admin --passwordfile "${PWDFILE}" enable-secure-admin
		${PAYARA_HOME}/payara41/bin/asadmin stop-domain ${DOMAIN}
	done
	rm "${PWDFILE}"
	
	echo "Setting ownership of ${PAYARA_HOME} content"
	chown -R vagrant:vagrant $PAYARA_HOME         # Make sure vagrant owns dir
}


# Copy startup script, and create service
installService() {
	echo "installing startup scripts"
	mkdir -p ${PAYARA_HOME}/startup                 # Make dirs for Payara
	cp /vagrant/payara_service-${PAYARA_VERSION} ${PAYARA_HOME}/startup/
	chmod +x ${PAYARA_HOME}/startup/payara_service-${PAYARA_VERSION}
	ln -s ${PAYARA_HOME}/startup/payara_service-${PAYARA_VERSION} /etc/init.d/payara
	
	echo "Adding payara system startup..."
	update-rc.d payara defaults > /dev/null 
	
	echo "Starting Payara..."
	
	# Explicitly start payaradomain by default
	case "${PAYARA_VERSION}" in
		4.1.2.181)
			su - vagrant -c 'service payara start payaradomain'
			;;
		/*)
			echo "Unknown Payara version, attempting to start domain1..."
			su - vagrant -c 'service payara start domain1'
	esac
}

configureOSE

if [ "$JDK" = "ORACLE" ]; then
   installOracleJDK8
else
   installOpenJDK7
fi

installPayara

if [ ${PAYARA_ED} = ${WEB}                 ] ||
   [ ${PAYARA_ED} = ${FULL}                ] ||
   [ ${PAYARA_ED} = ${MULTI_LANGUAGE_FULL} ] ||
   [ ${PAYARA_ED} = ${MULTI_LANGUAGE_WEB}  ]; then
	installService
fi

