forge verify-contract --watch \
  --verifier etherscan \
  --api-key $API_KEY \
  --via-ir \
  --chain-id 1 \
  --constructor-args-path script/eth/constructor-args.txt \
  0xe344dfc5906904af2186c7ee62a5754af119a4e3 \
  src/lottery-neuro.sol:LotteryIDO