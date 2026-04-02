# PAU Deployment Makefile
#
# Prerequisites:
#   - ETH_FROM: deployer address
#   - *_RPC_URL: chain-specific RPC URLs
#   - foundry keystore account named "deployer"
#
# Deployment order:
#   1. deploy-factory  (once per chain)
#   2. deploy-pau      (once per star per chain, needs factory address in input JSON)
#   3. deploy-facets   (once per star per chain)

# --------------------------------------------------------------------------------------------------
# Build & Test																					   #
# --------------------------------------------------------------------------------------------------

build:
	forge build

test:
	forge test

clean:
	forge clean

# --------------------------------------------------------------------------------------------------
# Deploy: PAU Factory																			   #
# --------------------------------------------------------------------------------------------------
# Deploys PAUFactory contract. No input needed.
# Output: script/output/{chainId}/pau-factory-{chain}-{env}.json

# Mainnet

deploy-factory-mainnet-production:
	CHAIN=mainnet ENV=production forge script script/DeployPAUFactory.s.sol:DeployPAUFactory \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

deploy-factory-mainnet-staging:
	CHAIN=mainnet ENV=staging forge script script/DeployPAUFactory.s.sol:DeployPAUFactory \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

# Base

deploy-factory-base-production:
	CHAIN=base ENV=production forge script script/DeployPAUFactory.s.sol:DeployPAUFactory \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(BASE_RPC_URL)

deploy-factory-base-staging:
	CHAIN=base ENV=staging forge script script/DeployPAUFactory.s.sol:DeployPAUFactory \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(BASE_RPC_URL)

# Arbitrum

deploy-factory-arbitrum-production:
	CHAIN=arbitrum_one ENV=production forge script script/DeployPAUFactory.s.sol:DeployPAUFactory \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(ARBITRUM_RPC_URL)

deploy-factory-arbitrum-staging:
	CHAIN=arbitrum_one ENV=staging forge script script/DeployPAUFactory.s.sol:DeployPAUFactory \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(ARBITRUM_RPC_URL)

# Avalanche

deploy-factory-avalanche-production:
	CHAIN=avalanche ENV=production forge script script/DeployPAUFactory.s.sol:DeployPAUFactory \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(AVALANCHE_RPC_URL)

deploy-factory-avalanche-staging:
	CHAIN=avalanche ENV=staging forge script script/DeployPAUFactory.s.sol:DeployPAUFactory \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(AVALANCHE_RPC_URL)

# --------------------------------------------------------------------------------------------------
# Deploy: PAU System for Spark																	   #
# --------------------------------------------------------------------------------------------------
# Deploys Controller, AccessControls, ALMProxy, RateLimits via PAUFactory.
# Input:  script/input/{chainId}/spark-pau-{chain}-{env}.json
# Output: script/output/{chainId}/spark-pau-{chain}-{env}.json
#
# Requires factory address in the input JSON.
# Run AFTER deploy-factory.

# Mainnet

deploy-pau-mainnet-production:
	CHAIN=mainnet ENV=production STAR=spark forge script script/DeployPAU.s.sol:DeployPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

deploy-pau-mainnet-staging:
	CHAIN=mainnet ENV=staging STAR=spark forge script script/DeployPAU.s.sol:DeployPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

# Base

deploy-pau-base-production:
	CHAIN=base ENV=production STAR=spark forge script script/DeployPAU.s.sol:DeployPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(BASE_RPC_URL)

deploy-pau-base-staging:
	CHAIN=base ENV=staging STAR=spark forge script script/DeployPAU.s.sol:DeployPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(BASE_RPC_URL)

# Arbitrum

deploy-pau-arbitrum-production:
	CHAIN=arbitrum_one ENV=production STAR=spark forge script script/DeployPAU.s.sol:DeployPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(ARBITRUM_RPC_URL)

deploy-pau-arbitrum-staging:
	CHAIN=arbitrum_one ENV=staging STAR=spark forge script script/DeployPAU.s.sol:DeployPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(ARBITRUM_RPC_URL)

# Avalanche

deploy-pau-avalanche-production:
	CHAIN=avalanche ENV=production STAR=spark forge script script/DeployPAU.s.sol:DeployPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(AVALANCHE_RPC_URL)

deploy-pau-avalanche-staging:
	CHAIN=avalanche ENV=staging STAR=spark forge script script/DeployPAU.s.sol:DeployPAU \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(AVALANCHE_RPC_URL)

# --------------------------------------------------------------------------------------------------
# Deploy: Spark Facets																			   #
# --------------------------------------------------------------------------------------------------
# Deploys protocol integration facets for Spark.
# No input needed. Constructor args from spark-address-registry.
# Output: script/output/{chainid}/spark-facets-{chain}-{env}.json

# Mainnet

deploy-spark-facets-mainnet-production:
	ENV=production forge script script/spark/DeployMainnetFacets.s.sol:DeployMainnetFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

deploy-spark-facets-mainnet-staging:
	ENV=staging forge script script/spark/DeployMainnetFacets.s.sol:DeployMainnetFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(MAINNET_RPC_URL)

# Base

deploy-spark-facets-base-production:
	ENV=production forge script script/spark/DeployBaseFacets.s.sol:DeployBaseFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(BASE_RPC_URL)

deploy-spark-facets-base-staging:
	ENV=staging forge script script/spark/DeployBaseFacets.s.sol:DeployBaseFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(BASE_RPC_URL)

# Arbitrum

deploy-spark-facets-arbitrum-production:
	ENV=production forge script script/spark/DeployArbitrumFacets.s.sol:DeployArbitrumFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(ARBITRUM_RPC_URL)

deploy-spark-facets-arbitrum-staging:
	ENV=staging forge script script/spark/DeployArbitrumFacets.s.sol:DeployArbitrumFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(ARBITRUM_RPC_URL)

# Avalanche

deploy-spark-facets-avalanche-production:
	ENV=production forge script script/spark/DeployAvalancheFacets.s.sol:DeployAvalancheFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(AVALANCHE_RPC_URL)

deploy-spark-facets-avalanche-staging:
	ENV=staging forge script script/spark/DeployAvalancheFacets.s.sol:DeployAvalancheFacets \
		--sender $(ETH_FROM) --account deployer --broadcast --verify --rpc-url $(AVALANCHE_RPC_URL)
