#!/usr/bin/env bash

# CFG_PATH="$PWD/cfg1"
# USER_HOME="/home/kasperekd" 

# trap 'echo "Caught signal. Exiting..." && for pid in "${pids[@]}"; do sudo kill "$pid" 2>/dev/null; done; exit 1' SIGINT SIGTERM

# pids=()

# start_program() {
#   local program="$1"
#   local config_file="$2"

#   if ! command -v "$program" &> /dev/null; then
#     echo "Error: Program '$program' not found!"
#     return 1
#   fi

#   sudo xterm -e "$program" -c "$config_file" &
#   pids+=($!)
#   sleep 0.2
#   return 0
# }

# sudo killall osmo-msc osmo-bsc osmo-mgw osmo-hlr osmo-stp mobile osmo-bts-trx fake_trx.py trxcon ccch_scan xterm mobile 2>/dev/null

# echo "Starting core Osmocom components..."
# start_program osmo-hlr "$CFG_PATH/osmo-hlr.cfg" || exit 1
# start_program osmo-msc "$CFG_PATH/osmo-msc.cfg" || exit 1
# start_program osmo-mgw "$CFG_PATH/osmo-mgw-for-msc.cfg" || exit 1
# start_program osmo-mgw "$CFG_PATH/osmo-mgw-for-bsc.cfg" || exit 1
# start_program osmo-stp "$CFG_PATH/osmo-stp.cfg" || exit 1
# start_program osmo-bsc "$CFG_PATH/osmo-bsc.cfg" || exit 1
# echo "Core Osmocom components started successfully."

# read -p "Press Enter to continue..."

# echo "Starting additional components..."
# # start_program python3 "$USER_HOME/2G/osmocom-bb/src/target/trx_toolkit/fake_trx.py" & 
# sudo xterm -e python3 "$USER_HOME/2G/osmocom-bb/src/target/trx_toolkit/fake_trx.py"
# pids+=($!)

# start_program osmo-bts-trx "./cfg/osmo-bts-trx.cfg" &
# pids+=($!)

# start_program "$USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon" &
# pids+=($!)

# start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile.cfg" &
# pids+=($!)

# echo "All components started."

# read -p "Press Enter to close all programs..."

# for pid in "${pids[@]}"; do
#   sudo kill "$pid" 2>/dev/null
# done

# echo "All programs closed."

pids=()
CFG_PATH="$PWD/cfg1"
# USER_HOME="$HOME" # or... 
# USER_HOME="/home/<YOUR USER>" 
USER_HOME="/home/kasperekd" 

echo $CFG_PATH
start_program() {
    sudo xterm -hold -e "$1" -c "$2" &
    pids+=($!)
    sleep 0.2
}

sudo killall osmo-msc osmo-bsc osmo-mgw osmo-hlr osmo-stp mobile osmo-bts-trx fake_trx.py trxcon ccch_scan xterm mobile 2>/dev/null

start_program osmo-hlr "$CFG_PATH/osmo-hlr.cfg"
start_program osmo-msc "$CFG_PATH/osmo-msc.cfg"
start_program osmo-mgw "$CFG_PATH/osmo-mgw-for-msc.cfg"
start_program osmo-mgw "$CFG_PATH/osmo-mgw-for-bsc.cfg"
start_program osmo-stp "$CFG_PATH/osmo-stp.cfg"
start_program osmo-bsc "$CFG_PATH/osmo-bsc.cfg"

echo "Press Enter to continue..."
read e

# Запуск остальных компонентов
# sudo xterm -e python3 "$USER_HOME/2G/osmocom-bb/src/target/trx_toolkit/fake_trx.py" &
sudo xterm -e python3 "$USER_HOME/2G/osmocom-bb/src/target/trx_toolkit/fake_trx.py" --bb-base-port 6555 &
start_program "osmo-bts-trx" "./cfg/osmo-bts-trx.cfg" &
echo "Press Enter to continue..."
read e
sudo xterm -e "../src/build/main" -f 127.0.0.1 -t 127.0.0.1 -b 6555 -p 6888 -n 1 &
echo "Press Enter to continue..."
read e
sudo xterm -e "$USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon" --trx-port 6888 &
# sudo xterm -e "$USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon" &
echo "Press Enter to continue..."
read e
# start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile2.cfg" &
start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile.cfg" &

echo "Press Enter to close all programs..."
read enter_to_close

for pid in "${pids[@]}"; do
    sudo kill "$pid" 2>/dev/null
done

sudo killall osmo-msc osmo-bsc osmo-mgw osmo-hlr osmo-stp mobile osmo-bts-trx fake_trx.py trxcon ccch_scan xterm mobile 2>/dev/null



# # БОЕВОЙ РЕЗЕРВ
# # sudo xterm -e python3 "$USER_HOME/2G/osmocom-bb/src/target/trx_toolkit/fake_trx.py" &
# # start_program "osmo-bts-trx" "./cfg/osmo-bts-trx.cfg" &
# # # start_program "osmo-bts-virtual" "$CFG_PATH/osmo-bts-virtual.cfg" &
# # start_program "$USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon" &
# # # sudo xterm -hold -e $USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon --trx-port 5700 -d DAPP:DL1C:DSCH -s /tmp/osmocom_l2 &
# # # sudo xterm -hold -e $USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon -d DAPP:DL1C:DSCH -s /tmp/osmocom_l2 &
# # # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/misc/ccch_scan" -a 774 -i 127.0.0.1 &
# # # sudo xterm -hold -e "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/misc/ccch_scan" -a ARFCN -i 127.0.0.1 &
# # # sudo xterm -hold -e "/home/kasperekd/2G/osmocom-bb/src/host/virt_phy/src/virtphy" &
# # echo "Press Enter to continue..."
# # read e
# # # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile2.cfg" &
# # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile.cfg" &
# # # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "./cfg/mobile.cfg" &
# # # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "./cfg/default.cfg" &
# # # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" -i 127.0.0.1 &

