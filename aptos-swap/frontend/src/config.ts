import { AptosConfig, Network, Aptos } from '@aptos-labs/ts-sdk'

export const contract =
  '0x77ebedd6a221df5ac3b31eeaa688d5af8696a0296e475500cf89ced93eb59ddc'
export const chef_contract =
  '0x2ca33c1d60dd10cf152d776da451ba6295e527c13d479632d977ce342365e962'

export const ve_contract =
  '0x47afb2cba83b1e111800a68e59c910e80e84186f61dffe9584393abbf8fdc3de'

export const vote_contract =
  '0x1fd985dff3af603d6363878b0258704b8b72a1ed2f9bdac888b0c8d8daf3e943'

export const config = new AptosConfig({ network: Network.TESTNET })
export const aptos = new Aptos(config)
