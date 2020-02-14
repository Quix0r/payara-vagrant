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

# Temporary ZIP file
TEMP_ZIP="/home/vagrant/temp.zip"
TEMP_PWD_FILE="/tmp/pwdfile"

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
	echo "unknown version number '${PAYARA_VERSION}'"
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


# Install OpenJDK8 from Ubuntu repos
installOpenJDK8() {
	echo "Installing OpenJDK 8"
	apt-get -qqy install openjdk-8-jdk            # Install OpenJDK 8
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
	echo "Provisioning Payara-${PAYARA_VERSION} ${PAYARA_ED} to ${PAYARA_HOME}"

	echo "Running update..."
	sudo apt-get -qqy update

	JAVA_BIN=$(which java)

	if [ -z "${JAVA_BIN}" ]
	then
		echo "Installing openjdk and unzip"
		sudo apt-get -y install aptitude || exit 255
		sudo aptitude -y install openjdk-8-jdk unzip mc || exit 255
	else
		echo "OpenJDK already installed."
	fi

	if [ ! -f "${PAYARA_HOME}/payara41/bin/asadmin" ]
	then
		# Make sure temp.zip is really gone
		sudo rm -f "${TEMP_ZIP}" "${TEMP_ZIP}.md5" 
		echo "Downloading Payara ${PAYARA_VERSION}"
		wget -q "${PAYARA_ED}" -O "${TEMP_ZIP}" || exit 255
		wget -q "${PAYARA_ED}.md5" -O "${TEMP_ZIP}.md5" || exit 255

		echo "Validating download ..."
		MD5_SUM1=$(md5sum "${PAYARA_ED}" | cut -d " " -f 1)
		MD5_SUM2=$(cat "${PAYARA_ED}.md5")
		if [ "${MD5_SUM1}" != "${MD5_SUM2}" ]
		then
			echo "MD5 sum '${MD5_SUM1}' doesn't match '${MD5_SUM2}'."
			exit 255
		fi

		if [ -d "${PAYARA_HOME}" ]
		then
			echo "Removing existing directory ..."
			sudo rm -rf "${PAYARA_HOME}"
		fi

		echo "Unzipping Payara ..."
		sudo mkdir -p "${PAYARA_HOME}"
		unzip -qq "${TEMP_ZIP}" -d "${PAYARA_HOME}" || exit 255
		sudo chown -R vagrant:vagrant "${PAYARA_HOME}"
		sudo rm -f "${TEMP_ZIP}" "${TEMP_ZIP}.md5"
	else
		echo "Payara was found."
	fi
}


# Copy startup script, and create service
installService() {
	echo "Installing startup scripts"
	mkdir -p "${PAYARA_HOME}/startup"                    # Make dirs for Payara 
	cp "/vagrant/payara_service-${PAYARA_VERSION}" "${PAYARA_HOME}/startup/" || exit 255
	chmod +x "${PAYARA_HOME}/startup/payara_service-${PAYARA_VERSION}" || exit 255
	sudo ln -sf "${PAYARA_HOME}/startup/payara_service-${PAYARA_VERSION}" /etc/init.d/payara
	sudo ln -sf "${PAYARA_HOME}/payara41/glassfish/domains/domain1" /home/vagrant/domain1

	echo "Adding payara system startup..."
	sudo update-rc.d payara defaults > /dev/null 

	# echo "Starting Payara..."

	# Start default domain
	case "${PAYARA_VERSION}" in
		4.1.2.181)
			sudo /etc/init.d/payara start
			;;
		/*)
			echo "Unknown Payara version, attempting to start domain1..."
			sudo /etc/init.d/payara start
	esac

	echo "Setting logín 'admin' and password 'vagrant' ..."
	echo "AS_ADMIN_PASSWORD=" > "${TEMP_PWD_FILE}"
	echo "AS_ADMIN_NEWPASSWORD=vagrant" >> "${TEMP_PWD_FILE}"
	"${PAYARA_HOME}/payara41/bin/asadmin" --host localhost --port 4848 --user admin --passwordfile="${TEMP_PWD_FILE}" change-admin-password || exit 255
	rm -f "${TEMP_PWD_FILE}"

	# Enable secure admin
	echo "AS_ADMIN_PASSWORD=vagrant" > "${TEMP_PWD_FILE}"
	"${PAYARA_HOME}/payara41/bin/asadmin" --host localhost --port 4848 --user admin --passwordfile="${TEMP_PWD_FILE}" enable-secure-admin || exit 255
	rm -f "${TEMP_PWD_FILE}"

	# Restart default domain
	case "${PAYARA_VERSION}" in
		4.1.2.181)
			sudo /etc/init.d/payara stop || exit 255
			sudo /etc/init.d/payara start
			;;
		/*)
			echo "Unknown Payara version, attempting to start domain1..."
			sudo /etc/init.d/payara stop || exit 255
			sudo /etc/init.d/payara start
	esac
}

configureOSE

if [ "$JDK" = "ORACLE" ]; then
   installOracleJDK8
else
   installOpenJDK8
fi

installPayara

if [ ${PAYARA_ED} = ${WEB}                 ] ||
   [ ${PAYARA_ED} = ${FULL}                ] ||
   [ ${PAYARA_ED} = ${MULTI_LANGUAGE_FULL} ] ||
   [ ${PAYARA_ED} = ${MULTI_LANGUAGE_WEB}  ]; then
	installService
fi

