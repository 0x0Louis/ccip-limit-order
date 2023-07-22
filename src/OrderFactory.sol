// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OrderFactory {
    using SafeERC20 for IERC20;

    error InvalidTaker(address sender, address taker);

    enum State {
        Invalid,
        Created,
        Filled,
        Cancelled
    }

    struct Party {
        address account;
        IERC20 token;
        uint256 amount;
    }

    struct Order {
        State state;
        Party maker;
        Party taker;
    }

    uint256 private _orderCount;

    mapping(uint256 => Order) private _orders;

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return _orders[orderId];
    }

    function createOrder(Order calldata order) external returns (uint256 orderId) {
        orderId = _orderCount++;

        _orders[orderId] = order;
    }
}
