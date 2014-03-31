#!/bin/bash

SCRIPT_DIR=`dirname $0`

SERVER=searchbrew.com
TARGET=/home/searchbrew
SERVICE_SERVER=searchbrew
INIT_SERVER_CONF=searchbrew.conf
APACHE_CONF=searchbrew.com
USER=searchbrew
ES_DOWNLOAD=https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.1.0.deb
ES_FILE=elasticsearch-1.1.0.deb

cd $SCRIPT_DIR/../server
sbt clean stage
cd ..

ssh $SERVER <<EOF
	sudo service $SERVICE_SERVER stop

	# if [ ! -f $TARGET ]; then
	# 	sudo adduser $USER
	# fi

	# install required
	#sudo add-apt-repository ppa:webupd8team/java
	#sudo apt-get update
	sudo apt-get -y install apache2 unattended-upgrades oracle-java7-installer oracle-java7-set-default git

	sudo a2enmod proxy_http
	sudo a2enmod rewrite

	if [ ! -f $ES_FILE ]; then
		wget $ES_DOWNLOAD
		sudo dpkg -i $ES_FILE
		echo "ES_HEAP_SIZE=256m" >> /etc/default/elasticsearch
		sudo update-rc.d elasticsearch defaults
	fi
EOF

ssh $USER@$SERVER <<EOF
	mkdir -p $TARGET/logs
	mkdir -p $TARGET/server/dist
EOF

rsync -v --recursive --delete --compress $SCRIPT_DIR/../server/target/universal/stage/ $USER@$SERVER:/$TARGET/server/dist/

ssh $USER@$SERVER <<EOF
	ln -s $TARGET/logs $TARGET/server/dist
EOF

scp $SCRIPT_DIR/$INIT_SERVER_CONF $SERVER:.
scp $SCRIPT_DIR/$APACHE_CONF $SERVER:.

ssh $SERVER <<EOF
	sudo mv $INIT_SERVER_CONF /etc/init/
	sudo mv $APACHE_CONF /etc/apache2/sites-available
	sudo a2ensite $APACHE_CONF
	sudo service apache2 reload
	sudo service elasticsearch start
	sudo service $SERVICE_SERVER start
EOF
