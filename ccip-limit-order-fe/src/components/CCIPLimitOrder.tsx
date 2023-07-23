import { useState } from "react";
import { Address, useAccount, useNetwork, useWaitForTransaction } from "wagmi";

import {
  useCcipLimitOrderGetBalance,
  useCcipLimitOrderGetOrder,
  usePrepareCcipLimitOrderCreateOrder,
  useCcipLimitOrderCreateOrder,
  usePrepareCcipLimitOrderCancelOrder,
  useCcipLimitOrderCancelOrder,
  usePrepareCcipLimitOrderFillOrder,
  useCcipLimitOrderFillOrder,
  usePrepareCcipLimitOrderSendTokens,
  useCcipLimitOrderSendTokens,
  useCcipLimitOrderCurrentChainSelector,
  useErc20Allowance,
  usePrepareErc20Approve,
  useErc20Approve,
} from "../generated";

export function CCIPLimitOrder() {
  const { address } = useAccount();
  const [contractAddress] = useState<Address>(
    "0x943a837698851f90696e20f009b3bdCB13eE4B27"
  );
  const [state, setState] = useState<BigInt>(BigInt(1));

  return (
    <div>
      Contract Address: {contractAddress}
      <LOCurrentChainSelector contractAddress={contractAddress} />
      <h3>Internal Balance</h3>
      <LOGetBalance contractAddress={contractAddress} />
      <h3>Info</h3>
      <LOGetOrder contractAddress={contractAddress} />
      <h3>Actions</h3>
      <button onClick={() => setState(BigInt(1))}>Create Order</button>
      <button onClick={() => setState(BigInt(2))}>Cancel Order</button>
      <button onClick={() => setState(BigInt(3))}>Fill Order</button>
      <button onClick={() => setState(BigInt(4))}>Claim Tokens</button>
      <button onClick={() => setState(BigInt(5))}>Approve Tokens</button>
      {state === BigInt(1) && (
        <LOCreateOrder contractAddress={contractAddress} />
      )}
      {state === BigInt(2) && (
        <LOCancelOrder contractAddress={contractAddress} />
      )}
      {state === BigInt(3) && <LOFillOrder contractAddress={contractAddress} />}
      {state === BigInt(4) && (
        <LOClaimTokens contractAddress={contractAddress} />
      )}
      {state === BigInt(5) && <Allowance spender={contractAddress} />}
    </div>
  );
}

function LOClaimTokens({ contractAddress }: { contractAddress: Address }) {
  const { address } = useAccount();
  const [chainSelector, setChainSelector] = useState<string>();
  const [tokenAddress, setTokenAddress] = useState<Address>();
  const [amount, setAmount] = useState<string>();
  const [feeTokenAddress, setFeeTokenAddress] = useState<Address>(
    "0x0000000000000000000000000000000000000000"
  );
  const [maxFeeAmount, setMaxFeeAmount] = useState<string>(
    "1000000000000000000"
  );
  const [gasLimit, setGasLimit] = useState<string>("200000");

  const { config, error, isError } = usePrepareCcipLimitOrderSendTokens({
    address: contractAddress,
    args: [
      chainSelector,
      _convertToBytes32(address?.toString()),
      [[tokenAddress, amount]],
      feeTokenAddress,
      maxFeeAmount,
      gasLimit,
    ],
    enabled: Boolean(
      address &&
        chainSelector &&
        tokenAddress &&
        amount &&
        feeTokenAddress &&
        maxFeeAmount &&
        gasLimit
    ),
  });
  const { data, write } = useCcipLimitOrderSendTokens(config);

  const { isLoading, isSuccess } = useWaitForTransaction({
    hash: data?.hash,
  });

  return (
    <div>
      <h3>Claim Tokens</h3>
      <div>
        <input
          onChange={(e) => setChainSelector(e.target.value)}
          placeholder="Chain Selector"
          style={{ width: 400 }}
          value={chainSelector}
        />
      </div>
      <div>
        <input
          onChange={(e) => setTokenAddress(e.target.value as Address)}
          placeholder="Token Address"
          style={{ width: 400 }}
          value={tokenAddress}
        />
      </div>
      <div>
        <input
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Amount"
          style={{ width: 400 }}
          value={amount}
        />
      </div>

      <div>
        <input
          onChange={(e) => setFeeTokenAddress(e.target.value as Address)}
          placeholder="Fee Token Address"
          style={{ width: 400 }}
          value={feeTokenAddress}
        />
      </div>
      <div>
        <input
          onChange={(e) => setMaxFeeAmount(e.target.value)}
          placeholder="Max Fee Amount"
          style={{ width: 400 }}
          value={maxFeeAmount}
        />
      </div>
      <div>
        <input
          onChange={(e) => setGasLimit(e.target.value)}
          placeholder="Gas Limit"
          style={{ width: 400 }}
          value={gasLimit}
        />
      </div>

      <button disabled={isLoading && !write} onClick={() => write?.()}>
        Claim Tokens
      </button>
      {isLoading && <ProcessingMessage hash={data?.hash} />}
      {isSuccess && <div>Success!</div>}
      {isError && <div>Error: {error?.message}</div>}
    </div>
  );
}

