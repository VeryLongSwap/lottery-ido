forge verify-contract --watch \
  --verifier etherscan \
  --api-key $API_KEY \
  --via-ir \
  --chain-id 1 \
  --constructor-args-path script/eth/constructor-args.txt \
  0x4f518a09a9732e4c19aeb3598cf5349651b0a827 \
  src/lottery-neuro.sol:LotteryIDO