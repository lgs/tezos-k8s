# tezos-k8s

helper program to deploy tezos on kubernetes

## quickstart

``` shell
python3 -m venv .venv
source .venv/bin/activate
pip install -e ./
```

## Generate constants

Your chain is uniquely defined by a set of values such as bootstrap account keys, chain id, timestamp...

Create these values:

``` shell
mkchain generate-constants $CHAIN_NAME
```

It will create two 2 yaml files, `<$CHAIN_NAME>_chain.yaml` and `<$CHAIN_NAME>_chain_invite.yaml`.

### Chain parameters

You can modify these parameters by:

* passing parameters to the `generate-constants` subcommand
* modifying the yaml file generated by `generate-constants`
* passing argument to `mkchain create` and `mkchain invite` commands, which will selectively override the yaml parameters

| YAML Parameter | mkchain argument | Description | Default |
| ----- | ----------- | ------ | ----- |
| number_of_nodes | --number-of-nodes |  Number of peers in the cluster | 1 |
| baker | --baker | Include a baking node in the cluster | True |
| docker_image | --docker-image | Version of the Tezos docker image | tezos/tezos:v7-release |
| bootstrap_mutez | --bootstrap-mutez | Initial balance of the bootstrap accounts | 4000000000000 |
| zerotier_network | --zerotier-network | Zerotier network id for external chain access | |
| zerotier_token | --zerotier-token | Zerotier token for external chain access | |
| bootstrap_peer | --bootstrap-peer | peer ip to join | |
| genesis_key | --genesis-key | genesis public key for the chain to join | |
| genesis_block | --genesis-block | hash of the genesis block | |
| timestamp | --timestamp | timestamp for the chain to join | |
| protocol_hash | --protocol-hash | Desired Tezos protocol hash | PsDELPH1Kxsxt8f9eWbxQeRxkjfbxoqM52jvs5Y5fBxWWh4ifpo |
| baker_command | --baker-command | The baker command to use, including protocol | tezos-baker-007-PsDELPH1 |

## private chain

### create a self-contained chain
$CHAIN_NAME: is your private chain's name

``` shell
mkchain generate-constants $CHAIN_NAME
mkchain create $CHAIN_NAME | kubectl apply -f -
```

## multi-cluster chain

See the [multicluster howto](MULTICLUSTER.md).

## development

See [development](DEVELOPMENT.md).
