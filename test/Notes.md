# command used to test :

#### create polymarket order not filled in the mock contract
`cast send $POLYMARKET_MOCK "setOrderStatus(bytes32,bool,uint256)" $POLYMARKET_ORDER_HASH false 10 --private-key $PRIVATE_KEY --rpc-url https://polygon-rpc.com`

#### check order status
`cast call $POLYMARKET_MOCK "getOrderStatus(bytes32)((bool,uint256))" $POLYMARKET_ORDER_HASH --rpc-url https://polygon-rpc.com`

#### create a polyswap order
`forge script ./script/SubmitSingleOrder.s.sol:SubmitSingleOrder --rpc-url https://polygon-rpc.com --broadcast --private-key $PRIVATE_KEY`

#### set polymarket mock order status to filled
`cast send $POLYMARKET_MOCK "setOrderStatus(bytes32,bool,uint256)" $POLYMARKET_ORDER_HASH true 0 --private-key $PRIVATE_KEY --rpc-url https://polygon-rpc.com`