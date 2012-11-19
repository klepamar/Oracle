# http://ttaweb.uk.oracle.com/software/tarantella/tta-4.60+/sgdbuild/test/5.00.553/tta-5.00-553.sol-sparc.pkg.gz

if [[ "$#" -ne 1 ]]
then
	echo "Include link from which to download SGD server, e.g. # ./install.sh ttaweb.uk.oracle.com/tta-5.00-553.sol.pkg.gz"
	exit 1
fi

echo "Downloading SGD server package..."
[[ -d /sgd ]] && rm -rf /sgd
mkdir -p /sgd
/usr/sfw/bin/wget -P /sgd "$1"

if [[ "$@" -eq 0 ]]
then 
	echo "SGD server package correctly downloaded..."
else
	echo "Error occured during downloading..."
fi

FILENAME=$(basename "$1")
FILENAME_MODIFIED=$(echo ${FILENAME%.gz})

echo "Gunzipping $FILENAME..."
gunzip /sgd/$FILENAME

echo "Installing $FILENAME_MODIFIED..."
pkgadd -d /sgd/$FILENAME_MODIFIED

echo "Installation successful, starting tarantella..."
/opt/tarantella/bin/tarantella start

