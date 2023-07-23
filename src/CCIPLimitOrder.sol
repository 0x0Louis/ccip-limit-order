// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CCIPBase, Client, Bytes} from "./CCIPBase.sol";

contract CCIPLimitOrder is CCIPBase {
    using SafeERC20 for IERC20;
    using Bytes for bytes;
    using Bytes for bytes32;
    using Bytes for address;

    error InvalidState(State expected, State actual);
    error InvalidTakerFee(uint48 takerFee);
    error InvalidMakerFee(uint48 makerFee);
    error InvalidFeeRecipient(address feeRecipient);
    error SameTakerFee(uint48 takerFee);
    error SameMakerFee(uint48 makerFee);
    error SameFeeRecipient(address feeRecipient);
    error UnsupportedChain(uint64 chainSelector);
    error InvalidSender(bytes32 expectedSender, bytes32 actualSender);
    error InvalidTaker(bytes32 expectedTaker, bytes32 actualTaker);
    error NativeTransferFailed();
    error FeeTooHigh(uint256 fee, uint256 maxFee);
    error InsufficientNative(uint256 value, uint256 fee);
    error InvalidFeeToken(address feeToken);
    error InvalidAmounts(uint256 makerAmount, uint256 takerAmount);
    error FeeNonNative();

    event OrderCreated(uint256 indexed orderId, Party maker, Party taker);
    event OrderFilled(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);
    event TakerFeeSet(uint48 takerFee);
    event MakerFeeSet(uint48 makerFee);
    event FeeRecipientSet(address feeRecipient);
    event CCIPActionReceived(CCIPAction action, uint256 indexed orderId);
    event TokensSent(uint64 indexed chainSelector, bytes32 indexed account, Client.EVMTokenAmount[] tokenAmounts);
    event TokenStored(bytes32 indexed account, address indexed token, uint256 amount);
    event TokenWithdrawn(bytes32 indexed account, address indexed token, uint256 amount);

    enum CCIPAction {
        SendToken,
        FillOrder
    }

    enum State {
        Invalid,
        Created,
        Filled,
        Cancelled
    }

    struct Party {
        bytes32 account;
        address token;
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
    address public immutable link;

    uint256 private _orderCount;

    uint48 private _takerFee;
    uint48 private _makerFee;
    address private _feeRecipient;

    mapping(uint256 => Order) private _orders;
    mapping(bytes32 => mapping(address => uint256)) private _balances;

    constructor(
        address router,
        uint64 chainSelector,
        address linkToken,
        uint48 makerFee,
        uint48 takerFee,
        address feeRecipient
    ) CCIPBase(router) {
        currentChainSelector = chainSelector;
        link = linkToken;

        if (makerFee != 0) _setMakerFee(makerFee);
        if (takerFee != 0) _setTakerFee(takerFee);

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

    function getFeeRecipient() external view returns (address feeRecipient) {
        return _feeRecipient;
    }

    function getBalance(bytes32 account, address token) external view returns (uint256 balance) {
        return _balances[account][token];
    }

    function getNextOrderId() external view returns (uint256 orderId) {
        return _orderCount;
    }

    function createOrder(Party calldata maker, Party calldata taker) external returns (uint256 orderId) {
        orderId = _orderCount++;

        _verifySender(maker.account, msg.sender.toBytes32());
        _verifyToken(maker.token);
        _verifyToken(taker.token);
        _verifyAmounts(maker.amount, taker.amount);

        _orders[orderId] = Order({state: State.Created, maker: maker, taker: taker});

        maker.token.safeTransferFrom(msg.sender, address(this), maker.amount);

        emit OrderCreated(orderId, maker, taker);
    }

    function fillOrder(
        uint64 chainSelector,
        uint256 orderId,
        address token,
        uint256 amount,
        address feeToken,
        uint256 maxFee,
        uint256 gasLimit
    ) external payable returns (bool) {
        if (chainSelector == currentChainSelector) {
            _fillOrder(orderId);
            _handleFee(feeToken, maxFee, 0);
            return true;
        }

        _verifyToken(token);

        bytes32 targetContract = _getTargetContract(chainSelector);
        if (targetContract == 0) revert UnsupportedChain(chainSelector);

        token.safeTransferFrom(msg.sender, address(this), amount);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        _ccipSend(
            chainSelector,
            targetContract,
            abi.encode(CCIPAction.FillOrder, msg.sender.toBytes32(), orderId),
            tokenAmounts,
            feeToken,
            maxFee,
            gasLimit
        );

        return true;
    }

    function cancelOrder(uint256 orderId) external returns (bool) {
        Order storage order = _orders[orderId];

        State state = order.state;

        _verifyState(State.Created, state);
        _verifySender(order.maker.account, msg.sender.toBytes32());

        order.state = State.Cancelled;

        IERC20(order.maker.token).safeTransfer(order.maker.account.toAddress(), order.maker.amount);

        emit OrderCancelled(orderId);

        return true;
    }

    function sendTokens(
        uint64 chainSelector,
        bytes32 account,
        Client.EVMTokenAmount[] calldata tokenAmounts,
        address feeToken,
        uint256 maxFee,
        uint256 gasLimit
    ) external payable returns (bool) {
        for (uint256 i = 0; i < tokenAmounts.length; i++) {
            _balances[msg.sender.toBytes32()][tokenAmounts[i].token] -= tokenAmounts[i].amount; // todo this would not work if sent by a non evm chain

            emit TokenWithdrawn(msg.sender.toBytes32(), tokenAmounts[i].token, tokenAmounts[i].amount);
        }

        address accountAddress = account.toAddress();

        if (chainSelector == currentChainSelector) {
            for (uint256 i = 0; i < tokenAmounts.length; i++) {
                IERC20(tokenAmounts[i].token).safeTransfer(accountAddress, tokenAmounts[i].amount);
            }
            _handleFee(feeToken, maxFee, 0);
        } else {
            bytes32 targetContract = _getTargetContract(chainSelector);
            if (targetContract == 0) revert UnsupportedChain(chainSelector);

            _ccipSend(
                chainSelector,
                targetContract,
                abi.encode(CCIPAction.SendToken, account, 0),
                tokenAmounts,
                feeToken,
                maxFee,
                gasLimit
            );
        }

        emit TokensSent(chainSelector, account, tokenAmounts);

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

    receive() external payable {}

    function call(address target, uint256 value, bytes calldata data) external onlyOwner {
        // todo remove this when testing is done
        (bool success,) = target.call{value: value}(data);
        require(success, "call failed");
    }

    function _verifyState(State expected, State actual) private pure {
        if (expected != actual) revert InvalidState(expected, actual);
    }

    function _verifySender(bytes32 expectedSender, bytes32 actualSender) private pure {
        if (expectedSender != actualSender) revert InvalidSender(expectedSender, actualSender);
    }

    function _verifyToken(address token) private view {
        if (!_isTrustedToken(token)) revert UntrustedToken(token);
    }

    function _verifyAmounts(uint256 makerAmount, uint256 takerAmount) private pure {
        if (makerAmount == 0 || takerAmount == 0) revert InvalidAmounts(makerAmount, takerAmount);
    }

    function _isOrderFillable(State state, Party memory taker, bytes32 sender, address token, uint256 amount)
        private
        pure
        returns (bool)
    {
        return state == State.Created && (taker.account == 0 || taker.account == sender) && taker.token == token
            && taker.amount == amount;
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

        _verifyState(State.Created, state);

        bytes32 takerAccount = order.taker.account;

        if (takerAccount == 0) order.taker.account = msg.sender.toBytes32();
        else if (takerAccount != msg.sender.toBytes32()) revert InvalidTaker(takerAccount, msg.sender.toBytes32());

        order.state = State.Filled;

        uint256 makerAmount = order.maker.amount;
        uint256 takerAmount = order.taker.amount;

        uint256 makerFee = (makerAmount * _takerFee) / BASIS_POINTS;
        uint256 takerFee = (takerAmount * _makerFee) / BASIS_POINTS;

        IERC20 makerToken = IERC20(order.maker.token);
        IERC20 takerToken = IERC20(order.taker.token);

        if (makerFee > 0) makerToken.safeTransfer(_feeRecipient, makerFee);
        if (takerFee > 0) takerToken.safeTransferFrom(msg.sender, _feeRecipient, takerFee);

        makerToken.safeTransfer(order.taker.account.toAddress(), makerAmount - makerFee);
        takerToken.safeTransferFrom(msg.sender, order.maker.account.toAddress(), takerAmount - takerFee);

        emit OrderFilled(orderId);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        _verifySender(_getTargetContract(message.sourceChainSelector), message.sender.toBytes32());

        (CCIPAction action, bytes32 account, uint256 orderId) = abi.decode(message.data, (CCIPAction, bytes32, uint256));

        if (action == CCIPAction.FillOrder) {
            _fillOrderMultiChain(message, account, orderId);
        } else if (action == CCIPAction.SendToken) {
            for (uint256 i = 0; i < message.destTokenAmounts.length; i++) {
                IERC20(message.destTokenAmounts[i].token).safeTransfer(
                    account.toAddress(), message.destTokenAmounts[i].amount
                );
            }
        }

        emit CCIPActionReceived(action, orderId);
    }

    function _fillOrderMultiChain(Client.Any2EVMMessage memory message, bytes32 sender, uint256 orderId) private {
        Order storage order = _orders[orderId];

        address makerToken = message.destTokenAmounts[0].token;
        uint256 makerAmount = message.destTokenAmounts[0].amount;

        if (!_isOrderFillable(order.state, order.taker, sender, makerToken, makerAmount)) {
            _storeToken(sender, makerToken, makerAmount);
        } else {
            order.state = State.Filled;
            order.taker.account = sender;

            address takerToken = order.maker.token;

            uint256 takerAmount = order.maker.amount;
            uint256 takerFee = (takerAmount * _takerFee) / BASIS_POINTS;

            if (takerFee > 0) IERC20(takerToken).safeTransfer(_feeRecipient, takerFee);
            _storeToken(sender, takerToken, takerAmount - takerFee);

            uint256 makerFee = (makerAmount * _makerFee) / BASIS_POINTS;

            if (makerFee > 0) IERC20(makerToken).safeTransfer(_feeRecipient, makerFee);
            IERC20(makerToken).safeTransfer(order.maker.account.toAddress(), makerAmount - makerFee);
        }
    }

    function _storeToken(bytes32 account, address token, uint256 amount) private {
        _balances[account][token] += amount;

        emit TokenStored(account, token, amount);
    }

    function _handleFee(address feeToken, uint256 maxFee, uint256 fee) internal override {
        if (fee > maxFee) revert FeeTooHigh(fee, maxFee);

        if (feeToken == address(0)) {
            if (msg.value < fee) revert InsufficientNative(msg.value, fee);

            if (msg.value > fee) _transferNative(msg.sender, msg.value - fee);
        } else {
            if (feeToken != link) revert InvalidFeeToken(feeToken);
            if (msg.value > 0) revert FeeNonNative();

            if (fee > 0) IERC20(feeToken).safeTransferFrom(msg.sender, address(this), fee);
        }
    }

    function _transferNative(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}("");
        if (!success) revert NativeTransferFailed();
    }
}
