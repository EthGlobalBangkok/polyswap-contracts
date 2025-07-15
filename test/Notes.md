# command used to test :

### create a polymarket order hash on mock contract
#### create polymarket order not filled in the mock contract
`cast send $POLYMARKET_MOCK "setOrderStatus(bytes32,bool,uint256)" $POLYMARKET_ORDER_HASH false 10 --private-key $PRIVATE_KEY --rpc-url https://polygon-rpc.com`

#### check order status
`cast call $POLYMARKET_MOCK "getOrderStatus(bytes32)((bool,uint256))" $POLYMARKET_ORDER_HASH --rpc-url https://polygon-rpc.com`

#### approve the sell token on the safe to the spender
`forge script ./script/SubmitSingleOrder.s.sol:ApproveSellTokenOnSafe --rpc-url https://polygon-rpc.com --broadcast --private-key $PRIVATE_KEY`

### if first time conditional order on safe:
#### set fallback handler one time
`cast send $SAFE "setFallbackHandler(address)" 0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5 --private-key $PRIVATE_KEY --rpc-url https://polygon-rpc.com`

#### get the domain separator of ComposableCoW
`cast call 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74 "domainSeparator()(bytes32)" --rpc-url https://polygon-rpc.com`

#### set domain verifier one time
`cast send $SAFE "setDomainVerifier(bytes32,address)" $COMPOSABLE_COW_DOMAIN_SEPARATOR $COMPOSABLE_COW --rpc-url https://polygon-rpc.com --private-key $PRIVATE_KEY`

### create a single order on ComposableCoW
#### create a polyswap order
`forge script ./script/SubmitSingleOrder.s.sol:SubmitSingleOrder --rpc-url https://polygon-rpc.com --broadcast --private-key $PRIVATE_KEY`

### set the order status to filled in the mock contract
`cast send $POLYMARKET_MOCK "setOrderStatus(bytes32,bool,uint256)" $POLYMARKET_ORDER_HASH true 0 --private-key $PRIVATE_KEY --rpc-url https://polygon-rpc.com`