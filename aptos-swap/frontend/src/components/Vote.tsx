import { Button, Avatar, message, Popover } from 'antd'
import { aptos, vote_contract } from '../config'
import { useEffect, useState } from 'react'
import { useWallet } from '@aptos-labs/wallet-adapter-react'
import { formatUnits } from 'viem'

export function LogoName({
  token_one_url,
  token_two_url,
}: {
  token_one_url: string
  token_two_url: string
}) {
  return (
    <>
      <Avatar.Group>
        <Avatar src={token_two_url} />
        <Avatar src={token_one_url} />
      </Avatar.Group>
    </>
  )
}

export function Vote() {
  const [messageApi, contextHolder] = message.useMessage()
  const { submitTransaction, signTransaction, account } = useWallet()
  const [isLoading, setIsLoading] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)
  const [isError, setIsError] = useState(false)
  const [map, setMap] = useState([
    {
      name: 'Qka - VeQka',
      token_one_url:
        'https://cdn.moralis.io/eth/0x2260fac5e5542a773aa44fbcfedf7c193bc2c599.png',
      token_two_url:
        'https://cdn.moralis.io/eth/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.png',
      id: 0,
      user: '-',
      user_reward: '-',
      pool_info_total_staked: '-',
      pool_info_reward_per_second: '-',
    },
    {
      name: 'VeQka - Qka',
      token_one_url:
        'https://cdn.moralis.io/eth/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.png',
      token_two_url:
        'https://cdn.moralis.io/eth/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.png',
      id: 1,
      user: '-',
      user_reward: '-',
      pool_info_total_staked: '-',
      pool_info_reward_per_second: '-',
    },
  ])

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

  useEffect(() => {
    if (account?.address)
      map.forEach((item, i: string | number) => {
        aptos
          .view<string[]>({
            payload: {
              function: `${vote_contract}::smart_chef::get_user_stake_amount`,
              typeArguments: [],
              functionArguments: [account?.address, item.id.toString()],
            },
          })
          .then((data) => {
            setMap((old_value: any) => {
              let new_value = old_value
              new_value[i].user = data[0]
              return [...new_value]
            })
          })

        aptos
          .view<string[]>({
            payload: {
              function: `${vote_contract}::smart_chef::get_pending_reward`,
              typeArguments: [],
              functionArguments: [account?.address, item.id.toString()],
            },
          })
          .then((data) => {
            setMap((old_value: any) => {
              let new_value = old_value
              new_value[i].user_reward = data[0]
              return [...new_value]
            })
          })

        aptos
          .view<string[]>({
            payload: {
              function: `${vote_contract}::smart_chef::get_pool_info`,
              typeArguments: [],
              functionArguments: [item.id.toString()],
            },
          })
          .then((data) => {
            setMap((old_value: any) => {
              let new_value = old_value
              new_value[i].pool_info_total_staked = data[0]
              new_value[i].pool_info_reward_per_second = data[2].toString()
              return [...new_value]
            })
          })
      })
  }, [account])

  return (
    <>
      {contextHolder}
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          minWidth: '500px',
          height: '100%',
          gap: '2rem',
        }}
      >
        {map.map((data) => (
          <>
            <div style={{}}>
              <div
                style={{
                  display: 'flex',
                  gap: '5rem',

                  backgroundColor: '#FFFFFF',
                  borderRadius: '5px',
                  padding: '10px',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <Popover
                  content={
                    <>
                      <div style={{ padding: '2rem' }}>
                        <div
                          style={{
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'center',
                            alignItems: 'center',
                            gap: '1rem',
                          }}
                        >
                          <span>
                            总质押:{' '}
                            {data.pool_info_total_staked != '-'
                              ? formatUnits(
                                  BigInt(data.pool_info_total_staked),
                                  8,
                                ).toString()
                              : '-'}{' '}
                          </span>
                          <span>
                            秒释放量:{' '}
                            {data.pool_info_reward_per_second != '-'
                              ? formatUnits(
                                  BigInt(data.pool_info_reward_per_second),
                                  8,
                                ).toString()
                              : '-'}{' '}
                          </span>
                        </div>
                      </div>
                    </>
                  }
                  title="详情"
                  trigger="hover"
                >
                  <div>
                    <Avatar.Group>
                      <Avatar size={'large'} src={data.token_two_url} />
                      <Avatar size={'large'} src={data.token_one_url} />
                    </Avatar.Group>
                  </div>
                </Popover>
                <div style={{ color: 'black' }}>
                  我的投票数:{' '}
                  {data.user != '-'
                    ? formatUnits(BigInt(data.user), 8).toString()
                    : '-'}
                </div>

                <div style={{ color: 'black' }}>
                  PendingReward:{' '}
                  {data.user_reward != '-'
                    ? formatUnits(BigInt(data.user_reward), 8).toString()
                    : '-'}
                </div>
                <div style={{ display: 'flex', gap: '1rem' }}>
                  <Button
                    onClick={async () => {
                      //send
                      setIsLoading(true)

                      let txn_wait_sign = await aptos.transaction.build.simple({
                        sender: account?.address || '',
                        data: {
                          function: `${vote_contract}::smart_chef::deposit`,
                          typeArguments: [],
                          functionArguments: [data.id.toString(), '100000000'],
                        },
                      })

                      let txn_with_sign = await signTransaction(txn_wait_sign)

                      submitTransaction({
                        transaction: txn_wait_sign,
                        senderAuthenticator: txn_with_sign,
                      }).then((txn: { hash: any }) => {
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
                    Vote
                  </Button>

                  {data.user != '-' ? (
                    <Button
                      onClick={async () => {
                        //send
                        setIsLoading(true)

                        let txn_wait_sign =
                          await aptos.transaction.build.simple({
                            sender: account?.address || '',
                            data: {
                              function: `${vote_contract}::smart_chef::withdraw`,
                              typeArguments: [],
                              functionArguments: [
                                data.id.toString(),
                                data.user,
                              ],
                            },
                          })

                        let txn_with_sign = await signTransaction(txn_wait_sign)

                        submitTransaction({
                          transaction: txn_wait_sign,
                          senderAuthenticator: txn_with_sign,
                        }).then((txn: { hash: any }) => {
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
                      Unvote
                    </Button>
                  ) : (
                    <></>
                  )}
                </div>
              </div>
            </div>
          </>
        ))}
      </div>
    </>
  )
}
