#!/usr/bin/env bash

pids=()
CFG_PATH="$PWD/cfg1"
# USER_HOME="$HOME" # or... 
# USER_HOME="/home/<YOUR USER>" 
USER_HOME="/home/fzybot" 

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
sleep 0.5

# Запуск остальных компонентов
sudo xterm -e python3 "$USER_HOME/2G/osmocom-bb/src/target/trx_toolkit/fake_trx.py" &
start_program "osmo-bts-trx" "./cfg/osmo-bts-trx.cfg" &
start_program "$USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon" &
echo "Press Enter to continue..."
sleep 0.5
# start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile2.cfg" &
start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile.cfg" &

echo "Press Enter to close all programs..."
read enter_to_close

for pid in "${pids[@]}"; do
    sudo kill "$pid" 2>/dev/null
done

sudo killall osmo-msc osmo-bsc osmo-mgw osmo-hlr osmo-stp mobile osmo-bts-trx fake_trx.py trxcon ccch_scan xterm mobile 2>/dev/null



# БОЕВОЙ РЕЗЕРВ
# sudo xterm -e python3 "$USER_HOME/2G/osmocom-bb/src/target/trx_toolkit/fake_trx.py" &
# start_program "osmo-bts-trx" "./cfg/osmo-bts-trx.cfg" &
# # start_program "osmo-bts-virtual" "$CFG_PATH/osmo-bts-virtual.cfg" &
# start_program "$USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon" &
# # sudo xterm -hold -e $USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon --trx-port 5700 -d DAPP:DL1C:DSCH -s /tmp/osmocom_l2 &
# # sudo xterm -hold -e $USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon -d DAPP:DL1C:DSCH -s /tmp/osmocom_l2 &
# # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/misc/ccch_scan" -a 774 -i 127.0.0.1 &
# # sudo xterm -hold -e "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/misc/ccch_scan" -a ARFCN -i 127.0.0.1 &
# # sudo xterm -hold -e "/home/kasperekd/2G/osmocom-bb/src/host/virt_phy/src/virtphy" &
# echo "Press Enter to continue..."
# read e
# # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile2.cfg" &
# start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/mobile.cfg" &
# # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "./cfg/mobile.cfg" &
# # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "./cfg/default.cfg" &
# # start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" -i 127.0.0.1 &