import { ethers } from 'ethers';
import * as fs from 'fs';
import * as csv from 'csv-parse/sync';

// ABI の一部（setResult 関数に関連する部分のみ）
const abi = [
  {
    inputs: [{
      components: [
        { internalType: "address", name: "addr", type: "address" },
        { internalType: "uint256", name: "amount", type: "uint256" },
        { internalType: "uint256[]", name: "wonTicketsAmount", type: "uint256[]" }
      ],
      internalType: "struct YourContract.SetResultArgs[]",
      name: "_data",
      type: "tuple[]"
    }],
    name: "setResult",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  }
];

interface CSVData {
  address: string;
  finalTokens: string;
  wonTickets: string;
}

async function setResultFromCSV(csvFilePath: string, contractAddress: string, privateKey: string) {
  // CSVファイルを読み込む
  const fileContent = fs.readFileSync(csvFilePath, 'utf-8');
  const records = csv.parse(fileContent, { columns: true, skip_empty_lines: true }) as CSVData[];

  // プロバイダーとウォレットをセットアップ
  const provider = new ethers.JsonRpcProvider(RPC);
  const wallet = new ethers.Wallet(privateKey, provider);

  // コントラクトインスタンスを作成
  const contract = new ethers.Contract(contractAddress, abi, wallet);

  // CSVデータを SetResultArgs[] 形式に変換
  const setResultArgs = records.map(record => ({
    addr: record.address,
    amount: ethers.parseUnits(record.finalTokens, 18), // トークンの小数点以下の桁数に応じて調整
    wonTicketsAmount: [ethers.parseUnits(record.wonTickets, 0)]
  }));

  try {
    // setResult 関数を呼び出し
    const tx = await contract.setResult(setResultArgs);
    console.log('Transaction sent:', tx.hash);
    await tx.wait();
    console.log('Transaction confirmed');
  } catch (error) {
    console.error('Error calling setResult:', error);
  }
}

// 使用例
const RPC = "https://rpc.startale.com/astar-zkevm";
const csvFilePath = 'setResult.csv';
const contractAddress = '0xc731958B9E93Fa65599C3A5DBfCeB0916DCD4980';

setResultFromCSV(csvFilePath, contractAddress, process.env.PRIVATE_KEY!).catch(console.error);