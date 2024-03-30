import { AptosConfig, Network, Aptos } from "@aptos-labs/ts-sdk"

export const contract =
  '0x77ebedd6a221df5ac3b31eeaa688d5af8696a0296e475500cf89ced93eb59ddc'
export const chef_contract = "0xae253c60cc171bebefb5d08cf7c4c18f295bd74cc577931143159b541606bbea";
export const config = new AptosConfig({ network: Network.TESTNET })
export const aptos = new Aptos(config)