pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "@nomiclabs/buidler/console.sol";


// QueueUints.sol
// using an array that marches through storage

struct SubscriptionData {
    address token;
    address to;
    uint256 amount;
    uint256 start;
    uint256 stop;
    uint256 unique;
}

struct Queue {
    SubscriptionData[] items;
    uint128 size;
    uint128 head;
}
library QueueFuns {
    function create(Queue storage self, uint256 size) internal {
        self.size = uint128(size);
        self.head = 0;
        delete self.items;
    }

    function append(Queue storage self, SubscriptionData memory item) internal
    returns (bool result) {
        if ((self.items.length - self.head) < self.size) {
            self.items.push(item);
            return true;
        }
    }

    function remove(Queue storage self) internal
    returns (SubscriptionData memory item, bool result) {
        if (self.head < self.items.length) {
            item = self.items[self.head];
            // self.items[self.head] = 0; // release unused storage
            self.head++;
            result = true;
        }
    }
}

contract SubscriptionQueue {

    string public name;

    using QueueFuns for Queue;

    event AddSubscription(SubscriptionData item);

    Queue subscriptions;
    constructor() public {
        name = "queue";
        subscriptions.create(1);
        SubscriptionData memory newSub = SubscriptionData(address(0),
            address(0x123),
            500,
            block.timestamp,
            block.timestamp,
            1);
        subscriptions.append(
            newSub
        );
    }
    function addMessage(SubscriptionData memory message) public returns (bool) {
        emit AddSubscription(message);
        return subscriptions.append(message);
    }

    function processMessages() public {
        (SubscriptionData memory message, bool success) = subscriptions.remove();
    }
}
