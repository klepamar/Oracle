# scripting user & group creation

echo "Creating ttasys & ttaserv users..."
useradd -m -d /export/home/ttasys ttasys
useradd -m -d /export/home/ttaserv ttaserv

echo "Setting up password for ttasys..."
passwd ttasys

echo "Setting up password for ttaserv..."
passwd ttaserv

echo "Creating ttaserv group..."
groupadd ttaserv
usermod -g ttaserv ttasys
usermod -g ttaserv ttaserv
