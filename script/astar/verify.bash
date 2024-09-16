forge verify-contract --watch \
  --verifier blockscout \
  --chain-id 592 \
  --verifier-url 'https://astar.blockscout.com/api/' \
  0x0f0Db3bcbA4B768fb7a1b6d690BA560C33e8B0eB \
  src/lottery-neuro.sol:LotteryIDO
