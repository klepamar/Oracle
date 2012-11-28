#! /bin/bash

# initial script
# cielom je vydefinovat a ulozit zoznam adresarov, ktore sa budu kontrolovat

FOLDER="/etc/check/"
CONFIG_FILE="/etc/check/folders.conf"
RESULTS_FILE="/etc/check/results"
MAIL_FILE="/etc/check/mail.conf"
RESULTS_FILE_HASH="/etc/check/results_hash"
SCRIPT_FILE="/usr/bin/check-regular-script.sh"
EMAIL=""
FOLDERS[0]="/usr/local/bin/"
FOLDERS[1]="/usr/sbin/"
FOLDERS[2]="/usr/bin/"
FOLDERS[3]="/sbin/"
FOLDERS[4]="/bin/"

function __mail__
{ 
	# $1 - subject, $2 - data
	echo "$2" | mail -s "$1" $EMAIL
}

function __displayFolders__
{
	echo "List of periodically checked folders:"
	echo "${FOLDERS[@]}"
}

function __displayHelp__
{
	echo "Run this script as a super-user and list folders which are going to be checked periodically against changes. Notification emails will be sent to address provided."
	echo "# ./init-script.sh /absolute/path/to/folders email-address."
	echo "Examples:"
	echo "# ./init-script.sh /bin /sbin /root root@localhost"
	echo "# ./init-script.sh root@localhost"
}

# pociatocna kontrola parametrov, ak uzivatel nespecifikoval adresar, pouzije sa vychodzia mnozina adresarov

if [[ "$UID" -ne 0 ]]
then
	echo "Elevate your privileges to super-user account! Exiting."
	exit 1
fi

if [[ "$#" -eq 0 ]]
then
	__displayHelp__
	echo "Missing email address parameter! Exiting."
	exit 1
else
	isAnyFolderParameter=""
	# zisti ci uzivatel ziadal o zobrazenie debug modu alebo chce zobrazit help mod
	for I in "$@"
	do
		if [ "$I" = "-h" ] || [ "$I" = "--help" ] 	
		then	
			__displayHelp__
			exit 0
		else
			isAnyFolderParameter="1"
		fi
	done

	# spracovanie posledneho parametru (=mailovej adresy)
	EMAIL=${!#}
	echo "Email parameter: ${!#}"
	if ! [[ "$EMAIL" =~ ^[[:alnum:]]+@[[:alnum:]]+$ ]] # ^[+]?[0-9]+([.][0-9]+)?$ ]] 
	then
		echo "Incorrect format of email address! Exiting."
		exit 1
	fi

	# samotne spracovanie parametrov (premenna "isAnyFolderParameter" udava, ze nejaky parameter predstavuje adresar, a teda sa nepouzije defaultne nastavenia folderov, ktore sa tak mozu zahodit
	[[ -z "$isAnyFolderParameter" ]] || unset FOLDERS
	i=1
	folderCount=0
	tempFolderName=""
	while true
	do
		if [ $1 ] 
		then
			if [[ "$1" = "$EMAIL" ]]
			then # skript kontroluje posledny parameter
			{			
				break
			}			
			# kontrola parametra na test "is directory?"	
			elif [ -d "$1" ]
			then # ak uzivatel zadal adresar bez koncoveho "/", tento znak doplnime
			{	
				tempFolderName="$1"
				tempFolderName=$(echo ${tempFolderName%\/})
				tempFolderName=$tempFolderName"/"
				#echo "$tempFolderName is a valid directory"
				#echo "adding to a list of directories at position: $folderCount"
				FOLDERS[${folderCount}]=$tempFolderName
				folderCount=$((folderCount+1))
			}
			else # parameter nie je ani validnym adresarom ani parametrom oznamujuci debug mod
			{
				echo "$1 is not a valid directory. Exiting."
				__displayHelp__
				exit 1
			}
			fi
			shift
		else
			break
		fi
		i=$((i+1))
	done
fi
__displayFolders__

# vytvorenie adresarovej struktury
if [ -d "$FOLDER" ]
then
	echo "The program is probably already installed, because $FOLDER already exists. Change list of checked folders by editing $CONFIG_FILE manually. Exiting."
	exit 1
else
	mkdir -p $FOLDER
	echo "Your email is saved in $MAIL_FILE..."
	echo "$EMAIL" > $MAIL_FILE
	echo "List of regularly checked folders is saved in $CONFIG_FILE..."
	for I in ${FOLDERS[@]}
	do
		echo "$I" >> $CONFIG_FILE
	done
fi

# prva kontrola
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

# vysledky prvej kontroly zasli mailom
__mail__ "Setting up check application finished" "Your /etc/check/folders.conf now contains list of folders that will be periodically checked against any changes. /etc/check/results stores results of the latest check. Mails informing you of the current status will be sent to mail defined in /etc/check/mail.conf. Any new comparison will be based on repeatedly recreated /etc/check/results file."

# spocitaj hash samotneho suboru s obsahom hashe
resultant_hash=$(md5sum "$RESULTS_FILE" | cut -d' ' -f1)
echo "$resultant_hash" > $RESULTS_FILE_HASH

# install 'regular-script.sh' into crontab
grep "$SCRIPT_FILE" '/etc/crontab' > /dev/null
if [[ "$?" -eq 0 ]]
then
	echo "Crontab already contains $SCRIPT_FILE..."
else
	echo "Adding entry to crontab..."
	echo "@hourly root $SCRIPT_FILE" >> /etc/crontab
fi

echo "init-script.sh ended successfully..."
exit 0