function LOFillOrder({ contractAddress }: { contractAddress: Address }) {
  const { address } = useAccount();
  const [chainSelector, setChainSelector] = useState<string>();
  const [orderId, setOrderId] = useState<string>();
  const [takerTokenAddress, setTakerTokenAddress] = useState<Address>();
  const [takerAmount, setTakerAmount] = useState<string>();
  const [feeTokenAddress, setFeeTokenAddress] = useState<Address>(
    "0x0000000000000000000000000000000000000000"
  );
  const [maxFeeAmount, setMaxFeeAmount] = useState<string>(
    "1000000000000000000"
  );
  const [gasLimit, setGasLimit] = useState<string>("200000");

  const { config, error, isError } = usePrepareCcipLimitOrderFillOrder({
    address: contractAddress,
    args: [
      chainSelector,
      orderId,
      takerTokenAddress,
      takerAmount,
      feeTokenAddress,
      maxFeeAmount,
      gasLimit,
    ],
    enabled: Boolean(
      address &&
        chainSelector &&
        orderId &&
        takerTokenAddress &&
        takerAmount &&
        feeTokenAddress &&
        maxFeeAmount &&
        gasLimit
    ),
  });
  const { data, write } = useCcipLimitOrderFillOrder(config);

  const { isLoading, isSuccess } = useWaitForTransaction({
    hash: data?.hash,
  });

  return (
    <div>
      <h3>Fill Order</h3>
      <div>
        <input
          onChange={(e) => setChainSelector(e.target.value)}
          placeholder="Chain Selector"
          style={{ width: 400 }}
          value={chainSelector}
        />
      </div>
      <div>
        <input
          onChange={(e) => setOrderId(e.target.value)}
          placeholder="Order ID"
          style={{ width: 400 }}
          value={orderId}
        />
      </div>
      <div>
        <input
          onChange={(e) => setTakerTokenAddress(e.target.value as Address)}
          placeholder="Taker Token Address"
          style={{ width: 400 }}
          value={takerTokenAddress}
        />
      </div>
      <div>
        <input
          onChange={(e) => setTakerAmount(e.target.value)}
          placeholder="Taker Amount"
          style={{ width: 400 }}
          value={takerAmount}
        />
      </div>
      <div>
        <input
          onChange={(e) => setFeeTokenAddress(e.target.value as Address)}
          placeholder="Fee Token Address"
          style={{ width: 400 }}
          value={feeTokenAddress}
        />
      </div>
      <div>
        <input
          onChange={(e) => setMaxFeeAmount(e.target.value)}
          placeholder="Max Fee Amount"
          style={{ width: 400 }}
          value={maxFeeAmount}
        />
      </div>
      <div>
        <input
          onChange={(e) => setGasLimit(e.target.value)}
          placeholder="Gas Limit"
          style={{ width: 400 }}
          value={gasLimit}
        />
      </div>
      <button disabled={isLoading && !write} onClick={() => write?.()}>
        Fill Order
      </button>
      {isLoading && <ProcessingMessage hash={data?.hash} />}
      {isSuccess && <div>Success!</div>}
      {isError && <div>Error: {error?.message}</div>}
    </div>
  );
}

