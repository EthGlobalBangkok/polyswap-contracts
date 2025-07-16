// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

struct OrderStatus {
    bool isFilledOrCancelled;
    uint256 remaining;
}

contract MockPolymarket {
    mapping(bytes32 => OrderStatus) public orderStatus;
    // Mock function to simulate the Polymarket order status

    function getOrderStatus(bytes32 orderHash) public view returns (OrderStatus memory) {
        return orderStatus[orderHash];
    }

    function setOrderStatus(bytes32 orderHash, bool isFilledOrCancelled, uint256 remaining) public {
        orderStatus[orderHash] = OrderStatus({isFilledOrCancelled: isFilledOrCancelled, remaining: remaining});
    }
}
