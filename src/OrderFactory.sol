// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {CCIPBase, Client, Bytes} from "./CCIPBase.sol";

contract OrderFactory is Ownable2Step, CCIPBase {
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
    error InvalidSender(bytes sender);
    error InvalidTakerToken(bytes32 token, bytes32 takerToken);
    error InvalidTakerAmount(uint256 amount, uint256 takerAmount);

    event OrderCreated(uint256 indexed orderId, Party maker, Party taker);
    event OrderFilled(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);
    event TakerFeeSet(uint48 takerFee);
    event MakerFeeSet(uint48 makerFee);
    event FeeRecipientSet(address feeRecipient);

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

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE = BASIS_POINTS / 20; // 5%

    uint64 public immutable currentChainSelector;

    uint256 private _orderCount;

    uint48 private _takerFee;
    uint48 private _makerFee;
    address private _feeRecipient;

    mapping(uint256 => Order) private _orders;
    mapping(uint64 => mapping(uint256 => Party)) private _parties;

    constructor(address router, uint64 chainSelector, uint48 takerFee, uint48 makerFee, address feeRecipient)
        CCIPBase(router)
    {
        currentChainSelector = chainSelector;

        _setTakerFee(takerFee);
        _setMakerFee(makerFee);
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

    function createOrder(Party calldata maker, Party calldata taker) external {
        uint256 orderId = _orderCount++;

        if (maker.account != msg.sender.toBytes32()) revert InvalidMaker(msg.sender.toBytes32(), maker.account);

        _orders[orderId] = Order({state: State.Created, maker: maker, taker: taker});

        IERC20(maker.token.toAddress()).safeTransferFrom(msg.sender, address(this), maker.amount);

        emit OrderCreated(orderId, maker, taker);
    }

    function fillOrder(uint64 chainSelector, uint256 orderId, bytes32 token, uint256 amount) external {
        bytes32 targetContract = _getTargetContract(chainSelector);

        if (targetContract == 0) revert UnsupportedChain(chainSelector);
        if (!_isTrustedToken(token.toAddress())) revert UntrustedToken(token.toAddress());
        if (_parties[chainSelector][orderId].account != 0) revert OrderAlreadyPending(chainSelector, orderId);

        if (chainSelector == currentChainSelector) return _fillOrder(orderId);

        _parties[chainSelector][orderId] = Party({account: msg.sender.toBytes32(), token: token, amount: amount});

        IERC20(token.toAddress()).safeTransferFrom(msg.sender, address(this), amount);

        _ccipSend(
            chainSelector,
            targetContract,
            abi.encode(CCIPAction.Check, msg.sender, token, amount, orderId),
            new Client.EVMTokenAmount[](0),
            type(uint256).max, // todo add a maxFee
            200_000 // todo add a gasLimit
        );
    }

    function cancelOrder(uint256 orderId) external {
        Order storage order = _orders[orderId];

        State state = order.state;

        if (state != State.Created) revert InvalidState(State.Created, state);

        order.state = State.Cancelled;

        IERC20(order.maker.token.toAddress()).safeTransfer(order.maker.account.toAddress(), order.maker.amount);

        emit OrderCancelled(orderId);
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

        takerToken.safeTransferFrom(msg.sender, address(this), takerAmount - takerFee);
        makerToken.safeTransfer(order.taker.account.toAddress(), makerAmount - makerFee);

        emit OrderFilled(orderId);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        if (_getTargetContract(message.sourceChainSelector) != Bytes.toBytes32(message.sender)) {
            revert InvalidSender(message.sender);
        }

        (CCIPAction action, bytes32 sender, bytes32 token, uint256 amount, uint256 orderId) =
            abi.decode(message.data, (CCIPAction, bytes32, bytes32, uint256, uint256));

        if (action == CCIPAction.Check) return _checkOrder(message, sender, token, amount, orderId);
        if (action == CCIPAction.Make) return _makeOrder(message, sender, token, amount, orderId);
        if (action == CCIPAction.Take) return _takeOrder(message, sender, token, amount, orderId);
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

        uint256 makerFeeAmount = (makerAmount * _makerFee) / BASIS_POINTS;

        if (makerFeeAmount > 0) IERC20(order.maker.token.toAddress()).safeTransfer(_feeRecipient, makerFeeAmount);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] =
            Client.EVMTokenAmount({token: order.maker.token.toAddress(), amount: makerAmount - makerFeeAmount});

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
        uint256 takerFeeAmount = (amount * _takerFee) / BASIS_POINTS;

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token.toAddress(), amount: amount - takerFeeAmount});

        delete _parties[message.sourceChainSelector][orderId];

        _ccipSend(
            message.sourceChainSelector,
            message.sender.toBytes32(),
            abi.encode(CCIPAction.Take, sender, token, amount, orderId),
            tokenAmounts,
            type(uint256).max, // todo add a maxFee
            200_000 // todo add a gasLimit
        );

        if (takerFeeAmount > 0) IERC20(token.toAddress()).safeTransfer(_feeRecipient, takerFeeAmount);
        _transferTokens(message.destTokenAmounts, sender.toAddress());
    }

    function _takeOrder(Client.Any2EVMMessage memory message, bytes32, bytes32, uint256, uint256 orderId) private {
        Order storage order = _orders[orderId];

        order.state = State.Filled;

        _transferTokens(message.destTokenAmounts, order.taker.account.toAddress());
    }
}
