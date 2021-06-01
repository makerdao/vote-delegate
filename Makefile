all     :; dapp --use solc:0.6.12 build
clean   :; dapp clean
test    :; dapp --use solc:0.6.12 test --rpc -v --fuzz-runs $(runs)
deploy  :; make && dapp create VoteDelegateFactory
