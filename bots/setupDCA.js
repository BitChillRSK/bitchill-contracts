const { ethers } = require('ethers');
require('dotenv').config()

const rpcUrl = process.env.RPC_URL

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

const privateKey = process.env.USER_PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);
const contract = new ethers.Contract(contractAddress, abi, wallet);

const docTokenAddress = '0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0'
const docTokenABI = [
	{
	  "constant": true,
	  "inputs": [],
	  "name": "name",
	  "outputs": [
		{
		  "name": "",
		  "type": "string"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "spender",
		  "type": "address"
		},
		{
		  "name": "value",
		  "type": "uint256"
		}
	  ],
	  "name": "approve",
	  "outputs": [
		{
		  "name": "",
		  "type": "bool"
		}
	  ],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": true,
	  "inputs": [],
	  "name": "totalSupply",
	  "outputs": [
		{
		  "name": "",
		  "type": "uint256"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "sender",
		  "type": "address"
		},
		{
		  "name": "recipient",
		  "type": "address"
		},
		{
		  "name": "amount",
		  "type": "uint256"
		}
	  ],
	  "name": "transferFrom",
	  "outputs": [
		{
		  "name": "",
		  "type": "bool"
		}
	  ],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": true,
	  "inputs": [],
	  "name": "decimals",
	  "outputs": [
		{
		  "name": "",
		  "type": "uint8"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "spender",
		  "type": "address"
		},
		{
		  "name": "addedValue",
		  "type": "uint256"
		}
	  ],
	  "name": "increaseAllowance",
	  "outputs": [
		{
		  "name": "",
		  "type": "bool"
		}
	  ],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "account",
		  "type": "address"
		},
		{
		  "name": "amount",
		  "type": "uint256"
		}
	  ],
	  "name": "mint",
	  "outputs": [
		{
		  "name": "",
		  "type": "bool"
		}
	  ],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": true,
	  "inputs": [
		{
		  "name": "account",
		  "type": "address"
		}
	  ],
	  "name": "balanceOf",
	  "outputs": [
		{
		  "name": "",
		  "type": "uint256"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [],
	  "name": "renounceOwnership",
	  "outputs": [],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": true,
	  "inputs": [],
	  "name": "owner",
	  "outputs": [
		{
		  "name": "",
		  "type": "address"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": true,
	  "inputs": [],
	  "name": "isOwner",
	  "outputs": [
		{
		  "name": "",
		  "type": "bool"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": true,
	  "inputs": [],
	  "name": "symbol",
	  "outputs": [
		{
		  "name": "",
		  "type": "string"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "account",
		  "type": "address"
		}
	  ],
	  "name": "addMinter",
	  "outputs": [],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [],
	  "name": "renounceMinter",
	  "outputs": [],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "who",
		  "type": "address"
		},
		{
		  "name": "value",
		  "type": "uint256"
		}
	  ],
	  "name": "burn",
	  "outputs": [],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "spender",
		  "type": "address"
		},
		{
		  "name": "subtractedValue",
		  "type": "uint256"
		}
	  ],
	  "name": "decreaseAllowance",
	  "outputs": [
		{
		  "name": "",
		  "type": "bool"
		}
	  ],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "recipient",
		  "type": "address"
		},
		{
		  "name": "amount",
		  "type": "uint256"
		}
	  ],
	  "name": "transfer",
	  "outputs": [
		{
		  "name": "",
		  "type": "bool"
		}
	  ],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "constant": true,
	  "inputs": [
		{
		  "name": "account",
		  "type": "address"
		}
	  ],
	  "name": "isMinter",
	  "outputs": [
		{
		  "name": "",
		  "type": "bool"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": true,
	  "inputs": [
		{
		  "name": "owner",
		  "type": "address"
		},
		{
		  "name": "spender",
		  "type": "address"
		}
	  ],
	  "name": "allowance",
	  "outputs": [
		{
		  "name": "",
		  "type": "uint256"
		}
	  ],
	  "payable": false,
	  "stateMutability": "view",
	  "type": "function"
	},
	{
	  "constant": false,
	  "inputs": [
		{
		  "name": "newOwner",
		  "type": "address"
		}
	  ],
	  "name": "transferOwnership",
	  "outputs": [],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "function"
	},
	{
	  "inputs": [],
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "constructor"
	},
	{
	  "payable": false,
	  "stateMutability": "nonpayable",
	  "type": "fallback"
	},
	{
	  "anonymous": false,
	  "inputs": [
		{
		  "indexed": true,
		  "name": "account",
		  "type": "address"
		}
	  ],
	  "name": "MinterAdded",
	  "type": "event"
	},
	{
	  "anonymous": false,
	  "inputs": [
		{
		  "indexed": true,
		  "name": "account",
		  "type": "address"
		}
	  ],
	  "name": "MinterRemoved",
	  "type": "event"
	},
	{
	  "anonymous": false,
	  "inputs": [
		{
		  "indexed": true,
		  "name": "from",
		  "type": "address"
		},
		{
		  "indexed": true,
		  "name": "to",
		  "type": "address"
		},
		{
		  "indexed": false,
		  "name": "value",
		  "type": "uint256"
		}
	  ],
	  "name": "Transfer",
	  "type": "event"
	},
	{
	  "anonymous": false,
	  "inputs": [
		{
		  "indexed": true,
		  "name": "owner",
		  "type": "address"
		},
		{
		  "indexed": true,
		  "name": "spender",
		  "type": "address"
		},
		{
		  "indexed": false,
		  "name": "value",
		  "type": "uint256"
		}
	  ],
	  "name": "Approval",
	  "type": "event"
	},
	{
	  "anonymous": false,
	  "inputs": [
		{
		  "indexed": true,
		  "name": "previousOwner",
		  "type": "address"
		},
		{
		  "indexed": true,
		  "name": "newOwner",
		  "type": "address"
		}
	  ],
	  "name": "OwnershipTransferred",
	  "type": "event"
	}
]
const docTokenContract = new ethers.Contract(docTokenAddress, docTokenABI, wallet);

async function approveDCAContract(amount) {
	const amountToApprove = ethers.parseUnits(amount, 18); // Asumiendo 18 decimales
    const approveTx = await docTokenContract.approve(contractAddress, amountToApprove);
    await approveTx.wait();
    console.log(`Se han aprobado tokens para el contrato DCA.`);
}

async function setupDCA(depositA, purchaseP, purchaseA) {
    // No necesitas convertir el depositAmount a BigNumber aquí, pásalo como string
    const depositAmount = depositA; // Pasa la cantidad como string directamente
    const purchasePeriod = purchaseP; // 60 segundos
    const purchaseAmount = purchaseA; // Pasa la cantidad como string directamente

    try {
        console.log("Aprobando el DOC para el contrato...");
        await approveDCAContract(depositAmount); // depositAmount es un string aquí
        
        console.log("Iniciando el depósito de DOC...");
        let tx = await contract.depositDOC(ethers.parseUnits(depositAmount, 18)); // Convierte aquí
        await tx.wait();
        console.log("Depósito completado.");

        console.log("Configurando el período de compra...");
        tx = await contract.setPurchasePeriod(purchasePeriod);
        await tx.wait();
        console.log("Período de compra configurado.");

        console.log("Configurando la cantidad de compra...");
        tx = await contract.setPurchaseAmount(ethers.parseUnits(purchaseAmount, 18)); // Convierte aquí
        await tx.wait();
        console.log("Cantidad de compra configurada.");
    } catch (error) {
        console.error("Se ha producido un error:", error);
    }
}

setupDCA('500', 60, '20');
