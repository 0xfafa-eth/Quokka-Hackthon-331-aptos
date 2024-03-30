import { UserOutlined, AntDesignOutlined } from "@ant-design/icons";
import { CollapseProps, Collapse, Button, Avatar, Tooltip } from "antd";
import { aptos, chef_contract } from "../config";

const text = `
  A dog is a type of domesticated animal.
  Known for its loyalty and faithfulness,
  it can be found as a welcome guest in many households across the world.
`;

const items: CollapseProps['items'] = [
  {
    key: '1',
    label: 
    <>
        <LogoName token_one_url="https://cdn.moralis.io/eth/0x2260fac5e5542a773aa44fbcfedf7c193bc2c599.png" token_two_url="https://cdn.moralis.io/eth/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.png"/>,
        <></>
    </>,
    children: <>
        <button onClick={()=>{
            aptos.view({
                payload: {
                    function: `${chef_contract}::smart_chef::get_pool_info`,
                    typeArguments: [],
                    functionArguments: [
                       "0"
                    ],
                  },
            })
        }}>View</button>
    </>,
  },
  {
    key: '2',
    label: 'This is panel header 2',
    children: <p>{text}</p>,
  },
  {
    key: '3',
    label: 'This is panel header 3',
    children: <p>{text}</p>,
  },
];
export function LogoName(
    {token_one_url,
    token_two_url}: {token_one_url:string,
        token_two_url:string}
){
    return <>
    <Avatar.Group>
        <Avatar src={token_two_url} />
        <Avatar src={token_one_url} />
    </Avatar.Group>
    </>
}

export function Farm() {
    return <>
        <Collapse size="large" style={{minWidth: "800px"}} items={items} defaultActiveKey={['1']} />
    </>
}