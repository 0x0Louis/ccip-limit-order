import { defineConfig } from "@wagmi/cli";
import { erc, react } from "@wagmi/cli/plugins";

export default defineConfig({
  out: "src/generated.ts",
  plugins: [erc(), react()],
  contracts: [
    {
      abi: [
        {
          inputs: [
            {
              internalType: "address",
              name: "router",
              type: "address",
            },
            {
              internalType: "uint64",
              name: "chainSelector",
              type: "uint64",
            },
            {
              internalType: "address",
              name: "linkToken",
              type: "address",
            },
            {
              internalType: "uint48",
              name: "makerFee",
              type: "uint48",
            },
            {
              internalType: "uint48",
              name: "takerFee",
              type: "uint48",
            },
            {
              internalType: "address",
              name: "feeRecipient",
              type: "address",
            },
          ],
          stateMutability: "nonpayable",
          type: "constructor",
        },
        {
          inputs: [
            {
              internalType: "uint256",
              name: "fee",
              type: "uint256",
            },
            {
              internalType: "uint256",
              name: "maxFee",
              type: "uint256",
            },
          ],
          name: "FeeTooHigh",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "uint256",
              name: "value",
              type: "uint256",
            },
            {
              internalType: "uint256",
              name: "fee",
              type: "uint256",
            },
          ],
          name: "InsufficientNative",
          type: "error",
        },
        {
          inputs: [],
          name: "InvalidAddress",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "uint256",
              name: "makerAmount",
              type: "uint256",
            },
            {
              internalType: "uint256",
              name: "takerAmount",
              type: "uint256",
            },
          ],
          name: "InvalidAmounts",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "feeRecipient",
              type: "address",
            },
          ],
          name: "InvalidFeeRecipient",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "feeToken",
              type: "address",
            },
          ],
          name: "InvalidFeeToken",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "uint256",
              name: "expected",
              type: "uint256",
            },
            {
              internalType: "uint256",
              name: "actual",
              type: "uint256",
            },
          ],
          name: "InvalidLength",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "uint48",
              name: "makerFee",
              type: "uint48",
            },
          ],
          name: "InvalidMakerFee",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "router",
              type: "address",
            },
          ],
          name: "InvalidRouter",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "bytes32",
              name: "expectedSender",
              type: "bytes32",
            },
            {
              internalType: "bytes32",
              name: "actualSender",
              type: "bytes32",
            },
          ],
          name: "InvalidSender",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "enum CCIPLimitOrder.State",
              name: "expected",
              type: "uint8",
            },
            {
              internalType: "enum CCIPLimitOrder.State",
              name: "actual",
              type: "uint8",
            },
          ],
          name: "InvalidState",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "bytes32",
              name: "expectedTaker",
              type: "bytes32",
            },
            {
              internalType: "bytes32",
              name: "actualTaker",
              type: "bytes32",
            },
          ],
          name: "InvalidTaker",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "uint48",
              name: "takerFee",
              type: "uint48",
            },
          ],
          name: "InvalidTakerFee",
          type: "error",
        },
        {
          inputs: [],
          name: "NativeTransferFailed",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "feeRecipient",
              type: "address",
            },
          ],
          name: "SameFeeRecipient",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "uint48",
              name: "makerFee",
              type: "uint48",
            },
          ],
          name: "SameMakerFee",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "uint48",
              name: "takerFee",
              type: "uint48",
            },
          ],
          name: "SameTakerFee",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "bytes32",
              name: "targetContract",
              type: "bytes32",
            },
          ],
          name: "SameTargetContract",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "bool",
              name: "status",
              type: "bool",
            },
          ],
          name: "SameTrustedTokenStatus",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "uint64",
              name: "chainSelector",
              type: "uint64",
            },
          ],
          name: "UnsupportedChain",
          type: "error",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "token",
              type: "address",
            },
          ],
          name: "UntrustedToken",
          type: "error",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: false,
              internalType: "enum CCIPLimitOrder.CCIPAction",
              name: "action",
              type: "uint8",
            },
            {
              indexed: true,
              internalType: "uint256",
              name: "orderId",
              type: "uint256",
            },
          ],
          name: "CCIPActionReceived",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: false,
              internalType: "address",
              name: "feeRecipient",
              type: "address",
            },
          ],
          name: "FeeRecipientSet",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: false,
              internalType: "uint48",
              name: "makerFee",
              type: "uint48",
            },
          ],
          name: "MakerFeeSet",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "bytes32",
              name: "messageId",
              type: "bytes32",
            },
          ],
          name: "MessageSent",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "uint256",
              name: "orderId",
              type: "uint256",
            },
          ],
          name: "OrderCancelled",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "uint256",
              name: "orderId",
              type: "uint256",
            },
            {
              components: [
                {
                  internalType: "bytes32",
                  name: "account",
                  type: "bytes32",
                },
                {
                  internalType: "address",
                  name: "token",
                  type: "address",
                },
                {
                  internalType: "uint256",
                  name: "amount",
                  type: "uint256",
                },
              ],
              indexed: false,
              internalType: "struct CCIPLimitOrder.Party",
              name: "maker",
              type: "tuple",
            },
            {
              components: [
                {
                  internalType: "bytes32",
                  name: "account",
                  type: "bytes32",
                },
                {
                  internalType: "address",
                  name: "token",
                  type: "address",
                },
                {
                  internalType: "uint256",
                  name: "amount",
                  type: "uint256",
                },
              ],
              indexed: false,
              internalType: "struct CCIPLimitOrder.Party",
              name: "taker",
              type: "tuple",
            },
          ],
          name: "OrderCreated",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "uint256",
              name: "orderId",
              type: "uint256",
            },
          ],
          name: "OrderFilled",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "address",
              name: "previousOwner",
              type: "address",
            },
            {
              indexed: true,
              internalType: "address",
              name: "newOwner",
              type: "address",
            },
          ],
          name: "OwnershipTransferStarted",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "address",
              name: "previousOwner",
              type: "address",
            },
            {
              indexed: true,
              internalType: "address",
              name: "newOwner",
              type: "address",
            },
          ],
          name: "OwnershipTransferred",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: false,
              internalType: "uint48",
              name: "takerFee",
              type: "uint48",
            },
          ],
          name: "TakerFeeSet",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "uint64",
              name: "chainSelector",
              type: "uint64",
            },
            {
              indexed: true,
              internalType: "bytes32",
              name: "targetContract",
              type: "bytes32",
            },
          ],
          name: "TargetContractSet",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "bytes32",
              name: "account",
              type: "bytes32",
            },
            {
              indexed: true,
              internalType: "address",
              name: "token",
              type: "address",
            },
            {
              indexed: false,
              internalType: "uint256",
              name: "amount",
              type: "uint256",
            },
          ],
          name: "TokenStored",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "bytes32",
              name: "account",
              type: "bytes32",
            },
            {
              indexed: true,
              internalType: "address",
              name: "token",
              type: "address",
            },
            {
              indexed: false,
              internalType: "uint256",
              name: "amount",
              type: "uint256",
            },
          ],
          name: "TokenWithdrawn",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "uint64",
              name: "chainSelector",
              type: "uint64",
            },
            {
              indexed: true,
              internalType: "bytes32",
              name: "account",
              type: "bytes32",
            },
            {
              components: [
                {
                  internalType: "address",
                  name: "token",
                  type: "address",
                },
                {
                  internalType: "uint256",
                  name: "amount",
                  type: "uint256",
                },
              ],
              indexed: false,
              internalType: "struct Client.EVMTokenAmount[]",
              name: "tokenAmounts",
              type: "tuple[]",
            },
          ],
          name: "TokensSent",
          type: "event",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "address",
              name: "token",
              type: "address",
            },
            {
              indexed: false,
              internalType: "bool",
              name: "trusted",
              type: "bool",
            },
          ],
          name: "TrustedTokenSet",
          type: "event",
        },
        {
          inputs: [],
          name: "BASIS_POINTS",
          outputs: [
            {
              internalType: "uint256",
              name: "",
              type: "uint256",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "MAX_FEE",
          outputs: [
            {
              internalType: "uint256",
              name: "",
              type: "uint256",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "MIN_PENDING_FILL_DURATION",
          outputs: [
            {
              internalType: "uint256",
              name: "",
              type: "uint256",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "acceptOwnership",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "target",
              type: "address",
            },
            {
              internalType: "uint256",
              name: "value",
              type: "uint256",
            },
            {
              internalType: "bytes",
              name: "data",
              type: "bytes",
            },
          ],
          name: "call",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "uint256",
              name: "orderId",
              type: "uint256",
            },
          ],
          name: "cancelOrder",
          outputs: [
            {
              internalType: "bool",
              name: "",
              type: "bool",
            },
          ],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              components: [
                {
                  internalType: "bytes32",
                  name: "messageId",
                  type: "bytes32",
                },
                {
                  internalType: "uint64",
                  name: "sourceChainSelector",
                  type: "uint64",
                },
                {
                  internalType: "bytes",
                  name: "sender",
                  type: "bytes",
                },
                {
                  internalType: "bytes",
                  name: "data",
                  type: "bytes",
                },
                {
                  components: [
                    {
                      internalType: "address",
                      name: "token",
                      type: "address",
                    },
                    {
                      internalType: "uint256",
                      name: "amount",
                      type: "uint256",
                    },
                  ],
                  internalType: "struct Client.EVMTokenAmount[]",
                  name: "destTokenAmounts",
                  type: "tuple[]",
                },
              ],
              internalType: "struct Client.Any2EVMMessage",
              name: "message",
              type: "tuple",
            },
          ],
          name: "ccipReceive",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              components: [
                {
                  internalType: "bytes32",
                  name: "account",
                  type: "bytes32",
                },
                {
                  internalType: "address",
                  name: "token",
                  type: "address",
                },
                {
                  internalType: "uint256",
                  name: "amount",
                  type: "uint256",
                },
              ],
              internalType: "struct CCIPLimitOrder.Party",
              name: "maker",
              type: "tuple",
            },
            {
              components: [
                {
                  internalType: "bytes32",
                  name: "account",
                  type: "bytes32",
                },
                {
                  internalType: "address",
                  name: "token",
                  type: "address",
                },
                {
                  internalType: "uint256",
                  name: "amount",
                  type: "uint256",
                },
              ],
              internalType: "struct CCIPLimitOrder.Party",
              name: "taker",
              type: "tuple",
            },
          ],
          name: "createOrder",
          outputs: [
            {
              internalType: "uint256",
              name: "orderId",
              type: "uint256",
            },
          ],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [],
          name: "currentChainSelector",
          outputs: [
            {
              internalType: "uint64",
              name: "",
              type: "uint64",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "uint64",
              name: "chainSelector",
              type: "uint64",
            },
            {
              internalType: "uint256",
              name: "orderId",
              type: "uint256",
            },
            {
              internalType: "address",
              name: "token",
              type: "address",
            },
            {
              internalType: "uint256",
              name: "amount",
              type: "uint256",
            },
            {
              internalType: "address",
              name: "feeToken",
              type: "address",
            },
            {
              internalType: "uint256",
              name: "maxFee",
              type: "uint256",
            },
            {
              internalType: "uint256",
              name: "gasLimit",
              type: "uint256",
            },
          ],
          name: "fillOrder",
          outputs: [
            {
              internalType: "bool",
              name: "",
              type: "bool",
            },
          ],
          stateMutability: "payable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "bytes32",
              name: "account",
              type: "bytes32",
            },
            {
              internalType: "address",
              name: "token",
              type: "address",
            },
          ],
          name: "getBalance",
          outputs: [
            {
              internalType: "uint256",
              name: "balance",
              type: "uint256",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "getFeeRecipient",
          outputs: [
            {
              internalType: "address",
              name: "feeRecipient",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "getMakerFee",
          outputs: [
            {
              internalType: "uint48",
              name: "makerFee",
              type: "uint48",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "uint256",
              name: "orderId",
              type: "uint256",
            },
          ],
          name: "getOrder",
          outputs: [
            {
              components: [
                {
                  internalType: "enum CCIPLimitOrder.State",
                  name: "state",
                  type: "uint8",
                },
                {
                  components: [
                    {
                      internalType: "bytes32",
                      name: "account",
                      type: "bytes32",
                    },
                    {
                      internalType: "address",
                      name: "token",
                      type: "address",
                    },
                    {
                      internalType: "uint256",
                      name: "amount",
                      type: "uint256",
                    },
                  ],
                  internalType: "struct CCIPLimitOrder.Party",
                  name: "maker",
                  type: "tuple",
                },
                {
                  components: [
                    {
                      internalType: "bytes32",
                      name: "account",
                      type: "bytes32",
                    },
                    {
                      internalType: "address",
                      name: "token",
                      type: "address",
                    },
                    {
                      internalType: "uint256",
                      name: "amount",
                      type: "uint256",
                    },
                  ],
                  internalType: "struct CCIPLimitOrder.Party",
                  name: "taker",
                  type: "tuple",
                },
              ],
              internalType: "struct CCIPLimitOrder.Order",
              name: "",
              type: "tuple",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "getRouter",
          outputs: [
            {
              internalType: "address",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "getTakerFee",
          outputs: [
            {
              internalType: "uint48",
              name: "takerFee",
              type: "uint48",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "uint64",
              name: "chainSelector",
              type: "uint64",
            },
          ],
          name: "getTargetContract",
          outputs: [
            {
              internalType: "bytes32",
              name: "targetContract",
              type: "bytes32",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "token",
              type: "address",
            },
          ],
          name: "isTrustedToken",
          outputs: [
            {
              internalType: "bool",
              name: "trusted",
              type: "bool",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "link",
          outputs: [
            {
              internalType: "address",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "owner",
          outputs: [
            {
              internalType: "address",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "pendingOwner",
          outputs: [
            {
              internalType: "address",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "renounceOwnership",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "uint64",
              name: "chainSelector",
              type: "uint64",
            },
            {
              internalType: "bytes32",
              name: "account",
              type: "bytes32",
            },
            {
              components: [
                {
                  internalType: "address",
                  name: "token",
                  type: "address",
                },
                {
                  internalType: "uint256",
                  name: "amount",
                  type: "uint256",
                },
              ],
              internalType: "struct Client.EVMTokenAmount[]",
              name: "tokenAmounts",
              type: "tuple[]",
            },
            {
              internalType: "address",
              name: "feeToken",
              type: "address",
            },
            {
              internalType: "uint256",
              name: "maxFee",
              type: "uint256",
            },
            {
              internalType: "uint256",
              name: "gasLimit",
              type: "uint256",
            },
          ],
          name: "sendTokens",
          outputs: [
            {
              internalType: "bool",
              name: "",
              type: "bool",
            },
          ],
          stateMutability: "payable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "feeRecipient",
              type: "address",
            },
          ],
          name: "setFeeRecipient",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "uint48",
              name: "makerFee",
              type: "uint48",
            },
          ],
          name: "setMakerFee",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "uint48",
              name: "takerFee",
              type: "uint48",
            },
          ],
          name: "setTakerFee",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "uint64",
              name: "chainSelector",
              type: "uint64",
            },
            {
              internalType: "bytes32",
              name: "targetContract",
              type: "bytes32",
            },
          ],
          name: "setTargetContract",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "token",
              type: "address",
            },
            {
              internalType: "bool",
              name: "trusted",
              type: "bool",
            },
          ],
          name: "setTrustedToken",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "bytes4",
              name: "interfaceId",
              type: "bytes4",
            },
          ],
          name: "supportsInterface",
          outputs: [
            {
              internalType: "bool",
              name: "",
              type: "bool",
            },
          ],
          stateMutability: "pure",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "newOwner",
              type: "address",
            },
          ],
          name: "transferOwnership",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          stateMutability: "payable",
          type: "receive",
        },
      ],
      name: "CCIPLimitOrder",
    },
  ],
});
