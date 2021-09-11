#!/bin/bash
#	Created by DJ Nelson
# 	A script for backing up files with an option to upload to github
# 
# 	This script requires the unix command line tool 'jq' to be installed
#		sudo apt install jq
##

source ~/.bash_colors

helpText() {
        echo -e "Usage: backup [init/run/help] <options>"
        echo "[options]:"
        echo -e "\tinit\t<file_name>\t\tCreate a JSON backup file"
	echo -e "\trun\t<json_file>\t\tStart the backup with specific JSON file configuration"
	echo -e "\tstat\t<json_file>\t\tGet total file size for specific backup configuration"
	echo -e "\thelp\t\t\t\tPrint this help text"

        exit 1
}

initBackupConf() {
	echo "{\"backup_name\":\"$1\",\"backup_directory\":\"$2\",\"files\":\"$3\",\"server\":\"$4\",\"nfs_partition\":\"$5\",\"mount_point\":\"$6\",\"unmount\":\"$7\",\"shred\":\"$8\"}"
}

parseBackupConf() {
	backup_name=$(jq -r '.backup_name' $JSON_FILE_NAME)
	backup_dir=$(jq -r '.backup_directory' $JSON_FILE_NAME)
	files=$(jq -r '.files' $JSON_FILE_NAME)
	server=$(jq -r '.server' $JSON_FILE_NAME)
	nfs_partition=$(jq -r '.nfs_partition' $JSON_FILE_NAME)
	mount_point=$(jq -r '.mount_point' $JSON_FILE_NAME)
	unmount=$(jq -r '.unmount' $JSON_FILE_NAME)
	shred=$(jq -r '.shred' $JSON_FILE_NAME)
}

## COMMAND LINE OPTIONS
OPTION=$1
JSON_FILE_NAME=$2

# check for root privileges
if [ $EUID -ne 0 ]; then
	echo -e "[${RED}!${OFF}] You must be root to run this program!"
	exit 1
fi

# check if jq is installed, otherwise we can't parse JSON
if ! which jq >/dev/null; then
	echo -e "[${RED}!${OFF}] This program requires the unix utility jq in order to run. Would you like to install it now? [y/n]: "
	read input

	# install it for the user if they want
	if [ input == 'y']; then
		apt install jq
	else
		exit 1
	fi
fi

case $OPTION in
	init)
		printf "Specify a configuration file name: "
		read backup_name

		printf "Specify where to store the configuration file (ex. /home/<user>/.config/backup"
		read backup_directory
	
		printf "Please enter a comma-separated list of files: "
		read files

		printf "Please specify a server to backup the archive to: "
		read server

		showmount -e $server
		printf "Please specify the appropriate partition on the server: "
		read nfs_partition
	
		printf "Please select where to mount the NFS server: "
		read mount_point

		printf "Would you like to unmount the backup destination when done? [y/n]: "
		read input
	
		if [ "$input" == "y" ]; then 
			unmount=true
		else
			unmount=false
		fi
	
		printf "Would you like to shred the original archive file? [y/n]: "
		read input2
	
		if [ "$input2" == "y" ]; then
			shred=true
		else
			shred=false
		fi

		initBackupConf $backup_name $backup_directory $files $server $nfs_partition $mount_point $unmount $shred >$backup_directory/$backup_name.json

		echo -e "[$BLUE*${OFF}] Successfully initialized backup job: $backup_name! Configuration data can be found here: $backup_directory/$backup_name.json"
		exit 0
		;;
	run)
		if  ! test -f "$JSON_FILE_NAME"; then
			echo "$JSON_FILE_NAME doesn't exist!"		
			exit 1
		fi

		parseBackupConf $JSON_FILE_NAME
		;;
	stat)
		if ! test -f "$JSON_FILE_NAME"; then
			echo "$JSON_FILE_NAME doesn't exist!"
			exit 1
		fi

		# Get total size of backup
		du -csh $(jq -r '.files' $JSON_FILE_NAME |tr ',' ' ')
		exit 0
		;;
	help)
		helpText
		exit 0
		;;
	*)
		helpText
		exit 1
		;;
esac
	
	

## CONNECTION CHECK
# check if you are able to access the server. If not, you must not be at home
if ! ping -w2 -c1 $server |grep "bytes from $server" >/dev/null; then
	echo -e "[${RED}!${OFF}] Failed to reach $server, you must be away from home. Terminating."
	exit 1
else
	echo -e "[${BLUE}*${OFF}] Successfully reached $server!"
fi

## ARCHIVE
# copy the files to the backup directory and archive them
mkdir ./$backup_name
for file in $(echo $files |tr -s ',' '\n'); do
	if [ -z "$backup_name.json" ]; then
		echo -e "[${RED}!${OFF}] $backup_name doesn't exist!"
	fi
	rsync -ruz $file $backup_name

	if [[ $? -eq 0 ]]; then
		echo -e "[${BLUE}*${OFF}] Copied $file to $backup_name"
	else 
		echo -e "[${RED}!${OFF}] Failed to copy $file to $backup_name"
		exit 1
	fi
done

echo -e "[${GREEN}*${OFF}] Beginning archive of $backup_name"
archive=$backup_name.tar.bz2
tar -cjf $archive $backup_name
if [ $? -eq 0 ]; then
	echo -e "[${BLUE}*${OFF}] Successfully archived $backup_name to $archive!"
	rm -rf ./$backup_name
fi

## MOUNT and BACKUP
mount -t nfs $server:$nfs_partition $mount_point
echo -e "[${BLUE}*${OFF}] Mounted $server:$nfs_partition to $mount_point."
echo -e "[${GREEN}*${OFF}] Copying $archive to $mount_point"
rsync -z $archive $mount_point

if [[ $? -eq 0 ]]; then
	echo -e "[${BLUE}*${OFF}] Successfully backed up ${YELLOW}$archive${OFF} to $server"
else
	echo -e "[${RED}!${OFF}] Failed to back up $archive. Are you able to access the NFS server?"
	exit 1
fi

## CLEAN UP
if $unmount; then
	umount $mount_point
fi

if $shred; then
	shred -uz $archive
fi

echo "Completed at $(date +%T) on $(date +%D)"
