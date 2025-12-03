Below is a complete, self-contained Solidity contract.
This implementation includes campaign creation, contributing (pledging), withdrawing funds by the campaign creator if the funding goal is met, and refunds to contributors if the goal is not met after the deadline. It includes events, comments, and simple reentrancy protection.
**Quick explanation (how it works)**

    Create a campaign: any address calls createCampaign(title, description, goalInWei, durationInSeconds). campaignCount assigns an id.
    
    Pledge: anyone can call pledge(campaignId) and send ETH (value) to contribute before the campaign ends.
    
    Unpledge: contributors can partially withdraw their pledge before the campaign ends (optional feature).
    
    Withdraw: after the campaign ends, if pledged ≥ goal, the campaign creator can call withdraw(id) to take all funds.
    
    Refund: after the campaign ends, if pledged < goal, contributors call refund(id) to get their contributed ETH back.

**Security:**

    Uses a simple nonReentrant guard (prevents reentrancy).
    
    Uses checks-effects-interactions pattern in critical functions.
    
    Solidity 0.8.x built-in overflow checks.
Deploy & test on Remix + MetaMask (step-by-step)

Open Remix

Go to https://remix.ethereum.org

Create file

In the File Explorer, create a new file named Crowdfunding.sol.

Paste the code above into that file.

Compiler

Click the Solidity Compiler tab.

Select a compiler version 0.8.17 (or any 0.8.x compiler compatible with pragma ^0.8.17).

Click Compile Crowdfunding.sol. You should see a green check if successful.

Deploy using MetaMask

Click the Deploy & Run Transactions tab.

For Environment, choose Injected Provider - MetaMask.

This will prompt MetaMask to connect to Remix (choose the account to use).

Ensure your MetaMask is connected to a testnet (e.g., Sepolia) or a local network. Do not use mainnet unless you intend to pay real ETH.

Gas & value can be left as default.

Click Deploy. MetaMask will open a confirmation — confirm the transaction. Wait for the transaction to be mined (MetaMask shows progress).

Interact

Once deployed, the deployed contract appears under Deployed Contracts.

Use createCampaign(...) to make a campaign. Example:

_title: "My First Campaign"

_description: "Fund my project"

_goal: 1000000000000000000 (1 ETH in wei)

_durationSeconds: 604800 (7 days in seconds)

To contribute: open pledge for id = 1. Enter an amount in the Remix Value input (e.g., 0.1 ETH) and choose ETH unit, then click pledge. MetaMask will confirm the payment.

After the campaign ends:

If funding reached, the creator uses withdraw(1).

If not reached, contributors call refund(1).

Testing tips

To simulate time passing in a test environment: use a test RPC like Ganache or Hardhat node and increase time. On public testnets, you must wait for wall-clock time (or recreate campaigns with small durations like 120 seconds for quick test).

Check events in Remix transaction logs to verify Pledged, FundsWithdrawn, etc.

