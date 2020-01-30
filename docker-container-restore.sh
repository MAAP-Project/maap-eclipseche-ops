#!/bin/bash
  
paramCheck()
{
   echo ""
   echo "Usage: $0 -t restoreLogFile -v /mountedVolume"
   echo -e "\t-t Path of the docker container table log to be restored"
   echo -e "\t-v The mounted volume from where the source files exist, including slash (e.g., /restore)"
   exit 1 # Exit script after printing help
}

while getopts "t:v:" opt
do
   case "$opt" in
      t ) logFile="$OPTARG" ;;
      v ) mountedVolume="$OPTARG" ;;
      ? ) paramCheck ;; # Print paramCheck in case parameter is non-existent
   esac
done

# Print paramCheck in case parameters are empty
if [ -z "$logFile" ] || [ -z "$mountedVolume"  ]
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

    #Use the container name up to the first period, which is the WS identifier that persists across restarts
    CONTAINER_NAME=$(echo $WS_NAME | cut -f1 -d".");

    #Get the container Id from the container name 
    CONTAINER_ID=$(/snap/bin/microk8s.docker ps -qf "name=$CONTAINER_NAME");
    SOURCE_FOLDER=$"$mountedVolume$p";
    RESTORE_FOLDER=$"/restore-$(date +%Y%m%d_%H%M%S)";

    #Create restore folder inside container
    /snap/bin/microk8s.docker exec "$CONTAINER_ID" bash -c "mkdir $RESTORE_FOLDER";

    #Copy restored files to container
    /snap/bin/microk8s.docker cp "$SOURCE_FOLDER"/. "$CONTAINER_ID":/"$RESTORE_FOLDER"/;

    #Report status
    echo "$RESTORE_COUNT"")" "$WS_NAME";
    echo "  source folder $p";
    echo "  container $CONTAINER_ID";
    echo "  restored to folder $RESTORE_FOLDER";
  fi

  COUNT=$((COUNT + 1));
done <$logFile
