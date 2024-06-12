WIP Tezos Octez node setup and baking OVH x softstack x Tezos

This is the documentation for setting up a Tezos Baker/Validator node with a server from [OVH](https://www.ovh.com).
## Requirements
- High CPU performance for transaction processing
- Sufficient memory to handle blockchain data and operations
- Fast and reliable storage with SSD
- Good network performance

In numbers:
- 8 GB RAM
- 2 CPU cores (better 4 vCPU)
- Min. 256 GB SSD Drive
- Linux (Docker optional)
- Network min. 100 Mbps

History types for a node:
- **Rolling mode:** The most lightweight mode. It stores recent blocks with their current context.
- **Full mode (default mode):** It also stores the content of every block since genesis so that it can handle requests about them, or even recompute the ledger state of every block of the chain.
- **Archive mode:** Also stores the history of the context, allowing services like indexers to enquire about balances or staking rights from any past block.

Network types:
- Mainnet
- Oxfordnet was a testnet. Seems to be deprecated.
- Ghostnet is a permanent testnet for devs or bakers.

The node is intended for baking with no need to store content of every previous block. This is why the history type can be in **rolling** mode. Network type must be **mainnet**.

## Select OVH server

1. Got to [ovh.com](https://www.ovh.com)
- Select *Eco Dedicated Servers*
![[1-ovh-eco-dedicated-servers.png]]

2. Select *location* filter 
- Choose *Europe*
![[2-select-location.png]]

3. Select *Hardware* filter 
- Select min. **16GB** RAM
- Select **NVMe** storage for SSD
- Select min. **256GB** storage
![[3-select-hardware.png]]

4. Select suitable server
- Choose one with min. **100Mbps** bandwidth
- Press *Configure*
![[4-choose-server.png]]

5. Check order summary
- Proceed through the payment process.
![[5-complete-configuration-and-payment.png]]

## Deployment of a tezos node

1. Choose ovh server: **SYS-4-SSD-16** 
2. Login to server with ssh. Perform ssh hardening.
3. Installation and Setup of a node
4. Keep octez up to date
5. Monitor performance and activity
