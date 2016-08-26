#!/bin/bash
#
# v0.0.1
# Installing BU on a new machine, configuring it, make it persistan to reboot 
# Tested on Ubuntu 14.04 and 16.04 x86_64
# inspired by https://raw.githubusercontent.com/XertroV/BitcoinAutoNode/master/bitcoinAutoNode.sh
#
# TODO add mechanism to fetch blockchain data from a remote provider (rsync + ssh, exchange keys)  
# WARN if run by sudo we need to input the password from stdin on disable password prompt for sudoers
#
# -d download instead of compiling
# -n avoid to create swap partition 
# -r reboot at the end

set -eu

#TODO read these pars from a conf file, ideally the JSON used in release signature. 
BU_VER="0.12.1bu"
BU_TAG="BU0.12.1b"
BU_URL64="https://www.bitcoinunlimited.info/downloads/bitcoinUnlimited-0.12.1-linux64.tar.gz"
BU_URL32="https://www.bitcoinunlimited.info/downloads/bitcoinUnlimited-0.12.1-linux32.tar.gz"
BU_SUM64="34de171ac1b48b0780d68f3844c9fd2e8bfe6a7780b55e1f012067c2440ebd8a"
BU_SUM32="984111483981bbfa5d33f40014336d74cbb263a51cb42a87e5d1871f88c14a7c"
BU_HOME=/home/bitcoin

# default value for variuois mode
DW_MODE=0
CR_SWAP=1
REBOOT=0

# add getopts parsing
while getopts "dnr" Opts; do
  case $Opts in
    d)
      #Download mode activated
      DW_MODE=1
      ;;
    n)
      #Disable swap creation
      CR_SWAP=0
      ;;
    r)
      #reboot the machien at the end
      REBOOT=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

### helper functions 

check_root_sudo () {
  if [ "$(whoami)" != "root" ]; then
    echo "Please run as root, or use sudo"
    exit 1
  fi;
}

check_tmux_screen () {
  if [[ -v TMUX || -v STY ]]; then 
    echo "TMUX/SCREEN detected"
  else
    echo "Please tun the script inside a terminal multiplexer (e.g. tmux, screen, ...)"; 
    echo "To install tmux use sudo apt-get install tmux" 
    exit 1;
  fi
}

#### main functions 

install_prereq () {
  echo -n "Updating Ubuntu ... "
  # removed ppa bitcon rep since wei don't need berkeley db 

  apt-get -y -qq update
  echo "done."
  echo -n "Installing Bu prereq via apt-get ... "
  sudo apt-get -qq install git
  sudo apt-get -qq install build-essential libtool autotools-dev 
  sudo apt-get -qq install automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-all-dev
  echo "done."
}

create_swap () {
  echo -n "Creating Swap ... "
  SWAP_SIZE=`free -m | grep Mem | awk '{print $2}'`
  rm -f /swapfile
  fallocate -l ${SWAP_SIZE}M /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile 
  echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
  echo "done."
}


cloning () {
  echo -n "Cloning Bitcoin BU ... "
  cd $HOME
  mkdir -p ./src && cd ./src
  git clone https://github.com/BitcoinUnlimited/BitcoinUnlimited.git BU 
  echo "done."
}

compiling () {
  echo -n "Compiling ... "
  cd $HOME/src/BU
  patch -p1 < $HOME/rpc_raw_tx.diff
  ./autogen.sh
  ./configure --without-gui --without-upnp --disable-tests --disable-wallet --disable-zmq
  export NUMCPUS=`grep -c '^processor' /proc/cpuinfo`
  make -j$NUMCPUS
  make install
  echo " done."
}


downloading () {
  echo -n "Downloading BU ... "
  tmp_dir="/tmp/`< /dev/urandom tr -dc A-Za-z0-9 | head -c10`"
  mkdir $tmp_dir
  cd $tmp_dir
  # TODO use a switch to explictly list all support arch
  if [ "$(uname -i)" == "x86_64" ]; then
    bu_name="bu64.tar.gz"
    bu_url=$BU_URL64
    bu_sum=$BU_SUM64
  else
    bu_name="bu32.tar.gz"
    bu_url=$BU_URL32
    bu_sum=$BU_SUM32
  fi;  
  curl -o $bu_name $bu_url
  echo " done."
  echo -n "Verify check sum ... "
  bu_real_sum=`sha256sum $bu_name | awk '{print $1}'`
  if [ "$bu_real_sum" != "$bu_sum" ]; then
    echo "SHA256 mismatch! Aborting!"
    echo "Expected archive sha256 checksum is $bu_sum, whereas this what we got: $bu_real_sum"
  fi; 
  echo " done."

  echo -n "Installing in /usr/local/bin ... "
  tmp_path=`tar tf $bu_name | head -n1 | awk -F '/' '{print $1}'`
  tar xf $bu_name 
  cp $tmp_path/bin/* /usr/local/bin 
  echo " done."
}

setting_up () {
  echo -n "Creating Bitcoin User ... "
  useradd -m bitcoin
  echo "done."
  echo -n "Creating config ... "
  su bitcoin -c "mkdir ${BU_HOME}/.bitcoin"
  config="${BU_HOME}/.bitcoin/bitcoin.conf"
  su bitcoin -c "touch $config"
  echo "server=1" > $config
  echo "daemon=1" >> $config
  echo "connections=40" >> $config
  echo "dbcache=200" >> $config
  randUser=`< /dev/urandom tr -dc A-Za-z0-9 | head -c30`
  randPass=`< /dev/urandom tr -dc A-Za-z0-9 | head -c30`
  echo "rpcuser=$randUser" >> $config
  echo "rpcpassword=$randPass" >> $config
  # set prune amount to size of `/` 60% (and then by /1000 to turn KB to MB) => /1666
  echo "prune="$(expr $(df | grep '/$' | tr -s ' ' | cut -d ' ' -f 2) / 1666) >> $config # safe enough for now
  chown bitcoin.bitcoin -R $BU_HOME/.bitcoin
  echo "done."
}


start_at_boot () {
  echo -n "Setting bitcoind to start at boot ... "
  LN=`wc -l /etc/rc.local | awk '{print $1}'`
  BU_INIT="su bitcoin -c '/usr/local/bin/bitcoind -datadir=${BU_HOME}/.bitcoin -daemon'"
  sed -i "${LN}i $BU_INIT" /etc/rc.local
  echo "done."
}

# mandatory checks 
check_root_sudo
check_tmux_screen

# main 
if [ "$CR_SWAP" == "1" ]; then
  create_swap
fi;

if [ "$DW_MODE" == "0" ]; then
  install_prereq
  cloning
  compiling
else
  downloading
fi;

# starting box configuration
setting_up
start_at_boot

echo "Finished."

if [ "$REBOOT" == "1" ]; then
  echo "Rebooting now ..."
  reboot
fi

