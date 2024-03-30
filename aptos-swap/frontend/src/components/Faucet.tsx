import { useWallet } from '@aptos-labs/wallet-adapter-react'
import { Button } from 'antd'

const faucet_contract =
  '0x0629b1b00b749a903909aab5ccd68a453b874cce963dffce03e38e318bf348b6'
let faucet_map = [
  {
    name: 'USDC',
    coin_type: `${faucet_contract}::faucet::USDC`,
  },

  {
    name: 'WETH',
    coin_type: `${faucet_contract}::faucet::WETH`,
  },
  {
    name: 'WBTC',
    coin_type: `${faucet_contract}::faucet::WBTC`,
  },
  ,
]

export function Faucet() {
  const { signAndSubmitTransaction } = useWallet()

  return (
    <>
      <div className="tradeBox">
        <div className="tradeBoxHeader">
          <h4>Faucet</h4>
        </div>
        <div className="inputs gap-4">
          {faucet_map.map((item, index) => (
              <Button
              key={index}
                onClick={async () => {
                  try {
                    await signAndSubmitTransaction({
                      // @ts-ignore
                      data: {
                        function: `${faucet_contract}::faucet::mint`,
                        typeArguments: [item?.coin_type || ''],
                        functionArguments: ['1000000000'],
                      },
                    })
                  } catch (e) {
                    console.log(e)
                  }
                }}
              >
                {item?.name}
              </Button>
          ))}
        </div>
      </div>
    </>
  )
}
