#!/bin/bash

function copyMysqlToTemp(){
  cp -a /var/lib/mysql /tmp
  chown -R mysql:mysql /tmp/mysql
  /etc/init.d/mysql start
}

function backup(){
  backupfile="/backup/$(date '+%Y-%m-%d').sql.7z"

  if [[ -f $backupfile ]]
    then rm "${backupfile}"
  fi

  if [[ -z $MYSQLSERVER_NAME ]]
    then backup_local
    else backup_remote
  fi
  chown -R user1000:user1000 /backup
}

function backup_remote(){
  echo "Backup remote database"
  if [[ -z ${DATABASE} ]]
    then mysqldump -h mysqlserver -u ${DBUSER:-root} --password=${DBPASS:-""} --max_allowed_packet=512m --add-drop-database --all-databases | 7zr a -si "${backupfile}"
    else mysqldump -h mysqlserver -u ${DBUSER:-root} --password=${DBPASS:-""} --max_allowed_packet=512m --add-drop-database --databases ${DATABASE} | 7zr a -si "${backupfile}"
  fi
}

function backup_local(){
  echo "Backup local database"
  copyMysqlToTemp
  if [[ -z ${DATABASE} ]]
    then mysqldump -u ${DBUSER:-root} --password=${DBPASS:-""} --max_allowed_packet=512m --add-drop-database --all-databases | 7zr a -si "${backupfile}"
    else mysqldump -u ${DBUSER:-root} --password=${DBPASS:-""} --max_allowed_packet=512m --add-drop-database --databases ${DATABASE} | 7zr a -si "${backupfile}"
  fi
}

function restore(){
  if [[ -z $MYSQLSERVER_NAME ]]
    then restore_local
    else restore_remote
  fi
}

function restore_remote(){
  echo "Restore remote database"
  7zr x -so "/backup/${SOURCE}" | mysql -h mysqlserver -u ${DBUSER:-root} --password=${DBPASS}
}

function restore_local(){
  echo "Restore local database"
  MYSQL_UID=$(stat -c %u /var/lib/mysql)
  MYSQL_GID=$(stat -c %g /var/lib/mysql)
  copyMysqlToTemp
  7zr x -so "/backup/${SOURCE}" | mysql -u ${DBUSER:-root} --password=${DBPASS:-""}
  /etc/init.d/mysql stop

  rm -rf /var/lib/mysql/*
  cp -a /tmp/mysql/* /var/lib/mysql
  chown -R ${MYSQL_UID}:${MYSQL_GID} /var/lib/mysql
}

if [[ $1 = "backup" ]]
   then backup
elif [[ $1 = "restore" ]]
  then restore
  else echo "Call with 'backup' or 'restore'"
fi
