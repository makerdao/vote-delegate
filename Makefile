all            :; DAPP_BUILD_OPTIMIZE=1 DAPP_BUILD_OPTIMIZE_RUNS=200 dapp --use solc:0.6.12 build
clean          :; dapp clean
test           :; ./test.sh $(match) $(runs)
deploy-mainnet :; make && dapp create VoteDelegateFactory 0x0a3f6849f78076aefaDf113F5BED87720274dDC0 0xD3A9FE267852281a1e6307a1C37CDfD76d39b133
deploy-kovan   :; make && dapp create VoteDelegateFactory 0x27E0c9567729Ea6e3241DE74B3dE499b7ddd3fe6 0xD931E7c869618dB6FD30cfE4e89248CAA091Ea5f
flatten        :; hevm flatten --source-file src/VoteDelegateFactory.sol > out/VoteDelegateFactory-flattened.sol
