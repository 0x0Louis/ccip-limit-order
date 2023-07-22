// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/CCIPLimitOrder.sol";
import "../src/CCIPBase.sol";

contract CCIPLimitOrderTest is Test {
    using Bytes for address;

    uint64 public constant CHAIN_SELECTOR_A = 1111111111111111111;
    uint64 public constant CHAIN_SELECTOR_B = 2222222222222222222;

    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");

    address public immutable feeReceiverA = makeAddr("feeReceiverA");
    address public immutable feeReceiverB = makeAddr("feeReceiverB");

    MockForwarderRouter public forwarderRouterA;
    MockForwarderRouter public forwarderRouterB;

    MockERC20 public token1_A;
    MockERC20 public token2_A;
    MockERC20 public token1_B;
    MockERC20 public token2_B;

    CCIPLimitOrder public ccipLimitOrderA;
    CCIPLimitOrder public ccipLimitOrderB;

    function setUp() public {
        token1_A = new MockERC20("Token 1", "T1");
        token1_B = new MockERC20("Token 1", "T1");

        token2_A = new MockERC20("Token 2", "T2");
        token2_B = new MockERC20("Token 2", "T2");

        forwarderRouterA = new MockForwarderRouter(CHAIN_SELECTOR_A);
        forwarderRouterB = new MockForwarderRouter(CHAIN_SELECTOR_B);

        ccipLimitOrderA =
            new CCIPLimitOrder(address(forwarderRouterA), CHAIN_SELECTOR_A, address(1), 100, 200, feeReceiverA);
        ccipLimitOrderB =
            new CCIPLimitOrder(address(forwarderRouterB), CHAIN_SELECTOR_B, address(1), 300, 400, feeReceiverB);

        forwarderRouterA.setTargetContract(CHAIN_SELECTOR_B, address(forwarderRouterB));
        forwarderRouterB.setTargetContract(CHAIN_SELECTOR_A, address(forwarderRouterA));

        ccipLimitOrderA.setTargetContract(CHAIN_SELECTOR_B, address(ccipLimitOrderB).toBytes32());
        ccipLimitOrderB.setTargetContract(CHAIN_SELECTOR_A, address(ccipLimitOrderA).toBytes32());

        ccipLimitOrderA.setTrustedToken(address(token1_A), true);
        ccipLimitOrderA.setTrustedToken(address(token2_A), true);

        ccipLimitOrderB.setTrustedToken(address(token1_B), true);
        ccipLimitOrderB.setTrustedToken(address(token2_B), true);

        forwarderRouterA.setTargetToken(CHAIN_SELECTOR_B, address(token1_A), address(token1_B));
        forwarderRouterA.setTargetToken(CHAIN_SELECTOR_B, address(token2_A), address(token2_B));

        forwarderRouterB.setTargetToken(CHAIN_SELECTOR_A, address(token1_B), address(token1_A));
        forwarderRouterB.setTargetToken(CHAIN_SELECTOR_A, address(token2_B), address(token2_A));

        vm.label(address(ccipLimitOrderA), "ccipLimitOrderA");
        vm.label(address(ccipLimitOrderB), "ccipLimitOrderB");

        vm.label(address(token1_A), "token1_A");
        vm.label(address(token2_A), "token2_A");

        vm.label(address(token1_B), "token1_B");
        vm.label(address(token2_B), "token2_B");

        vm.label(address(forwarderRouterA), "forwarderRouterA");
        vm.label(address(forwarderRouterB), "forwarderRouterB");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function test_FillOrderSameChain() public {
        vm.startPrank(alice);
        token1_A.mint(alice, 1e18);
        token1_A.approve(address(ccipLimitOrderA), 1e18);

        CCIPLimitOrder.Party memory maker =
            CCIPLimitOrder.Party({account: alice.toBytes32(), token: address(token1_A), amount: 1e18});

        CCIPLimitOrder.Party memory taker = CCIPLimitOrder.Party({account: 0, token: address(token2_A), amount: 10e18});

        uint256 orderId = ccipLimitOrderA.createOrder(maker, taker);
        vm.stopPrank();

        assertEq(token1_A.balanceOf(address(ccipLimitOrderA)), 1e18, "test_FillOrderSameChain::1");
        assertEq(token2_A.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderSameChain::2");

        vm.startPrank(bob);
        token2_A.mint(bob, 10e18);
        token2_A.approve(address(ccipLimitOrderA), 10e18);

        ccipLimitOrderA.fillOrder{value: 10 ether}(
            CHAIN_SELECTOR_A, orderId, address(token2_A), 10e18, address(0), type(uint256).max, 200_000
        );
        vm.stopPrank();

        assertEq(token1_A.balanceOf(address(ccipLimitOrderA)), 0, "test_FillOrderSameChain::3");
        assertEq(token2_A.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderSameChain::4");
        assertEq(token1_A.balanceOf(bob), 1e18 * 98 / 100, "test_FillOrderSameChain::5");
        assertEq(token2_A.balanceOf(alice), 10e18 * 99 / 100, "test_FillOrderSameChain::6");
        assertEq(token1_A.balanceOf(feeReceiverA), 1e18 * 2 / 100, "test_FillOrderSameChain::7");
        assertEq(token2_A.balanceOf(feeReceiverA), 10e18 * 1 / 100, "test_FillOrderSameChain::8");
    }

    function test_FillOrderMultiChain() public {
        vm.startPrank(alice);
        token1_A.mint(alice, 1e18);
        token1_A.approve(address(ccipLimitOrderA), 1e18);

        CCIPLimitOrder.Party memory maker =
            CCIPLimitOrder.Party({account: alice.toBytes32(), token: address(token1_A), amount: 1e18});

        CCIPLimitOrder.Party memory taker = CCIPLimitOrder.Party({account: 0, token: address(token2_A), amount: 10e18});

        uint256 orderId = ccipLimitOrderA.createOrder(maker, taker);
        vm.stopPrank();

        vm.startPrank(bob);
        token2_B.mint(bob, 10e18);
        token2_B.approve(address(ccipLimitOrderB), 10e18);

        ccipLimitOrderB.fillOrder{value: 10 ether}(
            CHAIN_SELECTOR_A, orderId, address(token2_B), 10e18, address(0), type(uint256).max, 200_000
        );
        vm.stopPrank();

        assertEq(token1_A.balanceOf(address(ccipLimitOrderA)), 1e18, "test_FillOrderMultiChain::1");
        assertEq(token2_B.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderMultiChain::2");
        assertEq(token1_A.balanceOf(bob), 0, "test_FillOrderMultiChain::3");
        assertEq(token2_A.balanceOf(alice), 0, "test_FillOrderMultiChain::4");

        forwarderRouterA.routeMessage();

        assertEq(token1_A.balanceOf(address(ccipLimitOrderA)), 1e18 * 98 / 100, "test_FillOrderMultiChain::5");
        assertEq(token2_A.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderMultiChain::6");
        assertEq(token1_A.balanceOf(bob), 0, "test_FillOrderMultiChain::7");
        assertEq(token2_A.balanceOf(alice), 10e18 * 99 / 100, "test_FillOrderMultiChain::8");

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(token1_A), amount: 1e18 * 98 / 100});

        vm.prank(bob);
        ccipLimitOrderA.sendTokens{value: 10 ether}(
            CHAIN_SELECTOR_B, bob.toBytes32(), tokenAmounts, address(0), type(uint256).max, 200_000
        );

        assertEq(token1_A.balanceOf(address(ccipLimitOrderA)), 0, "test_FillOrderMultiChain::9");
        assertEq(token2_A.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderMultiChain::10");
        assertEq(token1_B.balanceOf(bob), 0, "test_FillOrderMultiChain::11");
        assertEq(token2_A.balanceOf(alice), 10e18 * 99 / 100, "test_FillOrderMultiChain::12");

        forwarderRouterB.routeMessage();

        assertEq(token1_A.balanceOf(address(ccipLimitOrderA)), 0, "test_FillOrderMultiChain::13");
        assertEq(token2_A.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderMultiChain::14");
        assertEq(token1_A.balanceOf(bob), 0, "test_FillOrderMultiChain::15");
        assertEq(token1_B.balanceOf(bob), 1e18 * 98 / 100, "test_FillOrderMultiChain::16");
        assertEq(token2_A.balanceOf(alice), 10e18 * 99 / 100, "test_FillOrderMultiChain::17");
        assertEq(token2_B.balanceOf(alice), 0, "test_FillOrderMultiChain::18");
    }

    // function test_revert_FillOrderMultiChain() public {
    //     vm.startPrank(alice);
    //     token1_A.mint(alice, 1e18);
    //     token1_A.approve(address(ccipLimitOrderA), 1e18);

    //     CCIPLimitOrder.Party memory maker =
    //         CCIPLimitOrder.Party({account: alice.toBytes32(), token: address(token1_A).toBytes32(), amount: 1e18});

    //     CCIPLimitOrder.Party memory taker =
    //         CCIPLimitOrder.Party({account: 0, token: address(token2_B).toBytes32(), amount: 10e18});

    //     uint256 orderId = ccipLimitOrderA.createOrder(maker, taker);
    //     vm.stopPrank();

    //     vm.startPrank(bob);
    //     token2_B.mint(bob, 10e18);
    //     token2_B.approve(address(ccipLimitOrderB), 10e18);

    //     ccipLimitOrderB.fillOrder(CHAIN_SELECTOR_A, orderId, address(token2_B).toBytes32(), 10e18);
    //     vm.stopPrank();

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             CCIPLimitOrder.InvalidSender.selector, Bytes.toBytes32(alice), Bytes.toBytes32(address(this))
    //         )
    //     );
    //     ccipLimitOrderA.cancelOrder(orderId);

    //     vm.prank(alice);
    //     ccipLimitOrderA.cancelOrder(orderId);

    //     vm.expectRevert(abi.encodeWithSelector(CCIPLimitOrder.InvalidState.selector, 1, 4));
    //     vm.prank(alice);
    //     ccipLimitOrderA.cancelOrder(orderId);

    //     vm.expectRevert(abi.encodeWithSelector(CCIPLimitOrder.InvalidState.selector, 1, 4));
    //     forwarderRouterA.routeMessage();

    //     vm.expectRevert(
    //         abi.encodeWithSelector(CCIPLimitOrder.NoPendingFill.selector, address(this), CHAIN_SELECTOR_A, orderId)
    //     );
    //     ccipLimitOrderB.cancelPendingFill(CHAIN_SELECTOR_A, orderId);

    //     vm.expectRevert(CCIPLimitOrder.PendingFillNotExpired.selector);
    //     vm.prank(bob);
    //     ccipLimitOrderB.cancelPendingFill(CHAIN_SELECTOR_A, orderId);

    //     vm.warp(block.timestamp + ccipLimitOrderB.MIN_PENDING_FILL_DURATION());

    //     vm.prank(bob);
    //     ccipLimitOrderB.cancelPendingFill(CHAIN_SELECTOR_A, orderId);

    //     vm.expectRevert(abi.encodeWithSelector(CCIPLimitOrder.NoPendingFill.selector, bob, CHAIN_SELECTOR_A, orderId));
    //     vm.prank(bob);
    //     ccipLimitOrderB.cancelPendingFill(CHAIN_SELECTOR_A, orderId);

    //     vm.startPrank(alice);
    //     token1_A.mint(alice, 1e18);
    //     token1_A.approve(address(ccipLimitOrderA), 1e18);

    //     maker.account = bob.toBytes32();

    //     vm.expectRevert(
    //         abi.encodeWithSelector(CCIPLimitOrder.InvalidSender.selector, Bytes.toBytes32(bob), Bytes.toBytes32(alice))
    //     );
    //     ccipLimitOrderA.createOrder(maker, taker);

    //     maker.account = alice.toBytes32();

    //     orderId = ccipLimitOrderA.createOrder(maker, taker);
    //     vm.stopPrank();

    //     vm.startPrank(bob);
    //     token2_B.mint(bob, 10e18);
    //     token2_B.approve(address(ccipLimitOrderB), 10e18);

    //     ccipLimitOrderB.fillOrder(CHAIN_SELECTOR_A, orderId, address(token2_B).toBytes32(), 10e18);
    //     vm.stopPrank();

    //     forwarderRouterA.routeMessage();

    //     vm.expectRevert(abi.encodeWithSelector(CCIPLimitOrder.InvalidState.selector, 1, 2));
    //     vm.prank(alice);
    //     ccipLimitOrderA.cancelOrder(orderId);

    //     forwarderRouterB.routeMessage();

    //     vm.expectRevert(abi.encodeWithSelector(CCIPLimitOrder.InvalidState.selector, 1, 2));
    //     vm.prank(alice);
    //     ccipLimitOrderA.cancelOrder(orderId);

    //     forwarderRouterA.routeMessage();

    //     vm.expectRevert(abi.encodeWithSelector(CCIPLimitOrder.InvalidState.selector, 1, 3));
    //     vm.prank(alice);
    //     ccipLimitOrderA.cancelOrder(orderId);

    //     vm.startPrank(alice);
    //     token1_A.mint(alice, 1e18);
    //     token1_A.approve(address(ccipLimitOrderA), 1e18);
    //     token2_B.burn(alice, token2_B.balanceOf(alice));

    //     taker.account = charlie.toBytes32();

    //     orderId = ccipLimitOrderA.createOrder(maker, taker);
    //     vm.stopPrank();

    //     vm.startPrank(bob);
    //     token2_B.mint(bob, 10e18);
    //     token2_B.approve(address(ccipLimitOrderB), 10e18);

    //     vm.expectRevert(
    //         abi.encodeWithSelector(CCIPLimitOrder.InvalidTaker.selector, Bytes.toBytes32(charlie), Bytes.toBytes32(bob))
    //     );
    //     ccipLimitOrderA.fillOrder(CHAIN_SELECTOR_A, orderId, address(token2_B).toBytes32(), 10e18);

    //     ccipLimitOrderB.fillOrder(CHAIN_SELECTOR_A, orderId, address(token2_B).toBytes32(), 10e18);
    //     vm.stopPrank();

    //     vm.expectRevert(
    //         abi.encodeWithSelector(CCIPLimitOrder.InvalidTaker.selector, Bytes.toBytes32(charlie), Bytes.toBytes32(bob))
    //     );
    //     forwarderRouterA.routeMessage();

    //     vm.startPrank(charlie);
    //     token2_B.mint(charlie, 10e18);
    //     token2_B.approve(address(ccipLimitOrderB), 10e18);

    //     ccipLimitOrderB.fillOrder(CHAIN_SELECTOR_A, orderId, address(token2_B).toBytes32(), 10e18);
    //     vm.stopPrank();

    //     forwarderRouterA.routeMessage();
    //     forwarderRouterB.routeMessage();
    //     forwarderRouterA.routeMessage();

    //     assertEq(token1_A.balanceOf(charlie), 1e18 * 96 / 100, "test_revert_FillOrderMultiChain::3");
    //     assertEq(token2_B.balanceOf(alice), 10e18 * 99 / 100, "test_revert_FillOrderMultiChain::4");
    // }
}

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockForwarderRouter {
    using SafeERC20 for IERC20;

    uint64 public immutable currentChainSelector;
    mapping(uint64 => address) public targetContracts;
    mapping(uint64 => mapping(address => address)) public targetTokens;

    address public nextReceiver;
    Client.Any2EVMMessage public nextMessage;

    constructor(uint64 _currentChainSelector) {
        currentChainSelector = _currentChainSelector;
    }

    function setTargetContract(uint64 chainSelector, address targetContract) external {
        targetContracts[chainSelector] = targetContract;
    }

    function setTargetToken(uint64 chainSelector, address token, address targetToken) external {
        targetTokens[chainSelector][token] = targetToken;
    }

    function getFee(uint64 chainSelector, Client.EVM2AnyMessage calldata) external view returns (uint256 fee) {
        require(targetContracts[chainSelector] != address(0), "Unsupported chain");

        assembly {
            let size := calldatasize()
            fee := mul(mul(size, size), 1000000000000)
        }
    }

    function ccipSend(uint64 chainSelector, Client.EVM2AnyMessage calldata message)
        external
        payable
        returns (bytes32 messageId)
    {
        address targetContract = targetContracts[chainSelector];
        require(targetContract != address(0), "Unsupported chain");

        messageId = keccak256(abi.encode(message));

        address receiver = abi.decode(message.receiver, (address));

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](message.tokenAmounts.length);

        for (uint256 i = 0; i < message.tokenAmounts.length; i++) {
            MockERC20 token = MockERC20(message.tokenAmounts[i].token);
            MockERC20 targetToken = MockERC20(targetTokens[chainSelector][address(token)]);

            uint256 amount = message.tokenAmounts[i].amount;

            tokenAmounts[i] = Client.EVMTokenAmount({token: address(targetToken), amount: amount});

            token.burn(msg.sender, amount);
        }

        Client.Any2EVMMessage memory any2evmMessage = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: currentChainSelector,
            sender: abi.encode(msg.sender),
            data: message.data,
            destTokenAmounts: tokenAmounts
        });

        MockForwarderRouter(payable(targetContract)).setNextMessage(receiver, any2evmMessage);
    }

    function setNextMessage(address receiver, Client.Any2EVMMessage calldata message) external {
        nextReceiver = receiver;
        nextMessage = message;
    }

    function routeMessage() external {
        Client.Any2EVMMessage memory message = nextMessage;
        address receiver = nextReceiver;

        require(nextReceiver != address(0), "No message to route");

        delete nextMessage;
        delete nextReceiver;

        for (uint256 i = 0; i < message.destTokenAmounts.length; i++) {
            address token = message.destTokenAmounts[i].token;
            uint256 amount = message.destTokenAmounts[i].amount;

            MockERC20(token).mint(receiver, amount);
        }

        CCIPReceiver(receiver).ccipReceive(message);
    }
}
