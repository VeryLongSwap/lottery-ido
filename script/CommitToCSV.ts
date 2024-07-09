import * as fs from 'fs';

interface AddressData {
  address: string;
  amount: string;
  staking: string;
}

function convertJsonToCsv(inputFile: string, outputFile: string): void {
  // JSONファイルを読み込む
  const jsonData: string = fs.readFileSync(inputFile, 'utf-8');
  const data: AddressData[] = JSON.parse(jsonData);

  // CSVヘッダーを作成
  const csvHeader = 'address,amount,staking\n';

  // データ行を作成
  const csvRows = data.map(row =>
    `${row.address},${row.amount}, ${row.staking}`
  ).join('\n');

  // CSVデータを作成
  const csvData = csvHeader + csvRows;

  // CSVファイルに書き込む
  fs.writeFileSync(outputFile, csvData, 'utf-8');

  console.log(`CSVファイルが作成されました: ${outputFile}`);
}

// 使用例
const inputFile = 'result0709.json';
const outputFile = 'commit.csv';
convertJsonToCsv(inputFile, outputFile);