#! /bin/bash

# regular script
# pravidelne sa spustajuci skript, ktory porovnava hash suborov s hashom z predchadzajuceho dna a vysledky posiela mailom

FOLDER="/etc/check"
FOLDERS=""
CONFIG_FILE="/etc/check/folders.conf"
RESULTS_FILE="/etc/check/results"
MAIL_FILE="/etc/check/mail.conf"
RESULTS_FILE_HASH="/etc/check/results_hash"
SCRIPT_FILE="/usr/bin/check-regular-script.sh"
EMAIL=""
FOLDERS_INDEX="1"
TMPFILE="/tmp/regular-script.sh.$$"

function __mail__
{ 
	# $1 - subject, $2 - data
	echo -e "$2" | mail -s "$1" $EMAIL
}

function __checkMail__
{
	# ak neexistuje zaznam o mailovej schranke, logguje do syslogu
	if ! [ -f "$MAIL_FILE" ]
	then
		echo "$MAIL_FILE does not exist, but folder $FOLDER exists. Writing to syslog and exiting."
		logger -t "$SCRIPT_FILE" "$MAIL_FILE does not exist. Therefore, cannot send notification mails. Beware of intruders trying to get around this program!"
		exit 2		
	fi
	EMAIL=$(cat "$MAIL_FILE")
	if ! [[ "$EMAIL" =~ ^[[:alnum:]]+@[[:alnum:]]+$ ]] # ^[+]?[0-9]+([.][0-9]+)?$ ]] 
	then
		echo "$MAIL_FILE contains invalid email address. Writing to syslog and exiting."
		logger -t "$SCRIPT_FILE" "$MAIL_FILE contains invalid email address. Therefore, cannot send notification mails. Beware of intruders trying to get around this program!"
		exit 2
	fi
}

function __checkFiles__
{
	# informacia o schranke uzivatela urcite existuje => je mozne poslat mail
	for current_file in $CONFIG_FILE $RESULTS_FILE $RESULTS_FILE_HASH	
	do
		if ! [ -f "$current_file" ]
		then
		{
			echo "$current_file does not exist, but folder $FOLDER exists. Sending a warning mail and exiting."
			__mail__ "$current_file does not exist" "$FOLDER does not contain $current_file. Beware of intruders trying to get around this program!"
			exit 2
		}	
		fi	
	done
}

function __loadFolders__
{
	while read LINE
	do
		if [ -d "$LINE" ] # ignoring invalid folders
		then
			FOLDERS[$FOLDERS_INDEX]=$LINE
		fi
		FOLDERS_INDEX=$((FOLDERS_INDEX+1))
	done < "$CONFIG_FILE"
}

function __displayFolders__
{
	echo "List of periodically checked folders:"
	echo "${FOLDERS[@]}"
}

function __compareHashes__
{
	# urcite existuju vsetky potrebne subory, najma "results_hash" a "results"
	local new_hash=$(md5sum "$RESULTS_FILE" | cut -d' ' -f1)
	local old_hash=$(cat "$RESULTS_FILE_HASH")
	if ! [[ "$new_hash" = "$old_hash" ]]
	then
		echo "Hash included in $RESULTS_FILE_HASH varies from the hash calculated of $RESULTS_FILE. Sending a warning mail and exiting."
		__mail__ "Hashes do not match" "Hash included in $RESULTS_FILE_HASH varies from the hash calculated of $RESULTS_FILE. Beware of intruders trying to get around this program!"
		exit 2
	fi
}

