# Foundry DeFi Stablecoin

[![CI](https://github.com/tohidul3417/foundry-defi-stablecoin/actions/workflows/test.yml/badge.svg)](https://github.com/tohidul3417/foundry-defi-stablecoin/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## About The Project

This project implements a decentralized, over-collateralized stablecoin, **DecentralizedStableCoin (DSC)**, using the [Foundry](https://github.com/foundry-rs/foundry) development framework. The system is designed to maintain a 1:1 peg with the US Dollar through an algorithmic and autonomous protocol.

Users can deposit exogenous collateral (like WETH and WBTC) into the `DSCEngine` to mint DSC. The system ensures stability by requiring positions to be over-collateralized and by enabling a liquidation mechanism for under-collateralized positions. Asset prices are sourced reliably using [Chainlink Price Feeds](https://docs.chain.link/data-feeds).

This repository serves as a learning exercise and was completed as a part of the **Advanced Foundry** course's (offered by Cyfrin Updraft) *Develop a DeFi Protocol* section.

### System Architecture

The core of the system consists of two main smart contracts:

-   `DecentralizedStableCoin.sol` (`DSC`): An ERC20 token that represents the stablecoin. The `DSCEngine` is the sole owner and has the exclusive right to mint or burn DSC tokens.
-   `DSCEngine.sol`: The core logic contract that handles all major functions:
    -   Collateral deposits and withdrawals.
    -   Minting DSC against collateral.
    -   Burning DSC to redeem collateral.
    -   A liquidation mechanism to maintain protocol solvency.

---

## Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing.

### Prerequisites

You will need to have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed. Foundry is a blazing fast, portable, and modular toolkit for Ethereum application development written in Rust.

-   **Foundry (Forge & Anvil)**
    ```sh
    curl -L [https://foundry.paradigm.xyz](https://foundry.paradigm.xyz) | bash
    foundryup
    ```

### Installation & Setup

1.  **Clone the repository:**
    ```sh
    git clone [https://github.com/tohidul3417/foundry-defi-stablecoin.git](https://github.com/tohidul3417/foundry-defi-stablecoin.git)
    cd foundry-defi-stablecoin
    ```

2.  **Install dependencies and build the project:**
    This single command will download the necessary libraries (like OpenZeppelin and Chainlink) and compile the contracts.
    ```sh
    forge build
    ```

---

## Usage

Foundry's `forge` is the primary tool for interacting with the contracts.

### Building

If you've already run the setup, you can re-compile the smart contracts at any time by running:
```sh
forge build
````

This will compile the contracts and place the artifacts in the `out/` directory, as specified in `foundry.toml`.

### Testing

This project includes a comprehensive test suite covering unit tests, integration tests, and invariant (fuzz) tests.

  - **Run all tests:**

    ` sh     forge test      `

  - **Run tests with more detailed output:**
    For a more verbose output including logs from `console.log`, you can use the `-vvv` flag.

    ` sh     forge test -vvv      `

### Deployment

To deploy the contracts, you can use `forge script`. You will need to set up your environment for a network RPC URL and a secure way to handle your private key.

1.  **Start a local node (optional, for local testing):**
    This command will spin up a local Anvil instance, providing you with local accounts and an RPC URL.

    ```sh
    anvil
    ```

2.  **Set up your environment variables:**
    Create a file named `.env` in the root of the project. This file will hold your RPC URL and any other necessary environment variables.

    ```bash
    touch .env
    ```

    Add your RPC URL to your new `.env` file, replacing the placeholder value:

    ```
    SEPOLIA_RPC_URL="YOUR_SEPOLIA_RPC_URL"
    ```

### ⚠️ Advanced Security: The Professional Workflow for Key Management

Storing a plain-text `PRIVATE_KEY` in a `.env` file is a significant security risk. If that file is ever accidentally committed to GitHub, shared, or compromised, any funds associated with that key will be stolen instantly.

The professional standard is to **never store a private key in plain text**. Instead, we use Foundry's built-in **keystore** functionality, which encrypts your key with a password you choose.

Here is the clear, step-by-step process:

#### **Step 1: Create Your Encrypted Keystore**

This command generates a new private key and immediately encrypts it, saving it as a secure JSON file.

1.  **Run the creation command:**

    ```bash
    cast wallet new
    ```

2.  **Enter a strong password:**
    The terminal will prompt you to enter and then confirm a strong password. **This is the only thing that can unlock your key.** Store this password in a secure password manager (like 1Password or Bitwarden).

3.  **Secure the output:**
    The command will output your new wallet's **public address** and the **path** to the encrypted JSON file (usually in `~/.foundry/keystores/`).

      - Save the public address. You will need it to send funds to your new secure wallet.
      - Note the filename of the keystore file.

At this point, your private key exists only in its encrypted form. It is no longer in plain text on your machine.

#### **Step 2: Fund Your New Secure Wallet**

Use a faucet or another wallet to send some testnet ETH to the new **public address** you just generated.

#### **Step 3: Use Your Keystore Securely for Deployments**

Now, when you need to send a transaction (like deploying a contract), you will tell Foundry to use your encrypted keystore. Your private key is **never** passed through the command line or stored in a file.

1.  **Construct the command:**
    Use the `--keystore` flag to point to your encrypted file and the `--ask-pass` flag to tell Foundry to securely prompt you for your password.

2.  **Example Deployment Command:**

    ```bash
    # This command deploys the contracts on Sepolia
    forge script script/DeployDSC.s.sol \
        --rpc-url $SEPOLIA_RPC_URL \
        --keystore ~/.foundry/keystores/UTC--2025-07-27T...--your-wallet-address.json \
        --ask-pass \
        --broadcast \
        --verify \
        -vvvv
    ```

3.  **Enter your password when prompted:**
    Foundry will pause and securely ask for the password you created in Step 1.

**The Atomic Security Insight:** When you run this command, Foundry reads the encrypted file, asks for your password in memory, uses it to decrypt the private key for the single purpose of signing the transaction, and then immediately discards the decrypted key. The private key never touches your shell history or any unencrypted files. This is a vastly more secure workflow.

-----

## Continuous Integration

This repository has a CI pipeline configured in `.github/workflows/test.yml`. The workflow is triggered on every `push` and `pull_request` to the `main` branch and performs the following checks:

1.  Installs Foundry.
2.  Runs the formatter to check for consistent styling (`forge fmt --check`).
3.  Builds the project to ensure compilation (`forge build --sizes`).
4.  Runs the full test suite (`forge test -vvv`).

This ensures that the codebase remains consistent and that all tests pass before merging new changes.

-----

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

-----

## ⚠️ Security Disclaimer

This project was built for educational purposes and has **not** been audited. Do not use in a production environment or with real funds. Always conduct a full, professional security audit before deploying any smart contracts.

-----

## License

This project is distributed under the MIT License. See `LICENSE` for more information.
