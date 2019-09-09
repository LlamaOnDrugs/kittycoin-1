#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='kittycoin.conf'
CONFIGFOLDER='/root/.kittycoin'
COIN_DAEMON='kittycoind'
COIN_CLI='kittycoind'
COIN_PATH='/usr/local/bin/'
COIN_TGZ='https://transfer.sh/R3L0b/kittycoind'
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')
COIN_NAME='kittycoin'
COIN_PORT=51473
RPC_PORT=51474

NODEIP=$(curl -s4 icanhazip.com)

BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m" 
PURPLE="\033[0;35m"
RED='\033[0;31m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'

purgeOldInstallation() {
echo -e "${GREEN}Searching and removing old $COIN_NAME files and configurations${NC}"
    # kill wallet daemon
	sudo killall $COIN_DAEMON > /dev/null 2>&1
    # remove old ufw port allow
    sudo ufw delete allow $COIN_PORT/tcp > /dev/null 2>&1
    # remove old files
    sudo rm $COIN_CLI $COIN_DAEMON > /dev/null 2>&1
    if [ -d "~/.$COIN_NAME" ]; then
        sudo rm -rf ~/.$COIN_NAME > /dev/null 2>&1
    fi
   # remove binaries and $COIN_NAME utilities
    cd /usr/local/bin && sudo rm $COIN_CLI $COIN_DAEMON > /dev/null 2>&1 && cd
    echo -e "${GREEN}* Done${NONE}"
}

# function install_sentinel() {
  # echo -e "${GREEN}Installing sentinel.${NC}"
  # apt-get -y install python-virtualenv virtualenv >/dev/null 2>&1
  # git clone $SENTINEL_REPO $CONFIGFOLDER/sentinel >/dev/null 2>&1
  # cd $CONFIGFOLDER/sentinel
  # virtualenv ./venv >/dev/null 2>&1
  # ./venv/bin/pip install -r requirements.txt >/dev/null 2>&1
  # echo  "* * * * * cd $CONFIGFOLDER/sentinel && ./venv/bin/python bin/sentinel.py >> $CONFIGFOLDER/sentinel.log 2>&1" > $CONFIGFOLDER/$COIN_NAME.cron
  # crontab $CONFIGFOLDER/$COIN_NAME.cron
  # rm $CONFIGFOLDER/$COIN_NAME.cron >/dev/null 2>&1


function download_node() {
  echo -e "${GREEN}Downloading and Installing VPS $COIN_NAME Daemon${NC}"
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $COIN_TGZ
  compile_error
  chmod +x $COIN_DAEMON $COIN_CLI
  cp $COIN_DAEMON $COIN_CLI $COIN_PATH
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}
function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target

[Service]
User=root
Group=root

Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid

ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcallowip=127.0.0.1
listen=0
server=1
daemon=1
port=$COIN_PORT
EOF
}

function create_key() {
  echo -e "${YELLOW}Enter your ${RED}$COIN_NAME Masternode GEN Key${NC}."
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then
  $COIN_PATH$COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server could not start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded. Please wait and try again to generate the GEN Key${NC}"
    sleep 30
    COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  fi
  $COIN_PATH$COIN_CLI stop
fi
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=1/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logintimestamps=1
maxconnections=256
#bind=$NODEIP
masternode=1
masternodeaddr=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
staking=0
addnode=51.77.166.204
addnode=45.32.200.177
addnode=23.94.136.165
addnode=89.40.8.215
addnode=66.70.238.225
addnode=54.39.246.20
addnode=45.76.119.46
addnode=188.165.248.58
addnode=173.212.252.166
addnode=108.61.221.215
addnode=212.237.20.129
addnode=167.114.126.203

EOF
}


function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}


function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *18.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 18.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMOM" ] ; then
  echo -e "${RED}$COIN_NAME is already installed.${NC}"
  exit 1
fi
}

function prepare_system() {
echo -e "Preparing the VPS to setup. ${CYAN}$COIN_NAME${NC} ${CYAN}Masternode${NC}"
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${PURPLE}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install libzmq3-dev -y >/dev/null 2>&1
apt-get install -y libboost-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev >/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ unzip libzmq5"
 exit 1
fi
clear
}

function important_information() {
 echo
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${YELLOW} $COIN_NAME   http://ktycoins.com/${NC}"
 echo -e "${YELLOW} $COIN_NAME Explorer http://144.202.63.37:3001/${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${GREEN} $COIN_NAME Masternode is up and running listening on port${NC}${PURPLE}$COIN_PORT${NC}"
 echo -e "${GREEN} Configuration file is:${NC}${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "${GREEN} VPS_IP: PORT${NC}${GREEN}$NODEIP: $COIN_PORT${NC}"
 echo -e "${GREEN} MASTERNODE GENKEY is:${NC}${PURPLE}$COINKEY${NC}"
 echo -e "${BLUE}================================================================================================================================"
 echo -e "${CYAN} Follow $COIN_NAME on Twitter https://twitter.com/Kittycoin3${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${CYAN} Ensure Node is fully SYNCED with BLOCKCHAIN prior to Activation.${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${GREEN} Usage Commands.${NC}"
 echo -e "${GREEN} kittycoind masternode status${NC}"
 echo -e "${GREEN} kittycoind getinfo${NC}"
 echo -e "${GREEN} systemctl start $COIN_NAME.service${NC}"
 echo -e "${GREEN} systemctl stop $COIN_NAME.service${NC}"
 echo -e "${GREEN} systemctl status $COIN_NAME.service${NC}"
 echo -e "${GREEN} systemctl enable $COIN_NAME.service${NC}"
 echo -e "${GREEN} systemctl disable $COIN_NAME.service${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${RED} Brought to you by LordSoylent. Donations Appreciated.${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${YELLOW} $COIN_NAME: Ks72AGCTHb2osyLvXgTe7vb1bhviPxpN4i${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 
 }

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
#  install_sentinel
  important_information
  configure_systemd
}


##### Main #####
clear

purgeOldInstallation
checks
prepare_system
download_node
setup_node
