# scripting SGD server uninstallation

if ! [[ -d "/opt/tarantella" ]]
then
	echo "No /opt/tarantella folder. Exiting."
	exit 1
fi

PATH=$PATH:/opt/tarantella/bin:/opt/tta_tem/bin
export $PATH
USERS="test-egc test-agc test-tgc"

# list of packages to be uninstalled 
# tarantella uninstall --list

# remote all SGD packages (including configuration)

echo "Removing SGD and its features..."
tarantella uninstall --purge

if [[ "$?" -ne 0 ]]
then
	echo "Error occured during SGD uninstallation. Not removing users & groups. Exiting."
	exit 1
fi

echo "Removing users & groups for SGD..."
userdel -r ttasys
userdel -r ttaserv
groupdel ttaserv

echo "Removing testing users..."
for U in $USERS
do
	getent passwd $U
	if [[ "$?" -eq 2 ]]
	then
		echo "User $U does not exist."
	else
		userdel -r $U
	fi
done

# remote a specific package such as 'tta' (including configuration)
# tarantella uninstall tta --purge


