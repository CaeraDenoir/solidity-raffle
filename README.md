# Foundry Lottery

This is a Foundry project based on the Patrick Collins Solidity Course.
The objective is to create a provable random smart contract lottery winner.

## Installation

You will need [git](https://github.com/git-guides/install-git) and [Foundry](https://book.getfoundry.sh/getting-started/installation) installed for this project to work.

Once those are installed, you should be able to have access to the entire project by using this commands:

```bash
git clone https://github.com/CaeraDenoir/solidity-raffle.git
cd solidity-raffle
forge build
```

## Objectives
1. Users can join the lottery by paying some eth
2. The winner will receive all the ticket fees since the last winner
3. The winner will be determined every X period of time
4. The random generated number will be created by the use of Chainlink VRF. [See example](https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number#create-and-fund-a-subscription)
5. The automation needed to trigger the contract after X period of time will be based on Chainlink Automation. [See example](https://docs.chain.link/quickstarts/time-based-upkeep)