function LOCancelOrder({ contractAddress }: { contractAddress: Address }) {
  const { address } = useAccount();
  const [orderId, setOrderId] = useState<string>();

  const { config, error, isError } = usePrepareCcipLimitOrderCancelOrder({
    address: contractAddress,
    args: [orderId],
    enabled: Boolean(address && orderId),
  });
  const { data, write } = useCcipLimitOrderCancelOrder(config);

  const { isLoading, isSuccess } = useWaitForTransaction({
    hash: data?.hash,
  });

  return (
    <div>
      <h3>Cancel Order</h3>
      <div>
        <input
          onChange={(e) => setOrderId(e.target.value)}
          placeholder="Order ID"
          style={{ width: 400 }}
          value={orderId}
        />
      </div>
      <button disabled={isLoading && !write} onClick={() => write?.()}>
        Cancel Order
      </button>
      {isLoading && <ProcessingMessage hash={data?.hash} />}
      {isSuccess && <div>Success!</div>}
      {isError && <div>Error: {error?.message}</div>}
    </div>
  );
}

function LOCreateOrder({ contractAddress }: { contractAddress: Address }) {
  const { address } = useAccount();
  const [makerTokenAddress, setMakerTokenAddress] = useState<string>();
  const [makerAmount, setMakerAmount] = useState<string>();
  const [takerAddress, setTakerAddress] = useState<string>(
    "0x0000000000000000000000000000000000000000000000000000000000000000"
  );

  const [takerTokenAddress, setTakerTokenAddress] = useState<Address>();
  const [takerAmount, setTakerAmount] = useState<string>();

  const { config, error, isError } = usePrepareCcipLimitOrderCreateOrder({
    address: contractAddress,
    args: [
      [_convertToBytes32(address?.toString()), makerTokenAddress, makerAmount],
      [takerAddress, takerTokenAddress, takerAmount],
    ],
    enabled: Boolean(
      address &&
        makerTokenAddress &&
        makerAmount &&
        takerAddress &&
        takerTokenAddress &&
        takerAmount
    ),
  });
  const { data, write } = useCcipLimitOrderCreateOrder(config);

  const { isLoading, isSuccess } = useWaitForTransaction({
    hash: data?.hash,
  });

  return (
    <div>
      <h3>Create Order</h3>
      <h4>Maker Input</h4>
      <div>
        <input
          onChange={(e) => setMakerTokenAddress(e.target.value)}
          placeholder="Maker Token Address"
          style={{ width: 400 }}
          value={makerTokenAddress}
        />
      </div>
      <div>
        <input
          onChange={(e) => setMakerAmount(e.target.value)}
          placeholder="Maker Amount"
          style={{ width: 400 }}
          value={makerAmount}
        />
      </div>
      <h4>Taker Input</h4>
      <div>
        <input
          onChange={(e) => setTakerAddress(e.target.value)}
          placeholder="Taker Address"
          style={{ width: 500 }}
          value={takerAddress}
        />
      </div>
      <div>
        <input
          onChange={(e) => setTakerTokenAddress(e.target.value as Address)}
          placeholder="Taker Token Address"
          style={{ width: 400 }}
          value={takerTokenAddress}
        />
      </div>
      <div>
        <input
          onChange={(e) => setTakerAmount(e.target.value)}
          placeholder="Taker Amount"
          style={{ width: 400 }}
          value={takerAmount}
        />
      </div>
      <button disabled={isLoading && !write} onClick={() => write?.()}>
        Create Order
      </button>
      {isLoading && <ProcessingMessage hash={data?.hash} />}
      {isSuccess && <div>Success!</div>}
      {isError && <div>Error: {error?.message}</div>}
    </div>
  );
}

