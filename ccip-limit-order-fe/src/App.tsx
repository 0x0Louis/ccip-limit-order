import { useAccount } from "wagmi";

import { Account } from "./components/Account";
import { Connect } from "./components/Connect";
import { NetworkSwitcher } from "./components/NetworkSwitcher";
import { CCIPLimitOrder } from "./components/CCIPLimitOrder";

export function App() {
  const { isConnected } = useAccount();

  return (
    <>
      <h1>CCIP Limit Order</h1>

      <Connect />

      {isConnected && (
        <>
          <Account />
          <NetworkSwitcher />
          <CCIPLimitOrder />
        </>
      )}
    </>
  );
}
