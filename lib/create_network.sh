#!/bin/bash
 
 source qm.variables
 source lib/common.sh

#create node configuration file
 function copyConfTemplate(){
    PATTERN="s/#mNode#/${mNode}/g"
    sed $PATTERN lib/master/template.conf > ${mNode}/node/${mNode}.conf
 }

#function to generate keyPair for node
 function generateKeyPair(){
    echo -ne "\n" | constellation-node --generatekeys=${mNode} 1>>/dev/null
    
    echo -ne "\n" | constellation-node --generatekeys=${mNode}a 1>>/dev/null

    mv ${mNode}*.*  ${mNode}/node/keys/.
    
}

#function to create node initialization script
function createInitNodeScript(){
    cp lib/master/init_template.sh ${mNode}/init.sh
    chmod +x ${mNode}/init.sh
}

#function to create start node script with --raft flag
function copyStartTemplate(){
    NET_ID=$(awk -v min=10000 -v max=99999 -v freq=1 'BEGIN{srand(); for(i=0;i<freq;i++)print int(min+rand()*(max-min+1))}')
    PATTERN="s|#network_Id_value#|${NET_ID}|g"
    cp lib/master/start_quorum_template.sh ${mNode}/node/start_${mNode}.sh
    sed -i $PATTERN ${mNode}/node/start_${mNode}.sh
    PATTERN="s/#mNode#/${mNode}/g"
    sed -i $PATTERN ${mNode}/node/start_${mNode}.sh
    chmod +x ${mNode}/node/start_${mNode}.sh

    cp lib/master/start_template.sh ${mNode}/start.sh
    chmod +x ${mNode}/start.sh

    cp lib/master/pre_start_check_template.sh ${mNode}/node/pre_start_check.sh
    START_CMD="start_${mNode}.sh"
    PATTERN="s/#start_cmd#/${START_CMD}/g"
    sed -i $PATTERN ${mNode}/node/pre_start_check.sh
    PATTERN="s/#nodename#/${mNode}/g"
    sed -i $PATTERN ${mNode}/node/pre_start_check.sh
    PATTERN="s/#netid#/${NET_ID}/g"
    sed -i $PATTERN ${mNode}/node/pre_start_check.sh
    chmod +x ${mNode}/node/pre_start_check.sh

    cp lib/common.sh ${mNode}/node/common.sh

    cat lib/master/nodemanager_template.sh > ${mNode}/node/nodemanager.sh
    chmod +x ${mNode}/node/nodemanager.sh
}

#function to generate enode
function generateEnode(){
    bootnode -genkey nodekey
    nodekey=$(cat nodekey)
	bootnode -nodekey nodekey 2>enode.txt &
	pid=$!
	sleep 5
	kill -9 $pid
	wait $pid 2> /dev/null
	re="enode:.*@"
	enode=$(cat enode.txt)
    
    if [[ $enode =~ $re ]];
    	then
        Enode=${BASH_REMATCH[0]};
    fi
    
    cp nodekey ${mNode}/node/qdata/geth/.
    cp lib/master/static-nodes_template.json ${mNode}/node/qdata/static-nodes.json
    PATTERN="s|#eNode#|${Enode}|g"
    sed -i $PATTERN ${mNode}/node/qdata/static-nodes.json

    rm enode.txt
    rm nodekey
}

#function to create node accout and append it into genesis.json file
function createAccount(){
    mAccountAddress="$(geth --datadir datadir --password lib/master/passwords.txt account new 2>> /dev/null)"
    re="\{([^}]+)\}"
    if [[ $mAccountAddress =~ $re ]];
    then
        mAccountAddress="0x"${BASH_REMATCH[1]};
    fi
    cp datadir/keystore/* ${mNode}/node/qdata/keystore/${mNode}key
    PATTERN="s|#mNodeAddress#|${mAccountAddress}|g"
    PATTERN1="s|20|${NET_ID}|g"
    cat lib/master/genesis_template.json >> ${mNode}/node/genesis.json
    sed -i $PATTERN ${mNode}/node/genesis.json
    sed -i $PATTERN1 ${mNode}/node/genesis.json
    rm -rf datadir
}

# execute init script
function executeInit(){
    cd ${mNode}
    ./init.sh
}

function main(){    
    getInputWithDefault 'Please enter node name' "" mNode $GREEN
    rm -rf ${mNode}
    echo $mNode > .nodename
    mkdir -p ${mNode}/node/keys
    mkdir -p ${mNode}/node/qdata
    mkdir -p ${mNode}/node/qdata/{keystore,geth,logs}
    cp qm.variables $mNode

    copyConfTemplate
    generateKeyPair
    createInitNodeScript
    copyStartTemplate
    generateEnode
    createAccount
    executeInit   
}
main
