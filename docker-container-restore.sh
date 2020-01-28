#!/bin/bash
  
paramCheck()
{
   echo ""
   echo "Usage: $0 -t restoreLogFile"
   echo -e "\t-t Path of the docker container table log to be restored"
   exit 1 # Exit script after printing help
}

while getopts "t:" opt
do
   case "$opt" in
      t ) logFile="$OPTARG" ;;
      ? ) paramCheck ;; # Print paramCheck in case parameter is non-existent
   esac
done

# Print paramCheck in case parameters are empty
if [ -z "$logFile" ]
then
   echo "Some or all of the parameters are empty";
   paramCheck
fi

# Begin script in case all parameters are correct
COUNT=0
WS_NAME=''
RESTORE_COUNT=0

echo "";
echo "Restoring workspaces";
echo "";

while read p; do
  rem=$(( $COUNT % 2 ))

  if [ $rem -eq 0 ]
  then
    WS_NAME=$p;
  else
    RESTORE_COUNT=$((RESTORE_COUNT + 1));
    CONTAINER_ID=$(/snap/bin/microk8s.docker ps -aqf "name=$WS_NAME");
    RESTORE_FOLDER=$"/restore-$(date +%Y%m%d_%H%M%S)";
    /snap/bin/microk8s.docker exec "$CONTAINER_ID" bash -c "mkdir $RESTORE_FOLDER";
    /snap/bin/microk8s.docker cp "$p"/. "$CONTAINER_ID":/"$RESTORE_FOLDER"/;
    echo "$RESTORE_COUNT"")" "$WS_NAME";
    echo "  source folder $p";
    echo "  container $CONTAINER_ID";
    echo "  restored to folder $RESTORE_FOLDER";
  fi

  COUNT=$((COUNT + 1));
done <$logFile
