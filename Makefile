-include .env

.PHONY: all test deploy deploy_erc20 anvil help

help :; @echo "make help | test | deploy | deploy_erc20 | anvil"

test :; forge test 

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# # Ethereum Testnet Sepolia
# ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
# 	NETWORK_ARGS := --rpc-url $(ETHERSCAN_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
# endif

# Mantle Testnet Sepolia
# ifeq ($(findstring --network mantle-sepolia,$(ARGS)),--network mantle-sepolia)
# 	NETWORK_ARGS := --rpc-url $(MANTLESCAN_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/5003/etherscan' --etherscan-api-key "verifyContract" --skip-simulation -vvvv
# endif

# Mantle Mainnet
# ifeq ($(findstring --network mainnet,$(ARGS)),--network mainnet)
# 	NETWORK_ARGS := --rpc-url $(MANTLESCAN_MAINNET_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/5000/etherscan' --etherscan-api-key "verifyContract" --skip-simulation -vvvv
# endif

# Arbitrum Mainnet
ifeq ($(findstring --network arbitrum,$(ARGS)),--network arbitrum)
	NETWORK_ARGS := --rpc-url $(ARBITRUM_MAINNET_RPC_URL) --private-key $(PRIVATE_KEY) --chain-id 42161 --broadcast --verify -vvv 
endif

# Arbitrum Testnet Sepolia
ifeq ($(findstring --network arbitrum-sepolia,$(ARGS)),--network arbitrum-sepolia)
	NETWORK_ARGS := --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --chain-id 421614 --broadcast --verify -vvv 
endif

# make deploy ARGS="--network sepolia/mantle-sepolia/mainnet" 
deploy:
	@forge script script/DeployESAPEX12.s.sol:DeployESAPEX12 $(NETWORK_ARGS)

deploy_erc20:
	@forge script script/DeployERC20.s.sol:DeployERC20 $(NETWORK_ARGS)


# forge verify-contract --etherscan-api-key Y6UJSMIG4TU11KXGBDKU4N7TCTK8ZQK8YF  --verifier-url 'https://api-sepolia.arbiscan.io/api' --chain-id 421614 0xDa25B0b35C78a573e99001eE5b451dFc70858380 USDTMock