forge verify-contract --watch \
  --verifier blockscout \
  --chain-id 592 \
  --verifier-url 'https://astar.blockscout.com/api/' \
  0x106f8F8499eEf9318a2BAF3995cA6f24389CFfFe \
  src/lottery-neuro.sol:LotteryIDO
