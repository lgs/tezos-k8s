# Creating a Private Blockchain

## Zerotier

Zerotier is a VPN service that the Tezos nodes in your cluster will use to communicate with each other.

Create a ZeroTier network:

- Go to https://my.zerotier.com
- Login with credentials or create a new account
- Go to https://my.zerotier.com/account to create a new API access token
- Under `API Access Tokens > New Token`, give a name to your access token and generate it by clicking on the "generate" button. Save the generated access token, e.g. `yEflQt726fjXuSUyQ73WqXvAFoijXkLt` on your computer.
- Go to https://my.zerotier.com/network
- Create a new network by clicking on the "Create a Network"
  button. Save the 16 character generated network
  id, e.g. `1c33c1ced02a5eee` on your computer.

Set Zerotier environment variables in order to access the network id and access token values with later commands:

```shell
export ZT_TOKEN=yEflQt726fjXuSUyQ73WqXvAFoijXkLt
export ZT_NET=1c33c1ced02a5eee
```

## mkchain

mkchain is a python script that generates Helm values, which Helm then uses to create your Tezos chain on k8s.

Follow _just_ the Install mkchain step in `./mkchain/README.md`. See there for more info on how you can customize your chain.

Set as an environment variable the name you would like to give to your chain:

```shell
export CHAIN_NAME=my-chain
```

NOTE: k8s will throw an error when deploying if your chain name format does not match certain requirements. From k8s: `DNS-1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')`

Set [unbuffered IO](https://docs.python.org/3.6/using/cmdline.html#envvar-PYTHONUNBUFFERED) for python:

```shell
export PYTHONUNBUFFERED=x
```

## Start your private chain

Run `mkchain` to create your Helm values

```shell
mkchain $CHAIN_NAME --zerotier-network $ZT_NET --zerotier-token $ZT_TOKEN
```

This will create two files:

1. `./${CHAIN_NAME}_values.yaml`
2. `./${CHAIN_NAME}_invite_values.yaml`

The former is what you will use to create your chain, and the latter is for invitees to join your chain.

Create a Helm release that will start your chain:

```shell
helm install $CHAIN_NAME oxheadalpha/tezos-chain \
--values ./${CHAIN_NAME}_values.yaml \
--namespace oxheadalpha --create-namespace
```

Your kubernetes cluster will now be running a series of jobs to
perform the following tasks:

- get a zerotier ip
- generate a node identity
- create a baker account
- generate a genesis block for your chain
- start the bootstrap-node baker to bake/validate the chain
- activate the protocol
- bake the first block

You can find your node in the oxheadalpha namespace with some status information using kubectl.

```shell
kubectl -n oxheadalpha get pods -l appType=octez-node
```

You can view (and follow using the `-f` flag) logs for your node using the following command:

```shell
kubectl -n oxheadalpha logs -l appType=octez-node -c octez-node -f --prefix
```

Congratulations! You now have an operational Tezos based permissioned
chain running one node.

## Adding nodes within the cluster

You can spin up a number of regular peer nodes that don't bake in your cluster by passing `--number-of-nodes N` to `mkchain`. Pass this along with your previously used flags (`--zerotier-network` and `--zerotier-token`). You can use this to both scale up and down.

Or if you previously spun up the chain using `mkchain`, you may adjust
your setup to an arbitrary number of nodes by updating the "nodes"
section in the values yaml file.

nodes is a dictionary where each key value pair defines a statefulset
and a number of instances thereof.  The name (key) defines the name of
the statefulset and will be the base of the pod names.  The name must be
DNS compliant or you will get odd errors.  The instances are defined as a
list because their names are simply `-N` appended to the statefulsetname.
Said names are traditionally kebab case.

At the statefulset level, the following parameters are allowed:

   - storage_size: the size of the PV
   - runs: a list of containers to run, e.g. "baker", "tezedge"
   - instances: a list of nodes to fire up, each is a dictionary
     defining:
     - `bake_using_account`: The name of the account that should be used
                             for baking.
     - `is_bootstrap_node`: Is this node a bootstrap peer.
     - config: The `config` property should mimic the structure
               of a node's config.json.
               Run `tezos-node config --help` for more info.

defaults are filled in for most values.

Each statefulset can run either Nomadic Lab's `tezos-node` or TezEdge's
`tezedge` node.  Either can support all of the other containers.  If you
specify `tezedge` as one of the containers to run, then it will be run
in preference to `tezos-node`.

E.g.:

```
nodes:
  baking-node:
    storage_size: 15Gi
    runs:
      - baker
      - logger
    instances:
      - bake_using_account: baker0
        is_bootstrap_node: true
        config:
          shell:
            history_mode: rolling
  full-node:
    instances:
      - {}
      - {}
  tezedge-full-node:
    runs:
      - baker
      - logger
      - tezedge
    instances:
      - {}
      - {}
      - {}
```

This will run the following nodes:
   - `baking-node-0`
   - `full-node-0`
   - `full-node-1`
   - `tezedge-full-node-0`
   - `tezedge-full-node-1`
   - `tezedge-full-node-2`

`baking-node-0` will run baker and logger containers
and will be the only bootstrap node.  `full-node-*` are just nodes
with no extras.  `tezedge-full-node-*` will be tezedge nodes running baker
and logger containers.

To upgrade your Helm release run:

```shell
helm upgrade $CHAIN_NAME oxheadalpha/tezos-chain \
--values ./${CHAIN_NAME}_values.yaml \
--namespace oxheadalpha
```

The nodes will start up and establish peer-to-peer connections in a full mesh topology.

List all of your running nodes: `kubectl -n oxheadalpha get pods -l appType=octez-node`

## Adding external nodes to the cluster

External nodes to your local cluster can be added to your network by sharing a yaml file
generated by the `mkchain` command.

The file is located at: `<CURRENT WORKING DIRECTORY>/${CHAIN_NAME}_invite_values.yaml`

Send this file to the recipients you want to invite.

### On the computer of the joining node

The member needs to:

1. Follow the [prerequisite installation instructions](#installing-prerequisites)
2. [Start minikube](#start-minikube)

Then run:

```shell
helm repo add oxheadalpha https://oxheadalpha.github.io/tezos-helm-charts

helm install $CHAIN_NAME oxheadalpha/tezos-chain \
--values <LOCATION OF ${CHAIN_NAME}_invite_values.yaml> \
--namespace oxheadalpha --create-namespace
```

At this point additional nodes will be added in a full mesh
topology.

Congratulations! You now have a multi-node Tezos based permissioned chain.

On each computer, run this command to check that the nodes have matching heads by comparing their hashes (it may take a minute for the nodes to sync up):

```shell
kubectl get pod -n oxheadalpha -l appType=octez-node -o name |
while read line;
  do kubectl -n oxheadalpha exec $line -c octez-node -- /usr/local/bin/tezos-client rpc get /chains/main/blocks/head/hash;
done
```


