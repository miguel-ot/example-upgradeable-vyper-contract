# Upgradeable smart contract applications with Vyper

In this document, I will show how to create a simple upgradeable smart contract with [Vyper](https://docs.vyperlang.org/en/stable/) and how to interact with it using [Brownie](https://eth-brownie.readthedocs.io/en/stable/) and [web3.py](https://web3py.readthedocs.io/en/stable/).

**Disclaimer:** This document is intended for education purposes only and is not meant to be used in production.

## Introduction

It is well-known that a smart contract's code can not be modified once deployed. However, a smart contract application can be made upgradeable by means of a proxy contract. The proxy contract is a small smart contract that points to the full smart contract you have written, which will be called *implementation contract*. Users will interact with the proxy contract and this contract will send *delegate calls* to the implementation contract, which means that the proxy contract will use the logic of the implementation contract to perform the transaction. More precisely, the state variables of the proxy contract will be read and updated employing the logic of the implementation contract. It is worth mentioning that the state variables of the implementation contract will neither be read nor updated by the delegate calls of the proxy contract.

When the owner of the smart contract application wants to upgrade it, he/she can simply deploy a new implementation contract and change the address that the proxy contract points to.

Upgradeable smart contract applications have a clear advantage over immutable ones, which is the ability to fix bugs and add new features to the app without much difficulty and without the need to migrate all the data from the old version of the app to the new one. However, this benefit comes together with several important drawbacks. First of all, the users of an upgradeable smart contract application must trust the owners of the app not to deploy a malicious upgrade. Thus, an upgradeable smart contract application is much less decentralized than an immutable one. Secondly, the proxy contract adds a new point of failure to the app. For example, if the owner's account is compromised, user's funds will be at serious risk. Finally, setting up an upgradeable smart contract app is not simple, and a deep technical knowledge is required to securely implement and maintain such app.

## The implementation contract

We will start by creating a simple smart contract in Vyper, which will be our implementation contract, that is, the contract that contains the full logic of our application. It will be called `store.vy` and it will just store a number that can be modified.

```
# @version 0.3.7

implementation: public(address)
owner: public(address)
amount: public(uint256)

@external
def upgrade(addr: address):
    assert msg.sender == self.owner, "You are not the owner."
    self.implementation = addr

@external
def sum(a: uint256):
    self.amount += a
```

As we can see, the contract contains three state variables: `ìmplementation`, `owner` and `amount`. The variable `amount` will simply store a non-negative integer number. The variable `ìmplementation` is needed to indicate the address to which the proxy contract will point. And the variable `owner` will store the address of the owner of the app, which is the only one that will be able to upgrade it.

We can also see that the contract contains two external functions: the `upgrade` function which will allow the owner of the app to upgrade it, and the `sum` function, which modifies the stored value by adding a non-negative integer number to it.

## The proxy contract

For our sample proxy contract we will follow a similar pattern as the Universal Upgradeable Proxy Standard (UUPS). In this proxy pattern, the `upgrade` function is defined in the implementation contract, as we did in our contract `store.vy`. Thus, for our proxy contract we only need that every call that our proxy receives is delegated to the implementation contract. We will use the following contract that will be called `proxy.vy`.

```
# @version 0.3.7

implementation: public(address)
owner: public(address)
amount: public(uint256)

@external
def __init__(
    implementation_address: address
    ):
    self.implementation = implementation_address
    self.owner = msg.sender

@external
@payable
def __default__():
    raw_call(
        self.implementation,
        msg.data,
        max_outsize = 0,
        value = msg.value,
        is_delegate_call = True,
        revert_on_failure = True
    )
```

We can observe that the  proxy contract contains the same three state variables as the implementation contract:  `ìmplementation`, `owner` and `amount`. Although it is not required to define these state variables in the proxy contract, having them defined will make it easier for us to show how the upgradeable app works.

Our proxy contract contains two important functions: `__init__` and `__default__`. The `__init__` function is called when the proxy contract is deployed and, as we can see, sets the address of the implementation contract and defines the owner of the app as the deployer of the proxy contract. The `__default__` function is the function that will be called after the contract's deployment whenever a user sends a transaction to the proxy's address. As we can see, the `__default__` function makes a `raw_call` to the implementation contract with the same data that has been received in the transaction. In other words, the proxy contract makes a `delegate call` to the implementation contract.

## Deployment and transactions

We will now use [Brownie](https://eth-brownie.readthedocs.io/en/stable/) and the [web3.py](https://web3py.readthedocs.io/en/stable/) library to deploy our upgradeable smart contract app and interact with it.

First of all, we need to create a new project. To this end we proceed as follows.

```
mkdir store_app
cd store_app
brownie init
```

This initializes a new Brownie project in the folder `store_app` and creates the necessary subfolders.

Now, we put the files `store.vy` and `proxy.vy` described previously inside the `contracts` folder. After this, we execute
```
brownie compile
```
to compile both Vyper files.

We will now add our Ethereum account to Brownie executing
```
brownie accounts new MyAccount
```
We will be prompted for the private key of our account and a password to encrypt the new Brownie account with. Our newly added account will be listed if we execute the command
```
brownie accounts list
```
Now we will use Brownie's console to deploy the contracts in our local blockchain. We start the console with
```
brownie console
```
We will see a `>>>` prompt. From now on, we will write this prompt before the console commands to indicate that we are working in Brownie's console.

We will first load our Ethereum account to Brownie with the command
```
>>> dev_acc = accounts.load('MyAccount')
```
We will be asked for the password we wrote when we created the Brownie account.

Now, we will deploy the contracts to our local blockchain.
```
>>> store1 = store.deploy({'from': dev_acc})
>>> proxy1 = proxy.deploy(store1.address, {'from': dev_acc})
```
We can check the initial value of the `amount` variable with the `amount` method of the `store1` object:
```
>>> store1.amount()
0
```
We can see that it is set as `0`, as expected. Similarly, we can call the `sum` function of the `store` contract with
```
>>> store1.sum(3)
```
and now check that the value of the `amount` variable in the store contract is `3`:
```
>>> store1.amount()
3
```
It is important to mention that the value of the `amount` variable in the proxy contract is still `0` as we can see with the command
```
>>> proxy1.amount()
0
```
This is so because the proxy contract has its own state variables and we have not sent any transactions to the proxy contract yet. Also, it is worth mentioning that we can not interact with the proxy contract through Brownie alone, because Brownie does not know that it is a proxy contract and the `proxy1` object does not contain the `sum` method.

In order to interact with the proxy contract through Brownie, we will use the `web3` library. We import and set the necessary variables as follows:
```
>>> import web3
>>> provider = web3.Web3.HTTPProvider('http://127.0.0.1:8545')
>>> w3 = web3.Web3(provider)
>>> from web3.gas_strategies.rpc import rpc_gas_price_strategy
>>> w3.eth.set_gas_price_strategy(rpc_gas_price_strategy)
```

Now, we will add some coins to our account so that we can pay the gas fees required by the `web3` library. To this end we execute the command
```
>>> accounts[0].transfer(dev_acc, 10**18)
```
It is worth noticing that we are using just mock tokens of our local blockchain.

We will now create a `contract` object with the `web3` library so that we can interact with the proxy contract.
```
>>> proxy_contract = w3.eth.contract(address = proxy1.address, abi = store1.abi)
```
Note that we use the `abi` data of the `store.vy` contract, because our proxy contract will employ the logic of that contract.

We can test some methods of our new `proxy_contract` object with
```
>>> proxy_contract.address
>>> proxy_contract.all_functions()
```
Using the `proxy_contract` object we can read the value of the `amount` state variable of the proxy contract with
```
>>> proxy_contract.caller({'from': dev_acc.address}).amount()
```
We can see that the value of the `amount` variable is `0`, as we noticed previously with the command `proxy1.amount()`.

Now, we want to send a transaction to the proxy contract that calls the `sum` function. Since this function will modify the contract's state, it will need to write data into the blockchain. Thus, we can not use the `caller` method as we did before. Instead, we will need to create a transaction, sign it and send it to the proxy contract. 

We proceed as follows. First, we create the transaction:
```
>>> tx = proxy_contract.functions.sum(7).build_transaction({'from': dev_acc.address, 'chainId': 1337, 'nonce': dev_acc.nonce})
```
Now, we sign the transaction to obtain a signed transaction that we will store in the variable `signed_tx`:
```
>>> signed_tx = w3.eth.account.sign_transaction(tx, dev_acc.private_key)
```
Finally, we send the transaction:
```
>>> tx_sent = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
```
We can see that the `amount` variable of the proxy contract has been updated:
```
>>> proxy1.amount()
7
```
It is also interesting to note that the `amount` variable of the store contract has not been modified:
```
>>> store1.amount()
3
```
This occurs because the proxy contract employs only the logic of the implementation contract and does not use the values of the state variables that are stored in the implementation contract. The proxy contract stores, reads and modifies its own state variables.

Sometimes it is necessary to obtain the *receipt* of a transaction, which has useful information. For example, in the transaction receipt we can find the block number in which the transaction was included, the amount of gas used for the transaction and the transaction status, which is equal to `1` if the transaction was successful and equal to `0` if the transaction failed. We can obtain the receipt of our transaction executing
```
>>> tx_receipt = w3.eth.wait_for_transaction_receipt(tx_sent)
```

Having tested our proxy contract, we exit Brownie with the command
```
>>> exit()
```


## Upgrading the contract

Suppose that we want to add a new function to the `store.vy` contract. For example, a function that multiples the stored value by an integer. Thus, we will create a new Vyper contract with the following content, which will be called `storeV2.vy`.

```
# @version 0.3.7

implementation: public(address)
owner: public(address)
amount: public(uint256)

@external
def upgrade(addr: address):
    assert msg.sender == self.owner, "You are not the owner."
    self.implementation = addr

@external
def sum(a: uint256):
    self.amount += a

@external
def mul(k: uint256):
    self.amount = self.amount * k
```

The `storeV2.vy` file will be kept in the `contracts` folder of our project.

We will need to compile our new contract. Thus, we execute
```
brownie compile
```

We will now upgrade the `store` app to the V2 version. As we previously did, we start Brownie's console with
```
brownie console
```

First of all, we need to deploy our new implementation contract. To this end, we load our account with
```
>>> dev_acc = accounts.load('MyAccount')
```
and we deploy the upgraded contract to our local blockchain with
```
>>> store2 = storeV2.deploy({'from': dev_acc})
```
Since we closed the Brownie console after finishing the previous section, the local blockchain data we had was lost. Thus, we will need to redeploy the contracts `proxy.vy` and `store.vy`. Of course, if we had deployed them in a Testnet, we won't be redeploying them now, and we would only need to know their addresses.
In this case, we redeploy the contracts:
```
>>> store1 = store.deploy({'from': dev_acc})
>>> proxy1 = proxy.deploy(store1.address, {'from': dev_acc})
```

As we did before, in order to interact with the proxy contract through Brownie, we will use the `web3` library. We execute:
```
>>> import web3
>>> provider = web3.Web3.HTTPProvider('http://127.0.0.1:8545')
>>> w3 = web3.Web3(provider)
>>> from web3.gas_strategies.rpc import rpc_gas_price_strategy
>>> w3.eth.set_gas_price_strategy(rpc_gas_price_strategy)
>>> accounts[0].transfer(dev_acc, 10**18)
>>> proxy_contract = w3.eth.contract(address = proxy1.address, abi = store1.abi)
```
Now, we will perform the same transactions that we executed in the previous section so that we reach the same state we had. Again, this is needed because the local blockchain data is lost when Brownie is closed. We execute:
```
>>> store1.sum(3)
>>> store1.amount()
3
```
and
```
>>> tx = proxy_contract.functions.sum(7).build_transaction({'from': dev_acc.address, 'chainId': 1337, 'nonce': dev_acc.nonce})
>>> signed_tx = w3.eth.account.sign_transaction(tx, dev_acc.private_key)
>>> tx_sent = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
>>> proxy1.amount()
7
```

Now, we will upgrade our store app. To this end, we will call the `upgrade` function of the proxy contract, whose logic is given in the `store.vy` contract. Again, we need to create the transaction, sign it and then send it.
```
>>> tx = proxy_contract.functions.upgrade(store2.address).build_transaction({'from': dev_acc.address, 'chainId': 1337, 'nonce': dev_acc.nonce})
>>> signed_tx = w3.eth.account.sign_transaction(tx, dev_acc.private_key)
>>> tx_sent = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
```
We can now verify that the proxy contract now points to the new version of the `store` contract with:
```
>>> proxy1.implementation() == store2.address
True
```

We will now call the `mult` function that is present in the new version of the store app. We will need to define a new web3 contract object with
```
>>> proxy_contract = w3.eth.contract(address = proxy1.address, abi = store2.abi)
```
because we need the `abi` data of the new version.

Now we are ready to create, sign and send the new transaction.
```
>>> tx = proxy_contract.functions.mult(3).build_transaction({'from': dev_acc.address, 'chainId': 1337, 'nonce': dev_acc.nonce})
>>> signed_tx = w3.eth.account.sign_transaction(tx, dev_acc.private_key)
>>> tx_sent = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
```
And we can verify that the value of the `amount` variable has been updated accordingly:
```
>>> proxy1.amount()
21
```
Finally, note that the `amount` variables of the `store` and `storeV2` contracts were not modified:
```
>>> store1.amount()
3
>>> store2.amount()
0
```

