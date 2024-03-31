import { Button, message } from 'antd'
import { useEffect, useState } from 'react'
import { aptos, ve_contract } from '../config'
import { useWallet } from '@aptos-labs/wallet-adapter-react'
import { parseUnits } from 'viem'

export function Ve() {
  const { submitTransaction, signTransaction, account } = useWallet()
  const [messageApi, contextHolder] = message.useMessage()
  const [isLoading, setIsLoading] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)
  const [isError, setIsError] = useState(false)

  const [stakeAmount, SetStakeAmount] = useState(0)

  useEffect(() => {
    messageApi.destroy()

    if (isLoading) {
      messageApi
        .open({
          type: 'loading',
          content: 'Transaction is Pending...',
          duration: 5,
        })
        .then(() => {
          setIsLoading(false)
        })
    }
  }, [isLoading])

  useEffect(() => {
    messageApi.destroy()
    if (isSuccess) {
      messageApi
        .open({
          type: 'success',
          content: 'Transaction Successful',
          duration: 1.5,
        })
        .then(() => {
          setIsSuccess(false)
          setIsLoading(false)
        })
    }
  }, [isSuccess])

  useEffect(() => {
    messageApi.destroy()
    if (isError) {
      messageApi
        .open({
          type: 'error',
          content: 'Transaction Failed',
          duration: 1.5,
        })
        .then(() => {
          setIsError(false)
          setIsLoading(false)
        })
    }
  }, [isError])
  return (
    <>
      {contextHolder}
      <div style={{ border: '1px solid #FFFFFF' }}>
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: '2rem',
            padding: '3rem',
          }}
        >
          <span style={{}}>Stake To VeQKA</span>
          <div
            style={{ display: 'flex', gap: '2rem', flexDirection: 'column' }}
          >
            <input
              type="number"
              min={0}
              placeholder="Stake Amount"
              value={stakeAmount}
              onChange={(e) => SetStakeAmount(Number(e.target.value))}
            />
            <Button
              onClick={async () => {
                //send
                setIsLoading(true)

                let txn_wait_sign = await aptos.transaction.build.simple({
                  sender: account?.address || '',
                  data: {
                    function: `${ve_contract}::veqka::stake`,
                    typeArguments: [],
                    functionArguments: [
                      24 * 60 * 60 * 365 * 2,
                      parseUnits(stakeAmount.toString(), 8).toString(),
                    ],
                  },
                })

                let txn_with_sign = await signTransaction(txn_wait_sign)

                submitTransaction({
                  transaction: txn_wait_sign,
                  senderAuthenticator: txn_with_sign,
                }).then((txn) => {
                  aptos
                    .waitForTransaction({
                      transactionHash: txn.hash,
                    })
                    .then(() => {
                      setIsSuccess(true)
                    })
                    .catch(() => {
                      setIsError(true)
                    })
                    .finally(() => {})
                })
              }}
            >
              Stake
            </Button>
          </div>
        </div>
      </div>
    </>
  )
}