function __createHashes__
{
	local file_date=""
	local file_time=""
	local file_name=""
	local ls_output=""
	local files_added="0"
	local files_changed="0"
	local files_deleted="0"
	local results_new="/tmp/regular-script.sh.new$$"
	local results_old="/tmp/regular-script.sh.old$$"
	awk 	'{
			for (i=1; i<NF; i++)
			{
				if (i == (NF-1))
					printf ("%s", $i)
				else
					printf ("%s ", $i)
			}
			print ""
		 }' $RESULTS_FILE > "$results_old"
	touch $TMPFILE
	for ((I=1; I<FOLDERS_INDEX; I++))
	do
		currentFolder=${FOLDERS[${I}]}
		echo "Folder $currentFolder is being checked..."
		currentFiles="$currentFolder*"
		for J in $currentFiles
		do
			if [ -f "$J" ]
			then
			{
				# vytvaram docasny subor podobny /etc/check/results, ale obsahuje pouze nazov suborun na kazdom riadku
				echo "$J" >> $results_new
				#/etc/check/results v tvare: subor hash_suboru
				new_hash=$(md5sum "$J" | cut -d' ' -f1)				# cerstvy hash
				old_hash=$(grep "$J" "$RESULTS_FILE")				# existoval tento subor pri poslednej kontrole?
				if [[ "$?" -eq 0 ]]
				then
				{
					old_hash=$(echo $old_hash | awk '{print $NF}')		# predchadzajuci hash
					if ! [[ "$new_hash" = "$old_hash" ]]
					then
					{
						echo "$J ...CHANGED..."
						files_changed=$((files_changed+1))
						ls_output=$(ls -la --time-style="+%Y%m%d %H:%M:%S" "$J")
						file_date=$(echo $ls_output | cut -d' ' -f6)
						file_time=$(echo $ls_output | cut -d' ' -f7)
						file_name=$(echo $ls_output | cut -d' ' -f8)
						echo "CHG $file_date $file_time $file_name" >> $TMPFILE
					}
					else
						echo "$J ...OK..."
					fi
				}
				else
				{
					echo "$J ...ADDED..."
					files_added=$((files_added+1))
					ls_output=$(ls -la --time-style="+%Y%m%d %H:%M:%S" "$J")
					file_date=$(echo $ls_output | cut -d' ' -f6)
					file_time=$(echo $ls_output | cut -d' ' -f7)
					file_name=$(echo $ls_output | cut -d' ' -f8)
					echo "ADD $file_date $file_time $file_name" >> $TMPFILE
				}
				fi
			}
			fi			
		done
	done
	# po spracovani vsetkych aktualnych suborov, mozeme zistit ktore subory boli v porovnani s predchadzajucom verziou zmazane
	sort "$results_old" > "${results_old}_backup"
	sort "$results_new" > "${results_new}_backup"
	mv ${results_old}_backup ${results_old}
	mv ${results_new}_backup ${results_new}
	for file_name in "`comm -23 "$results_old" "$results_new"`"
	do
		if ! [ -z "$file_name" ]
		then
			echo "$file_name ...DELETED..."
			files_deleted=$((files_deleted+1))
			echo -e "DEL \t\t      $file_name" >> $TMPFILE
		fi
	done
	echo -e "\nTime & date: `date`.\nAdded files: $files_added.\nChanged files: $files_changed.\nDeleted files: $files_deleted.\nCurrent logfile:\n================\n`cat $TMPFILE`"
	__mail__ "/usr/bin/check - regular check" "Time & date: `date`.\nAdded files: $files_added.\nChanged files: $files_changed.\nDeleted files: $files_deleted.\nCurrent logfile:\n================\n`cat $TMPFILE`"
	#rm -rf "$results_new"
	#rm -rf "$results_old"
}

function __recalculateHashes__
{
	local resultant_hash=""
	local currentFiles=""

	# opatovna kontrola
	echo "Recalculating hashes..."
	rm -rf $RESULTS_FILE
	rm -rf $RESULTS_FILE_HASH
	for I in ${FOLDERS[@]}
	do
		echo "Folder $I is being checked..."
		currentFiles="$I*"
		for J in $currentFiles
		do
			#echo "Calculating hash of $J"
			if [ -f "$J" ]
			then
				# vypocitaj hash pouze zo suborov v danom adresari
				hash=$(md5sum "$J" | cut -d' ' -f1)
				echo "Filename: $J, hash: $hash"
				echo "$J $hash" >> $RESULTS_FILE 
			fi
		done 
	done
	
	# spocitaj hash samotneho suboru s obsahom hashe
	resultant_hash=$(md5sum "$RESULTS_FILE" | cut -d' ' -f1)
	echo "$resultant_hash" > $RESULTS_FILE_HASH
}

if [[ "$UID" -ne 0 ]]
then
	echo "Elevate your privileges to super-user account! Exiting."
	exit 1
fi

if ! [ -d "$FOLDER" ]
then
	echo "$FOLDER does not exist. Run init-script.sh first! Exiting."
	exit 1
fi

__checkMail__		# najskor skontroluj emailovu adresu; ak neexistuje -> warning ho syslogu
__checkFiles__		# ak email existuje, pripadne chyby zasielat nan
__loadFolders__		# nacitaj zoznam adresarov, ktorych obsah sa budem kontrolovat hashovanim
__displayFolders__
__compareHashes__	# kontrola integrity suboru $RESULTS_FILE
__createHashes__
__recalculateHashes__

#rm -rf "$TMPFILE"
exit 0
