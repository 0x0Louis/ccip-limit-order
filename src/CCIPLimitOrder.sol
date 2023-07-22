// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {CCIPBase, Client, Bytes} from "./CCIPBase.sol";

contract CCIPLimitOrder is Ownable2Step, CCIPBase {
    using SafeERC20 for IERC20;
    using Bytes for bytes;
    using Bytes for bytes32;
    using Bytes for address;

    error InvalidMaker(bytes32 sender, bytes32 maker);
    error InvalidTaker(bytes32 sender, bytes32 taker);
    error InvalidState(State expected, State actual);
    error InvalidTakerFee(uint48 takerFee);
    error InvalidMakerFee(uint48 makerFee);
    error InvalidFeeRecipient(address feeRecipient);
    error SameTakerFee(uint48 takerFee);
    error SameMakerFee(uint48 makerFee);
    error SameFeeRecipient(address feeRecipient);
    error UnsupportedChain(uint64 chainSelector);
    error OrderAlreadyPending(uint64 chainSelector, uint256 orderId);
    error InvalidSender(bytes32 sender);
    error InvalidTakerToken(bytes32 token, bytes32 takerToken);
    error InvalidTakerAmount(uint256 amount, uint256 takerAmount);
    error PendingFillNotExpired();

    event OrderCreated(uint256 indexed orderId, Party maker, Party taker);
    event OrderFilled(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);
    event PendingFillCancelled(uint64 indexed chainSelector, uint256 orderId);
    event TakerFeeSet(uint48 takerFee);
    event MakerFeeSet(uint48 makerFee);
    event FeeRecipientSet(address feeRecipient);
    event CCIPActionReceived(CCIPAction action, uint256 indexed orderId);

    enum CCIPAction {
        Check,
        Make,
        Take
    }

    enum State {
        Invalid,
        Created,
        Filling,
        Filled,
        Cancelled
    }

    struct Party {
        bytes32 account;
        bytes32 token;
        uint256 amount;
    }

    struct Order {
        State state;
        Party maker;
        Party taker;
    }

    struct PendingFill {
        bytes32 account;
        bytes32 token;
        uint256 amount;
        uint256 timestamp;
    }

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE = 500 / BASIS_POINTS; // 5%
    uint256 public constant MIN_PENDING_FILL_DURATION = 1 days;

    uint64 public immutable currentChainSelector;

    uint256 private _orderCount;

    uint48 private _takerFee;
    uint48 private _makerFee;
    address private _feeRecipient;

    mapping(uint256 => Order) private _orders;
    mapping(uint64 => mapping(uint256 => PendingFill)) private _pendingFills;

    constructor(address router, uint64 chainSelector, uint48 takerFee, uint48 makerFee, address feeRecipient)
        CCIPBase(router)
    {
        currentChainSelector = chainSelector;

        if (takerFee != 0) _setTakerFee(takerFee);
        if (makerFee != 0) _setMakerFee(makerFee);

        _setFeeRecipient(feeRecipient);
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return _orders[orderId];
    }

    function getTakerFee() external view returns (uint48 takerFee) {
        return _takerFee;
    }

    function getMakerFee() external view returns (uint48 makerFee) {
        return _makerFee;
    }

    function createOrder(Party calldata maker, Party calldata taker) external returns (uint256 orderId) {
        orderId = _orderCount++;

        if (maker.account != msg.sender.toBytes32()) revert InvalidMaker(msg.sender.toBytes32(), maker.account);
        if (!_isTrustedToken(maker.token.toAddress()) || !_isTrustedToken(taker.token.toAddress())) {
            revert UntrustedToken(maker.token.toAddress());
        }

        _orders[orderId] = Order({state: State.Created, maker: maker, taker: taker});

        IERC20(maker.token.toAddress()).safeTransferFrom(msg.sender, address(this), maker.amount);

        emit OrderCreated(orderId, maker, taker);
    }

    function fillOrder(uint64 chainSelector, uint256 orderId, bytes32 token, uint256 amount) external returns (bool) {
        if (chainSelector == currentChainSelector) {
            _fillOrder(orderId);
            return true;
        }

        if (!_isTrustedToken(token.toAddress())) revert UntrustedToken(token.toAddress());
        bytes32 targetContract = _getTargetContract(chainSelector);
        if (targetContract == 0) revert UnsupportedChain(chainSelector);

        if (_pendingFills[chainSelector][orderId].account != 0) revert OrderAlreadyPending(chainSelector, orderId);

        _pendingFills[chainSelector][orderId] =
            PendingFill({account: msg.sender.toBytes32(), token: token, amount: amount, timestamp: block.timestamp});

        IERC20(token.toAddress()).safeTransferFrom(msg.sender, address(this), amount);

        _ccipSend(
            chainSelector,
            targetContract,
            abi.encode(CCIPAction.Check, msg.sender, token, amount, orderId),
            new Client.EVMTokenAmount[](0),
            type(uint256).max, // todo add a maxFee
            200_000 // todo add a gasLimit
        );

        return true;
    }

    function cancelOrder(uint256 orderId) external returns (bool) {
        Order storage order = _orders[orderId];

        State state = order.state;

        if (state != State.Created) revert InvalidState(State.Created, state);

        order.state = State.Cancelled;

        IERC20(order.maker.token.toAddress()).safeTransfer(order.maker.account.toAddress(), order.maker.amount);

        emit OrderCancelled(orderId);

        return true;
    }

    function cancelPendingFill(uint64 chainSelector, uint256 orderId) external returns (bool) {
        PendingFill storage pendingFill = _pendingFills[chainSelector][orderId];

        if (pendingFill.account != msg.sender.toBytes32()) revert InvalidSender(msg.sender.toBytes32());
        if (pendingFill.timestamp + MIN_PENDING_FILL_DURATION > block.timestamp) revert PendingFillNotExpired();

        delete _pendingFills[chainSelector][orderId];

        IERC20(pendingFill.token.toAddress()).safeTransfer(msg.sender, pendingFill.amount);

        emit PendingFillCancelled(chainSelector, orderId);

        return true;
    }

    function setTakerFee(uint48 takerFee) external onlyOwner {
        _setTakerFee(takerFee);
    }

    function setMakerFee(uint48 makerFee) external onlyOwner {
        _setMakerFee(makerFee);
    }

    function setFeeRecipient(address feeRecipient) external onlyOwner {
        _setFeeRecipient(feeRecipient);
    }

    function _setTakerFee(uint48 takerFee) private {
        if (takerFee > MAX_FEE) revert InvalidTakerFee(takerFee);
        if (takerFee == _takerFee) revert SameTakerFee(takerFee);

        _takerFee = takerFee;

        emit TakerFeeSet(takerFee);
    }

    function _setMakerFee(uint48 makerFee) private {
        if (makerFee > MAX_FEE) revert InvalidMakerFee(makerFee);
        if (makerFee == _makerFee) revert SameMakerFee(makerFee);

        _makerFee = makerFee;

        emit MakerFeeSet(makerFee);
    }

    function _setFeeRecipient(address feeRecipient) private {
        if (feeRecipient == address(0)) revert InvalidFeeRecipient(feeRecipient);
        if (feeRecipient == _feeRecipient) revert SameFeeRecipient(feeRecipient);

        _feeRecipient = feeRecipient;

        emit FeeRecipientSet(feeRecipient);
    }

    function _fillOrder(uint256 orderId) private {
        Order storage order = _orders[orderId];

        State state = order.state;

        if (state != State.Created) revert InvalidState(State.Created, state);

        bytes32 takerAccount = order.taker.account;

        if (takerAccount == 0) order.taker.account = msg.sender.toBytes32();
        else if (takerAccount != msg.sender.toBytes32()) revert InvalidTaker(msg.sender.toBytes32(), takerAccount);

        order.state = State.Filled;

        uint256 makerAmount = order.maker.amount;
        uint256 takerAmount = order.taker.amount;

        uint256 makerFee = (makerAmount * _makerFee) / BASIS_POINTS;
        uint256 takerFee = (takerAmount * _takerFee) / BASIS_POINTS;

        IERC20 makerToken = IERC20(order.maker.token.toAddress());
        IERC20 takerToken = IERC20(order.taker.token.toAddress());

        if (makerFee > 0) makerToken.safeTransfer(_feeRecipient, makerFee);
        if (takerFee > 0) takerToken.safeTransfer(_feeRecipient, takerFee);

        takerToken.safeTransferFrom(msg.sender, order.maker.account.toAddress(), takerAmount - takerFee);
        makerToken.safeTransfer(order.taker.account.toAddress(), makerAmount - makerFee);

        emit OrderFilled(orderId);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        if (_getTargetContract(message.sourceChainSelector) != Bytes.toBytes32(message.sender)) {
            revert InvalidSender(message.sender.toBytes32());
        }

        (CCIPAction action, bytes32 sender, bytes32 token, uint256 amount, uint256 orderId) =
            abi.decode(message.data, (CCIPAction, bytes32, bytes32, uint256, uint256));

        if (action == CCIPAction.Check) _checkOrder(message, sender, token, amount, orderId);
        else if (action == CCIPAction.Make) _makeOrder(message, sender, token, amount, orderId);
        else if (action == CCIPAction.Take) _takeOrder(message, sender, token, amount, orderId);

        emit CCIPActionReceived(action, orderId);
    }

    function _checkOrder(
        Client.Any2EVMMessage memory message,
        bytes32 sender,
        bytes32 token,
        uint256 amount,
        uint256 orderId
    ) private {
        Order storage order = _orders[orderId];

        if (order.state != State.Created) revert InvalidState(State.Created, order.state);
        if (order.taker.account != 0 && order.taker.account != sender) revert InvalidTaker(sender, order.taker.account);
        if (order.taker.token != token) revert InvalidTakerToken(token, order.taker.token);
        if (order.taker.amount != amount) revert InvalidTakerAmount(amount, order.taker.amount);

        order.taker.account = sender;
        order.state = State.Filling;

        uint256 makerAmount = order.maker.amount;
        IERC20 makerToken = IERC20(order.maker.token.toAddress());

        uint256 makerFeeAmount = (makerAmount * _makerFee) / BASIS_POINTS;

        if (makerFeeAmount > 0) makerToken.safeTransfer(_feeRecipient, makerFeeAmount);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(makerToken), amount: makerAmount - makerFeeAmount});

        _ccipSend(
            message.sourceChainSelector,
            message.sender.toBytes32(),
            abi.encode(CCIPAction.Make, sender, token, amount, orderId),
            tokenAmounts,
            type(uint256).max, // todo add a maxFee
            200_000 // todo add a gasLimit
        );
    }

    function _makeOrder(
        Client.Any2EVMMessage memory message,
        bytes32 sender,
        bytes32 token,
        uint256 amount,
        uint256 orderId
    ) private {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token.toAddress(), amount: amount});

        delete _pendingFills[message.sourceChainSelector][orderId];

        IERC20 makerToken = IERC20(message.destTokenAmounts[0].token);
        uint256 makerAmount = message.destTokenAmounts[0].amount;

        uint256 makerFeeAmount = (makerAmount * _makerFee) / BASIS_POINTS;

        _ccipSend(
            message.sourceChainSelector,
            message.sender.toBytes32(),
            abi.encode(CCIPAction.Take, sender, token, amount, orderId),
            tokenAmounts,
            type(uint256).max, // todo add a maxFee
            200_000 // todo add a gasLimit
        );

        if (makerFeeAmount > 0) makerToken.safeTransfer(_feeRecipient, makerFeeAmount);
        makerToken.safeTransfer(sender.toAddress(), makerAmount - makerFeeAmount);
    }

    function _takeOrder(Client.Any2EVMMessage memory, bytes32, bytes32, uint256, uint256 orderId) private {
        Order storage order = _orders[orderId];

        order.state = State.Filled;

        IERC20 takerToken = IERC20(order.taker.token.toAddress());

        uint256 takerAmount = order.taker.amount;
        uint256 takerFeeAmount = (takerAmount * _takerFee) / BASIS_POINTS;

        if (takerFeeAmount > 0) takerToken.safeTransfer(_feeRecipient, takerFeeAmount);
        takerToken.safeTransfer(order.maker.account.toAddress(), takerAmount - takerFeeAmount);
    }
}
