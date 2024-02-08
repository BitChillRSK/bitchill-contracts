const { ethers } = require('ethers');
const cron = require('node-cron');
require('dotenv').config()

const rpcUrl = process.env.RPC_URL || 'https://public-node.testnet.rsk.co'

// Configuración del proveedor y del contrato
const provider = new ethers.JsonRpcProvider(rpcUrl);
const contractAddress = '0x17010f287973bcB2dc84ad385e17b2A7D54C41Af';
const abi = [
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "docTokenAddress",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "mocProxyAddress",
				"type": "address"
			}
		],
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"inputs": [],
		"name": "CannotBuyIfPurchasePeriodHasNotElapsed",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "DepositAmountMustBeGreaterThanZero",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "DocDepositFailed",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "DocWithdrawalAmountExceedsBalance",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "DocWithdrawalAmountMustBeGreaterThanZero",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "DocWithdrawalFailed",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "OnlyMocProxyContractCanSendRbtcToDcaContract",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "owner",
				"type": "address"
			}
		],
		"name": "OwnableInvalidOwner",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "OwnableUnauthorizedAccount",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "PurchaseAmountMustBeGreaterThanZero",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "PurchaseAmountMustBeLowerThanHalfOfBalance",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "PurchasePeriodMustBeGreaterThanZero",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "RedeemDocRequestFailed",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "RedeemFreeDocFailed",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "rBtcWithdrawalFailed",
		"type": "error"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "DocDeposited",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "DocWithdrawn",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "previousOwner",
				"type": "address"
			},
			{
				"indexed": true,
				"internalType": "address",
				"name": "newOwner",
				"type": "address"
			}
		],
		"name": "OwnershipTransferred",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "purchaseAmount",
				"type": "uint256"
			}
		],
		"name": "PurchaseAmountSet",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "purchasePeriod",
				"type": "uint256"
			}
		],
		"name": "PurchasePeriodSet",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "docAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "rbtcAmount",
				"type": "uint256"
			}
		],
		"name": "RbtcBought",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "rbtcAmount",
				"type": "uint256"
			}
		],
		"name": "rBtcWithdrawn",
		"type": "event"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "buyer",
				"type": "address"
			}
		],
		"name": "buy",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "depositAmount",
				"type": "uint256"
			}
		],
		"name": "depositDOC",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getDocBalance",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getPurchaseAmount",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getRbtcBalance",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "owner",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "renounceOwnership",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "purchaseAmount",
				"type": "uint256"
			}
		],
		"name": "setPurchaseAmount",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "purchasePeriod",
				"type": "uint256"
			}
		],
		"name": "setPurchasePeriod",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "newOwner",
				"type": "address"
			}
		],
		"name": "transferOwnership",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "withdrawAccumulatedRbtc",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "withdrawalAmount",
				"type": "uint256"
			}
		],
		"name": "withdrawDOC",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"stateMutability": "payable",
		"type": "receive"
	}
];

const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);
const contract = new ethers.Contract(contractAddress, abi, wallet);

// Lista de direcciones de usuarios
const userAddresses = ['0x226E865Ab298e542c5e5098694eFaFfe111F93D3']

async function checkAndExecuteBuys() {
    for (const userAddress of userAddresses) {
        try {
            console.log(`Intentando ejecutar compra para la dirección: ${userAddress}`);
            const tx = await contract.buy(userAddress);
            await tx.wait();
            console.log(`Compra ejecutada para la dirección: ${userAddress}, tx: ${tx.hash}`);
        } catch (error) {
            // Maneja el error específico de "periodo de compra no ha transcurrido"
            if (error.message.includes('CannotBuyIfPurchasePeriodHasNotElapsed')) {
                console.log(`Todavía no es el momento de comprar para la dirección: ${userAddress}`);
            } else {
                console.error(`Error al ejecutar la compra para la dirección: ${userAddress}:`, error);
            }
        }
    }
}

// Programar la ejecución del bot

cron.schedule('*/15 * * * * *', () => { // Se ejecuta cada 15 segundos
    console.log("Verificando si es momento de ejecutar compras...");
    checkAndExecuteBuys();
});

console.log("Bot iniciado...");