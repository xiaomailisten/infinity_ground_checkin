// import { LCDClient, MnemonicKey, MsgCreate, Wallet, /* MsgCreate2 */ } from '@initia/initia.js';
// import * as fs from 'fs';
// import "dotenv/config";

// const path = `./out/Checkin.sol/Checkin.bin`;
// const lcdURL = process.env.LCD_URL;
// const gasPrices = process.env.GAS_PRICES;

// async function deploy() {
//   const lcd = new LCDClient(lcdURL!, {
//     gasPrices: gasPrices,
//     gasAdjustment: '1.5',
//   });

//   const key = new MnemonicKey({
//     mnemonic:
//       process.env.PRIVATE_KEY,
//   });
//   const wallet = new Wallet(lcd, key);

//   const codeBytes = fs.readFileSync(path, "utf-8");
//   const msgs = [
//     new MsgCreate(key.accAddress, codeBytes),
//   ];

//   // sign tx
//   const signedTx = await wallet.createAndSignTx({ msgs });
//   // send(broadcast) tx
//   lcd.tx.broadcastSync(signedTx).then(res => console.log(res));
//   // {
//   //   height: 0,
//   //   txhash: '162AA29DE237BD060EFEFFA862DBD07ECD1C562EBFDD965AD6C34DF856B53DC2',
//   //   raw_log: '[]'
//   // }
// }

// deploy();
