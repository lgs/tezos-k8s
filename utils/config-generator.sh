#!/bin/sh -x

ls -l /etc/tezos/data
echo ------------------------------------------------------------
cat /etc/tezos/data/config.json
echo ------------------------------------------------------------

mkdir -p /var/tezos/client
chmod -R 777 /var/tezos
set -e
python3 /config-generator.py "$@"
set +e

#
# Generate the tezedge configuration file:

cat > /etc/tezos/tezedge.conf <<EOM
--network=custom
--custom-network-file=/etc/tezos/config.json
--p2p-port=9732
--rpc-port=8732
--init-sapling-spend-params-file=/sapling-spend.params
--init-sapling-output-params-file=/sapling-output.params
--tezos-data-dir=/var/tezos/node/data
--bootstrap-db-path=/var/tezos/node/bootstrap
--identity-file=/tmp/tezedge/identity.json
--identity-expected-pow=0
--log-format=simple
--log-level=info
--ocaml-log-enabled=false
--peer-thresh-low=10
--peer-thresh-high=15
--protocol-runner=/protocol-runner
--tokio-threads=0
--enable-testchain=false
--log=terminal
EOM

< /etc/tezos/config.json jq -r '.p2p."bootstrap-peers"[]'	| \
	tr '\012' ',' | sed s/^/--bootstrap-lookup-address=/	  \
		>> /etc/tezos/tezedge.conf

#
# Next we write the current baker account into /etc/tezos/baking-account.
# We do it here because we shall use jq to process some of the environment
# variables and we are not guaranteed to have jq available on an arbitrary
# tezos docker image.

MY_CLASS=$(echo $NODES | jq -r ".\"${MY_NODE_CLASS}\"")
AM_I_BAKER=0
if [ "$MY_CLASS" != null ]; then
    AM_I_BAKER=$(echo $MY_CLASS | \
		 jq -r '.runs|map(select(. == "baker"))|length')
fi

if [ "$AM_I_BAKER" -eq 1 ]; then
    my_baker_account=$(echo $MY_CLASS | \
	    jq -r ".instances[${MY_POD_NAME#$MY_NODE_CLASS-}]
		   |if .bake_using_accounts
		    then .bake_using_accounts[]
		    else .bake_using_account
		    end")

    # If no account to bake for was specified in the node's settings,
    # config-generator defaults the account name to the pod's name.
    if [ "$my_baker_account" = null ]; then
	my_baker_account="$MY_POD_NAME"
    fi

    echo "$my_baker_account" > /etc/tezos/baker-account
fi