function LOGetBalance({ contractAddress }: { contractAddress: Address }) {
  const { address } = useAccount();
  const [tokenAddress, setTokenAddress] = useState<Address>(
    "0x0000000000000000000000000000000000000000"
  );

  const { data: balance } = useCcipLimitOrderGetBalance({
    address: contractAddress,
    args:
      address && tokenAddress
        ? [_convertToBytes32(address?.toString()), tokenAddress]
        : undefined,
    watch: true,
  });

  return (
    <div>
      Token:{" "}
      <input
        onChange={(e) => setTokenAddress(e.target.value as Address)}
        placeholder="Token Address"
        style={{ width: 400 }}
        value={tokenAddress}
      />
      <br />
      Balance: {balance?.toString()}
    </div>
  );
}

function LOGetOrder({ contractAddress }: { contractAddress: Address }) {
  const [orderId, setOrderId] = useState<string>("0");

  const { data: order } = useCcipLimitOrderGetOrder({
    address: contractAddress,
    args: orderId ? [orderId] : undefined,
    watch: true,
  });

  return (
    <div>
      Order ID:{" "}
      <input
        onChange={(e) => setOrderId(e.target.value)}
        placeholder="Order ID"
        style={{ width: 400 }}
        value={orderId}
      />
      <br />
      State: {_convertState(order?.state?.toString())}
      {order && order?.state.toString() !== "0" && (
        <OrderDetails order={order} />
      )}
    </div>
  );
}

function OrderDetails({ order }: { order: any }) {
  return (
    <div>
      MakerAccount: {order?.maker.account.toString()}
      <br />
      MakerToken: {order?.maker.token.toString()}
      <br />
      MakerAmount: {order?.maker.amount.toString()}
      <br />
      TakerAccount: {order?.taker.account.toString()}
      <br />
      TakerToken: {order?.taker.token.toString()}
      <br />
      TakerAmount: {order?.taker.amount.toString()}
      <br />
    </div>
  );
}

function Allowance({ spender }: { spender: Address }) {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");
  const [contractAddress, setContractAddress] = useState<Address>();

  const { config, error, isError } = usePrepareErc20Approve({
    address: contractAddress,
    args: spender && amount ? [spender, BigInt(amount)] : undefined,
    enabled: Boolean(spender && amount),
  });
  const { data, write } = useErc20Approve(config);

  const { isLoading, isSuccess } = useWaitForTransaction({
    hash: data?.hash,
  });

  const { data: balance } = useErc20Allowance({
    address: contractAddress,
    args: address && spender ? [address, spender] : undefined,
    watch: true,
  });

  return (
    <div>
      <h3>Approve Tokens</h3>
      <div>
        Token:{" "}
        <input
          onChange={(e) => setContractAddress(e.target.value as Address)}
          placeholder="Token Address"
          style={{ width: 400 }}
          value={contractAddress}
        />
      </div>
      <div>
        Set Allowance:{" "}
        <input
          disabled={isLoading}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="amount (units)"
          value={amount}
        />
        <button disabled={isLoading && !write} onClick={() => write?.()}>
          Approve
        </button>
        {isLoading && <ProcessingMessage hash={data?.hash} />}
        {isSuccess && <div>Success!</div>}
        {isError && <div>Error: {error?.message}</div>}
      </div>
      <div>Current Allowance: {balance?.toString()}</div>
    </div>
  );
}

function LOCurrentChainSelector({
  contractAddress,
}: {
  contractAddress: Address;
}) {
  const { data: chainSelector } = useCcipLimitOrderCurrentChainSelector({
    address: contractAddress,
    watch: true,
  });

  return <div>Current Chain Selector: {chainSelector?.toString()}</div>;
}

function _convertState(state: string): string {
  switch (state) {
    case "0":
      return "INVALID";
    case "1":
      return "OPEN";
    case "2":
      return "FILLED";
    case "3":
      return "CANCELLED";
  }
  return "UNKNOWN";
}

function _convertToBytes32(str: string): string {
  return "0x" + str.substring(2).padStart(64, "0");
}

function ProcessingMessage({ hash }: { hash?: `0x${string}` }) {
  const { chain } = useNetwork();
  const etherscan = chain?.blockExplorers?.etherscan;
  return (
    <span>
      Processing transaction...{" "}
      {etherscan && (
        <a href={`${etherscan.url}/tx/${hash}`}>{etherscan.name}</a>
      )}
    </span>
  );
}
