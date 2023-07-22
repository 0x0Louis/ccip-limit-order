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

    address public immutable feeReceiverA = makeAddr("feeReceiverA");
    address public immutable feeReceiverB = makeAddr("feeReceiverB");

    MockForwarderRouter public forwarderRouterA;
    MockForwarderRouter public forwarderRouterB;

    MockERC20 public tokenA;
    MockERC20 public tokenB;

    CCIPLimitOrder public ccipLimitOrderA;
    CCIPLimitOrder public ccipLimitOrderB;

    function setUp() public {
        tokenA = new MockERC20("Token A", "TA");
        tokenB = new MockERC20("Token B", "TB");

        forwarderRouterA = new MockForwarderRouter(CHAIN_SELECTOR_A);
        forwarderRouterB = new MockForwarderRouter(CHAIN_SELECTOR_B);

        ccipLimitOrderA = new CCIPLimitOrder(address(forwarderRouterA), CHAIN_SELECTOR_A, 0, 0, feeReceiverA);
        ccipLimitOrderB = new CCIPLimitOrder(address(forwarderRouterB), CHAIN_SELECTOR_B, 0, 0, feeReceiverB);

        forwarderRouterA.setTargetContract(CHAIN_SELECTOR_B, address(forwarderRouterB));
        forwarderRouterB.setTargetContract(CHAIN_SELECTOR_A, address(forwarderRouterA));

        ccipLimitOrderA.setTargetContract(CHAIN_SELECTOR_B, address(ccipLimitOrderB).toBytes32());
        ccipLimitOrderB.setTargetContract(CHAIN_SELECTOR_A, address(ccipLimitOrderA).toBytes32());

        ccipLimitOrderA.setFeeToken(address(1));
        ccipLimitOrderB.setFeeToken(address(1));

        ccipLimitOrderA.setTrustedToken(address(tokenA), true);
        ccipLimitOrderA.setTrustedToken(address(tokenB), true);

        ccipLimitOrderB.setTrustedToken(address(tokenA), true);
        ccipLimitOrderB.setTrustedToken(address(tokenB), true);

        vm.label(address(ccipLimitOrderA), "ccipLimitOrderA");
        vm.label(address(ccipLimitOrderB), "ccipLimitOrderB");

        vm.label(address(tokenA), "tokenA");
        vm.label(address(tokenB), "tokenB");

        vm.label(address(forwarderRouterA), "forwarderRouterA");
        vm.label(address(forwarderRouterB), "forwarderRouterB");
    }

    function test_FillOrderSameChain() public {
        vm.startPrank(alice);
        tokenA.mint(alice, 1e18);
        tokenA.approve(address(ccipLimitOrderA), 1e18);

        CCIPLimitOrder.Party memory maker =
            CCIPLimitOrder.Party({account: alice.toBytes32(), token: address(tokenA).toBytes32(), amount: 1e18});

        CCIPLimitOrder.Party memory taker =
            CCIPLimitOrder.Party({account: 0, token: address(tokenB).toBytes32(), amount: 10e18});

        uint256 orderId = ccipLimitOrderA.createOrder(maker, taker);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(address(ccipLimitOrderA)), 1e18, "test_FillOrderSameChain::1");
        assertEq(tokenB.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderSameChain::2");

        vm.startPrank(bob);
        tokenB.mint(bob, 10e18);
        tokenB.approve(address(ccipLimitOrderA), 10e18);

        ccipLimitOrderA.fillOrder(CHAIN_SELECTOR_A, orderId, address(tokenB).toBytes32(), 10e18);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(address(ccipLimitOrderA)), 0, "test_FillOrderSameChain::3");
        assertEq(tokenB.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderSameChain::4");
        assertEq(tokenA.balanceOf(bob), 1e18, "test_FillOrderSameChain::5");
        assertEq(tokenB.balanceOf(alice), 10e18, "test_FillOrderSameChain::6");
    }

    function test_FillOrderMultiChain() public {
        vm.startPrank(alice);
        tokenA.mint(alice, 1e18);
        tokenA.approve(address(ccipLimitOrderA), 1e18);

        CCIPLimitOrder.Party memory maker =
            CCIPLimitOrder.Party({account: alice.toBytes32(), token: address(tokenA).toBytes32(), amount: 1e18});

        CCIPLimitOrder.Party memory taker =
            CCIPLimitOrder.Party({account: 0, token: address(tokenB).toBytes32(), amount: 10e18});

        uint256 orderId = ccipLimitOrderA.createOrder(maker, taker);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenB.mint(bob, 10e18);
        tokenB.approve(address(ccipLimitOrderB), 10e18);

        ccipLimitOrderB.fillOrder(CHAIN_SELECTOR_A, orderId, address(tokenB).toBytes32(), 10e18);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(address(ccipLimitOrderA)), 1e18, "test_FillOrderMultiChain::1");
        assertEq(tokenB.balanceOf(address(ccipLimitOrderB)), 10e18, "test_FillOrderMultiChain::2");
        assertEq(tokenA.balanceOf(bob), 0, "test_FillOrderMultiChain::3");
        assertEq(tokenB.balanceOf(alice), 0, "test_FillOrderMultiChain::4");

        forwarderRouterA.routeMessage();

        assertEq(tokenA.balanceOf(address(ccipLimitOrderA)), 0, "test_FillOrderMultiChain::5");
        assertEq(tokenB.balanceOf(address(ccipLimitOrderB)), 10e18, "test_FillOrderMultiChain::6");
        assertEq(tokenA.balanceOf(bob), 0, "test_FillOrderMultiChain::7");
        assertEq(tokenB.balanceOf(alice), 0, "test_FillOrderMultiChain::8");

        forwarderRouterB.routeMessage();

        assertEq(tokenA.balanceOf(address(ccipLimitOrderA)), 0, "test_FillOrderMultiChain::9");
        assertEq(tokenB.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderMultiChain::10");
        assertEq(tokenA.balanceOf(bob), 1e18, "test_FillOrderMultiChain::11");
        assertEq(tokenB.balanceOf(alice), 0, "test_FillOrderMultiChain::12");

        forwarderRouterA.routeMessage();

        assertEq(tokenA.balanceOf(address(ccipLimitOrderA)), 0, "test_FillOrderMultiChain::13");
        assertEq(tokenB.balanceOf(address(ccipLimitOrderB)), 0, "test_FillOrderMultiChain::14");
        assertEq(tokenA.balanceOf(bob), 1e18, "test_FillOrderMultiChain::15");
        assertEq(tokenB.balanceOf(alice), 10e18, "test_FillOrderMultiChain::16");
    }
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

    address public nextReceiver;
    Client.Any2EVMMessage public nextMessage;

    constructor(uint64 _currentChainSelector) {
        currentChainSelector = _currentChainSelector;
    }

    function setTargetContract(uint64 chainSelector, address targetContract) external {
        targetContracts[chainSelector] = targetContract;
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
        returns (bytes32 messageId)
    {
        address targetContract = targetContracts[chainSelector];
        require(targetContract != address(0), "Unsupported chain");

        messageId = keccak256(abi.encode(message));

        address receiver = abi.decode(message.receiver, (address));

        Client.Any2EVMMessage memory any2evmMessage = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: currentChainSelector,
            sender: abi.encode(msg.sender),
            data: message.data,
            destTokenAmounts: message.tokenAmounts
        });

        for (uint256 i = 0; i < message.tokenAmounts.length; i++) {
            IERC20 token = IERC20(message.tokenAmounts[i].token);
            uint256 amount = message.tokenAmounts[i].amount;

            token.safeTransferFrom(msg.sender, address(this), amount);
            token.safeTransfer(targetContract, amount);
        }

        MockForwarderRouter(targetContract).setNextMessage(receiver, any2evmMessage);
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
            IERC20 token = IERC20(message.destTokenAmounts[i].token);
            uint256 amount = message.destTokenAmounts[i].amount;

            IERC20(token).safeTransfer(receiver, amount);
        }

        CCIPReceiver(receiver).ccipReceive(message);
    }
}
