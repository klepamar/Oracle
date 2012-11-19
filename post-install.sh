# scripting SGD server settings

if [[ -d "/opt/tarantella" ]]
then
	echo "/opt/tarantella folder already exists. Exiting."
	exit 1
fi

PATH=$PATH:/opt/tarantella/bin:/opt/tta_tem/bin
export $PATH
USERS="test-egc test-agc test-tgc"

if [[ "$UID" -ne 0 ]]
then
	echo "You need to be root to run the script!"
	exit 1
fi

if [[ "$#" -ne 2 ]]
then
	echo "Include servername as the first parameter and locale as the other parameter, e.g. # ./server-script.sh ada fr_FR"
	exit 1
fi

SERVER=$1;
echo "ServerName: $SERVER"

if [[ "$2" = "fr_FR" ]]
then
	MESSAGE="éèçà"
	echo "Locale set to fr_FR..."
elif [[ "$2" = "pt_BR" ]]
then
	MESSAGE="ççÇÇáãõñ"
	echo "Locale set to pt_BR..."
elif [[ "$2" = "it_IT" ]]
then
	MESSAGE="òèéçàù"
	echo "Locale set to it_IT..."
elif [[ "$2" = "de_DE" ]]
then
	MESSAGE="ßöäüÖÄÜ"
	echo "Locale set to de_DE..."
elif [[ "$2" = "es_ES" ]]
then
	MESSAGE="ññÑÑÑççÇñáó"
	echo "Locale set to es_ES..."
else
	echo "Invalid locale entered. Exiting..."
	exit 1
fi

# create new users on the current machine
echo "Creating users: test-egc, test-agc and test-tgc..."
for U in $USERS
do
	useradd -d /export/home/${U} $U
done


# set password to new users
echo "Setting up password for new users..."
for U in $USERS
do
	passwd $U
done

# create new users test-[eta]gc under COM
echo "Creating users within SGD..."
for U in $USERS
do
	tarantella object new_person --name dc=COM/cn=$U --surname $U --user $U --ntdomain "organization.cz"
done

# make newly created users administrators of SGD
echo "Making newly created users administrators of SGD..."
for U in $USERS
do
	tarantella role add_member --role global --member "dc=COM/cn=$U"
done

# set up javor.cz.oracle.com as an application server
echo "Setting up javor.cz.oracle.com as Windows application server..."
tarantella object new_host --name "o=appservers/cn=javor.cz.oracle.com" --address "javor.cz.oracle.com" --auth default --hostlocale "en_us" --ntdomain "organization.cz"

# add Windows Desktop & assign to to javor
echo "Creating Windows Desktop..."
tarantella object new_windowsapp --name "o=applications/cn=Windows Desktop" --scalable true --maximize true --width 1920 --height 1080 --app "" --appserv "o=appservers/cn=javor.cz.oracle.com"

# create a new Unix application - gedit
echo "Creating Gedit..."
tarantella object new_xapp --name "o=applications/cn=Gedit ($SERVER)" --app "/usr/bin/gedit" --width 640 --height 480 --method ssh --depth 24 --ssharguments "-X"

# create a Unix application containing multi-byte characters
echo "Creating application with multi-byte characters..."
tarantella object new_xapp --name "o=applications/cn=Gedit${MESSAGE} ($SERVER)" --app "/usr/bin/gedit" --width 640 --height 480 --method ssh --depth 24 --ssharguments "-X"

# assign all applications for all newly added users
for U in $USERS
do
	tarantella object add_link --name "dc=COM/cn=$U" --link "o=applications/cn=Gedit ($SERVER)"
	tarantella object add_link --name "dc=COM/cn=$U" --link "o=applications/cn=Firefox ($SERVER)"
	tarantella object add_link --name "dc=COM/cn=$U" --link "o=applications/cn=Gnome Terminal ($SERVER)"
	tarantella object add_link --name "dc=COM/cn=$U" --link "o=applications/cn=Gedit${MESSAGE} ($SERVER)"
	tarantella object add_link --name "dc=COM/cn=$U" --link "o=applications/cn=Windows Desktop"
done

# --------------
# AUTHENTICATION
# --------------
echo "Authentication settings..."
# Whether to save the user name and password that the user types to log in to SGD in the password cache.
tarantella config edit --launch-savettapassword "1"

# The following example uses the SGD password stored in the password cache when authenticating to an application server.
tarantella config edit --launch-trycachedpassword "1"

# action when password expired - In the following example, the user can change their password using a terminal window.
tarantella config edit --launch-expiredpassword "manual"

# show the authentication dialog if the user holds down the Shift key when they click an application’s link, or if there is a password problem.
tarantella config edit --launch-showauthdialog "user"

# Attributes that control the initial display state of the Launch Details area of the Application Launch dialog
tarantella config edit --launch-details-initial "hidden"

# --------------------
# CLIENT DRIVE MAPPING
# --------------------
echo "Client Drive Mapping settings..."
# Whether to enable client drive mapping (CDM) for applications running on Windows application servers.
tarantella config edit --array-windowscdm "1"

# Whether to enable CDM for applications running on UNIX or Linux platform application servers -> install TEM before!
tarantella config edit --array-unixcdm "1"

# Whether to enable dynamic drive mapping for the array. This feature enables “hot plugging” of removable storage devices, such as Universal Serial Bus (USB) drives -> install TEM before!
tarantella config edit --array-dyndevice "1"

# Whether to allow copy and paste operations for Windows and X application sessions for the array.
tarantella config edit --array-clipboard-enabled "1"

# Whether to allow users to edit their own profiles for use with the SGD Client.
tarantella config edit --array-editprofile "1"

# --------------------
# PRINTING PREFERENCES
# --------------------
echo "Local printer mapping settings..."
# Client Printing - The following example enables the user to print to all client printers from a Windows application.
tarantella config edit --printing-mapprinters "2"

# Enables users to print from a Windows application using the SGD Universal PDF printer.
tarantella config edit --printing-pdfenabled "1"

# The following example enables printing from Windows applications to the SGD Universal PDF Viewer printer.
tarantella config edit --printing-pdfviewerenabled 1

# ----------
# LOG FILTER
# ----------
# Enabling CDM Logging for the SGD Array
echo "Log filter..."
tarantella config edit --array-logfilter cdm/*/*:cdm%%PID%%.jsl,cdm/*/*:cdm%%PID%%.log,server/deviceservice/*:cdm%%PID%%.log,server/deviceservice/*:cdm%%PID%%.jsl,*/*/*error:jserver%%PID%%_error.log,*/*/*error:jserver%%PID%%_error.jsl,*/*/fatalerror:.../_beans/com.sco.tta.server.log.ConsoleSink

# Generates and installs a self-signed server SSL certificate.
# tarantella security selfsign

# To enable secure connections to a particular SGD server you must already have installed an SSL certificate for that server.
# tarantella security start

# list of packages to be uninstalled 
# tarantella uninstall --list

# remote all SGD packages (including configuration)
# tarantella uninstall --purge

# remote a specific package such as 'tta' (including configuration)
# tarantella uninstall tta --purge

# The name of the domain controller used for Windows domain authentication.
# tarantella config edit --login-nt-domain "organization.cz"

# create a new Windows application - notepad
# tarantella object new_windowsapp --name "o=applications/cn=Notepad" --width 640 --heigth 480 --app "c:\\Windows\notepad.exe" --appserv "p=appservers/cn=javor.cz.oracle.com"

# list all applications
# /opt/tarantella/bin/tarantella object list_contents --name "o=applications"

# list all applications servers
# /opt/tarantella/bin/tarantella object list_contents --name "o=appservers"
