// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract OrderFactory is Ownable2Step {
    using SafeERC20 for IERC20;

    error InvalidMaker(address sender, address maker);
    error InvalidTaker(address sender, address taker);
    error InvalidState(State expected, State actual);
    error InvalidTakerFee(uint48 takerFee);
    error InvalidMakerFee(uint48 makerFee);
    error InvalidFeeRecipient(address feeRecipient);
    error SameTakerFee(uint48 takerFee);
    error SameMakerFee(uint48 makerFee);
    error SameFeeRecipient(address feeRecipient);

    event OrderCreated(uint256 indexed orderId, Party maker, Party taker);
    event OrderFilled(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);
    event TakerFeeSet(uint48 takerFee);
    event MakerFeeSet(uint48 makerFee);
    event FeeRecipientSet(address feeRecipient);

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

    uint256 public constant BASIS_POINTS = 10000;

    uint256 private _orderCount;

    uint48 private _takerFee;
    uint48 private _makerFee;
    address private _feeRecipient;

    mapping(uint256 => Order) private _orders;

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return _orders[orderId];
    }

    function getTakerFee() external view returns (uint48 takerFee) {
        return _takerFee;
    }

    function getMakerFee() external view returns (uint48 makerFee) {
        return _makerFee;
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

        uint256 makerAmount = order.maker.amount;
        uint256 takerAmount = order.taker.amount;

        uint256 makerFee = (makerAmount * _makerFee) / BASIS_POINTS;
        uint256 takerFee = (takerAmount * _takerFee) / BASIS_POINTS;

        if (makerFee > 0) order.maker.token.safeTransfer(_feeRecipient, makerFee);
        if (takerFee > 0) order.taker.token.safeTransfer(_feeRecipient, takerFee);

        order.taker.token.safeTransferFrom(msg.sender, address(this), takerAmount - takerFee);
        order.maker.token.safeTransfer(order.taker.account, makerAmount - makerFee);

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

    function setTakerFee(uint48 takerFee) external onlyOwner {
        if (takerFee > BASIS_POINTS) revert InvalidTakerFee(takerFee);
        if (takerFee == _takerFee) revert SameTakerFee(takerFee);

        _takerFee = takerFee;

        emit TakerFeeSet(takerFee);
    }

    function setMakerFee(uint48 makerFee) external onlyOwner {
        if (makerFee > BASIS_POINTS) revert InvalidMakerFee(makerFee);
        if (makerFee == _makerFee) revert SameMakerFee(makerFee);

        _makerFee = makerFee;

        emit MakerFeeSet(makerFee);
    }

    function setFeeRecipient(address feeRecipient) external onlyOwner {
        if (feeRecipient == address(0)) revert InvalidFeeRecipient(feeRecipient);
        if (feeRecipient == _feeRecipient) revert SameFeeRecipient(feeRecipient);

        _feeRecipient = feeRecipient;

        emit FeeRecipientSet(feeRecipient);
    }
}
