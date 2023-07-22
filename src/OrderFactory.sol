// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OrderFactory {
    using SafeERC20 for IERC20;

    error InvalidMaker(address sender, address maker);
    error InvalidTaker(address sender, address taker);
    error InvalidState(State expected, State actual);

    event OrderCreated(uint256 indexed orderId, Party maker, Party taker);
    event OrderFilled(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);

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

    function createOrder(Party calldata maker, Party calldata taker) external {
        uint256 orderId = _orderCount++;

        if (maker.account != msg.sender) revert InvalidMaker(msg.sender, maker.account);

        _orders[orderId] = Order({state: State.Created, maker: maker, taker: taker});

        maker.token.safeTransferFrom(msg.sender, address(this), maker.amount);

        emit OrderCreated(orderId, maker, taker);
    }

    function fillOrder(uint256 orderId) external {
        Order storage order = _orders[orderId];

        State state = order.state;

        if (state != State.Created) revert InvalidState(State.Created, state);

        address takerAccount = order.taker.account;

        if (takerAccount == address(0)) order.taker.account = msg.sender;
        else if (takerAccount != msg.sender) revert InvalidTaker(msg.sender, takerAccount);

        order.state = State.Filled;

        order.taker.token.safeTransferFrom(msg.sender, address(this), order.taker.amount);
        order.maker.token.safeTransfer(order.taker.account, order.maker.amount);

        emit OrderFilled(orderId);
    }

    function cancelOrder(uint256 orderId) external {
        Order storage order = _orders[orderId];

        State state = order.state;

        if (state != State.Created) revert InvalidState(State.Created, state);

        order.state = State.Cancelled;

        order.maker.token.safeTransfer(order.maker.account, order.maker.amount);

        emit OrderCancelled(orderId);
    }
}
