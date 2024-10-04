PATH := ~/.solc-select/artifacts/solc-0.8.21:$(PATH)
certora-vote-delegate         :; PATH=${PATH} certoraRun certora/VoteDelegate.conf$(if $(rule), --rule $(rule),)$(if $(results), --wait_for_results all,)
certora-vote-delegate-factory :; PATH=${PATH} certoraRun certora/VoteDelegateFactory.conf$(if $(rule), --rule $(rule),)$(if $(results), --wait_for_results all,)
