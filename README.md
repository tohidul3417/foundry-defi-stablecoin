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

    ```sh
    forge test
    ```

  - **Run tests with more detailed output:**
    For a more verbose output including logs from `console.log`, you can use the `-vvv` flag.

    ```sh
    forge test -vvv
    ```

### Deployment

To deploy the contracts, you can use `forge script`. You will need to set up environment variables for your private key and a network RPC URL.

1.  **Start a local node (optional, for local testing):**
    This command will spin up a local Anvil instance, providing you with local accounts and an RPC URL.

    ```sh
    anvil
    ```

2.  **Deploy the contracts:**
    Create a `.env` file in the root directory and populate it with your `PRIVATE_KEY` and an `RPC_URL` (e.g., from Infura, Alchemy, or your local Anvil node).

    ```env
    SEPOLIA_RPC_URL=your_rpc_url
    PRIVATE_KEY=your_private_key
    ```

    Then, run the deployment script. The script is configured to use the appropriate addresses for either a live network (like Sepolia) or a local Anvil instance.

    ```sh
    # Example for deploying to Sepolia
    forge script script/DeployDSC.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify -vvvv
    ```

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

## License

This project is distributed under the MIT License. See `LICENSE` for more information.

```
