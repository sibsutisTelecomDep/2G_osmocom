#!/usr/bin/env bash

pids=()
CFG_PATH="$PWD/cfg"
# USER_HOME="$HOME" # or... 
# USER_HOME="/home/<YOUR USER>" 
USER_HOME="/home/kasperekd" 

echo $CFG_PATH
start_program() {
    sudo xterm -e "$1" -c "$2" &
    pids+=($!)
    sleep 0.2
}

start_program osmo-mgw "$CFG_PATH/osmo-mgw.cfg" &
start_program osmo-hlr "$CFG_PATH/osmo-hlr.cfg" &
start_program osmo-stp "$CFG_PATH/osmo-stp.cfg" &
start_program osmo-msc "$CFG_PATH/osmo-msc.cfg" &
start_program osmo-bsc "$CFG_PATH/osmo-bsc.cfg" &

sudo xterm -e python3 "$USER_HOME/2G/osmocom-bb/src/target/trx_toolkit/fake_trx.py" &
start_program "osmo-bts-trx" "$CFG_PATH/osmo-bts.cfg" &
start_program "$USER_HOME/2G/osmocom-bb/src/host/trxcon/src/trxcon" &
start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/misc/ccch_scan" -a ARFCN -i 127.0.0.1 &

start_program "$USER_HOME/2G/osmocom-bb/src/host/layer23/src/mobile/mobile" "$CFG_PATH/default.cfg" &

echo "Press Enter to close all programs..."
read enter_to_close

for pid in "${pids[@]}"; do
    sudo kill "$pid" 2>/dev/null
done

sudo killall osmo-msc osmo-bsc osmo-mgw osmo-hlr osmo-stp mobile osmo-bts-trx fake_trx.py trxcon xterm 2>/dev/null