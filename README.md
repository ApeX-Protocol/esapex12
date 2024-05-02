# esApex12 contract

### Document

### Install Foundry

```shell
$ curl -L https://foundry.paradigm.xyz | bash
$ foundryup
```

### Install Library

```shell
forge build
```

or

```shell
$ forge install foundry-rs/forge-std --no-commit
$ forge install OpenZeppelin/openzeppelin-contracts --no-commit
$ forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
```

### Test

```shell
$ forge test
```

### Deploy on the Mantle testnet sepolia

```shell
make deploy ARGS="--network sepolia"
```

### Deploy on the Mantle mainnet

```shell
make deploy ARGS="--network mainnet"
```
