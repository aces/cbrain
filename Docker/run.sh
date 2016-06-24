#!/bin/bash

function die {
    printf $*
    echo
    exit 1
}


if [ $# != 3 ]
then
   die "usage: run.sh COMMAND MODE PORT\n COMMAND: config|portal|bourreau\n MODE: development|production|test"
fi

echo $*

COMMAND=$1
MODE=$2
PORT=$3


HOST=mysql
if [ "x${MYSQL_HOST}" != "x" ]
then
  HOST=${MYSQL_HOST}
fi
PORT=3306

echo -n "waiting for TCP connection to ${HOST}:${PORT}..."

while ! nc -w 1 ${HOST} ${PORT} 2>/dev/null
do
  echo -n .
  sleep 1
done

echo 'ok'

case ${COMMAND} in
    config )
        
        echo "Configuring"

        # Edits DB configuration file from template
        dockerize -template $HOME/cbrain/Docker/database.yml.TEMPLATE:$HOME/cbrain/BrainPortal/config/database.yml || die "Cannot edit DB configuration file"

        # Edits portal name from template
        dockerize -template $HOME/cbrain/Docker/config_portal.rb.TEMPLATE:$HOME/cbrain/BrainPortal/config/initializers/config_portal.rb || die "Cannot edit CBRAIN configuration file"

        # DB initialization, seeding, and sanity check
        cd $HOME/cbrain/BrainPortal             || die "Cannot cd to BrainPortal directory"
        rake db:schema:load RAILS_ENV=${MODE}   || die "Cannot load DB schema"
        rake db:seed RAILS_ENV=${MODE}          || die "Cannot seed DB"
        rake db:sanity:check RAILS_ENV=${MODE}  || die "Cannot sanity check DB"

        # Plugin installation, portal side
        cd $HOME/cbrain/BrainPortal             || die "Cannot cd to BrainPortal directory"
        rake cbrain:plugins:install:all         || die "Cannot install portal plugins"

        # Plugin installation, bourreau side
        cd $HOME/cbrain/Bourreau                || die "Cannot cd to Bourreau directory"
        rake cbrain:plugins:install:plugins     || die "Cannot install bourreau plugins"
        
        ;;
    portal )
        echo "Starting portal"
        cd $HOME/cbrain/BrainPortal             || die "Cannot cd to BrainPortal directory"
        rails server thin -e ${MODE} -p ${PORT} || die "Cannot start BrainPortal"
        
        ;;
    bourreau )
        echo "Starting bourreau"
        ;;         
esac



