The Rangers protocol has implements the EIP3074 and adds two instructions, `auth` and `authcall`, to the `VM`, which are mainly used to make agent execution/batch agent execution of transactions and pay gas fee for the original address . The whole implementation can be divided into three parts: `client` (related to authorised accounts), `solidity contract` and `VM command`.

### `client`

The `client` is mainly used for the transmission of authorised information and the signing of authorised addresses.

(1) The `client` shall perform a hash operation on the contents of the authorised transaction. And the transaction shall contain the following information:

```solidity
type Tx struct {
	To Address // The called contract address or transfer address
	Value *big.Int //transfer amount
	Gaslimit *big.Int //gas limit
	Nonce *big.Int // The user’s nonce in the contract
	Data []byte // The content of the called contract
}
```

The method of calculating hash needs to be consistent with the solidity contract, so it will result in `commitHash`.
(2) Calculate the hash of `commitHash`, `chainId`, and `contract address`, indicating that the above transaction will be authorized to be executed on a specific chain and specific contract.

> hash=keccak256(MAGIC || chainId || paddedInvokerAddress || commitHash)

(3) The user (referring to the authorised account) signs the hash with his `private key` on the `client`, indicating recognition of the authorised content.
Since the user must authorise by signing, the user must trust the `client`, and the `client` should display and explain the above information to the user.

### solidity contract

The proxy service provider needs to deploy a transit contract on Rangers protocol to accept authorized information and use `auth` `authcall` to complete transaction sending.
(1) Verify the submitted authorization information, including `nonce` verification and `commitHash` verification

```solidity
function getCommitHash(Transaction[] calldata txList)public view returns (bytes32){
    bytes  memory data = new bytes(txList.length*32);
    uint256 index = 0;
    for (uint256 i = 0; i < txList.length; i++) {
      bytes memory encoded = abi.encode(txList[i]);
      bytes32 hash = keccak256(encoded);
      for(uint256 j=0;j<32;j++){
          data[index] = hash[j];
          index = index+1;
      }
    }
    return keccak256(data);
}
```

(2) Use `auth` command to configure authorization settings

```solidity
/**
* authorizedAddress
* memory (A byte array composed of `r` `s` `v` in the signature of the authorized address to `commitHash` and the `commitHash` itself.)
* return bool （Indicates whether the authorization address is set successfully）
*/
bool auth(authorizedAddress,abi.encode(sig.v,sig.r,sig.s,commitHash))
```

(3) Use `authcall` command to make proxy calls to the contract

```solidity
/**
* nonce （The nonce of the authorized address）
* to （The called contract address）
* gasLimit
* value （The transfer amount）
* valueExt （The standard parameters of eip3074, currently 0）
* data (calldata)
* ret (The data returned by the calling contract or the error message returned)
* return bool (Whether the contract was executed successfully)
*/
bool authcall(uint256 nonce,uint256 gasLimit, address to, uint256 value,uint256 valueExt,bytes memory data,bytes memory ret);
```

### VM command

(1) The `auth` command will perform the same hash calculation as the client, and the user will verify the `chain ID` and contract address.

> hash=keccak256(MAGIC || chainId || paddedInvokerAddress || commitHash)

The signature is then restored and the restored address is compared with the authorised address to confirm authorisation. When verification is complete, the authorised address is stored.

```solidity
//EIP-3074 cal hash
//keccak256(MAGIC || chainId || paddedInvokerAddress || commit)
func calAuthHash(chainId *big.Int, contractAddress common.Address, commit [32]byte) []byte {
	chainIdBytes := utility.LeftPadBytes(chainId.Bytes(), 32)
	paddedContractAddress := utility.LeftPadBytes(contractAddress.Bytes(), 32)

	msg := make([]byte, 97)
	msg[0] = AUTHMAGIC
	copy(msg[1:33], chainIdBytes)
	copy(msg[33:65], paddedContractAddress)
	copy(msg[65:], commit[:])
	hash := crypto.Keccak256(msg)
	return hash
}
```

(2) In the `authcall` command, the authorized transaction list will be executed, and the sender of the transaction will be set as the authorized address.

What needs to be stressed is:

1. The `gas` used to execute the transaction and `value` in the transaction are paid by the caller of the contract, not by the contract itself. This is the difference between the implementation of the Rangers protocol and the official EIP-3074 document.
   The reason for this is that the Rsngers protocol development team believes that payment by the caller is more flexible and can prevent malicious contract calls from consuming the entire amount of the contract.
2. Regarding `nonce`: You need to fill in the current `nonce` of the authorized address correctly. The `nonce` will be verified during the execution of authcall. If the `nonce` is wrong, an error will be returned. The `nonce` can be obtained through <a href="https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gettransactioncount" title="rpc">eth json rpc</a>.
3. About `Gaslimit`: The mechanism is the same as Ethereum gaslimit. If the `gasLimit` of the `authcall` is written as `0`, the remaining maximum gas will be used by default. Otherwise, the filled in gasLimit will be used to perform verification. It is recommended to write `0` here.
