const { ethers } = require('ethers');
const cron = require('node-cron');
require('dotenv').config()

const rpcUrl = process.env.RPC_URL

// Configuración del proveedor y del contrato
const provider = new ethers.JsonRpcProvider(rpcUrl);
const contractAddress = '';
const abi = [];
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);
const contract = new ethers.Contract(contractAddress, abi, wallet);

// Lista de direcciones de usuarios
const userAddresses = ['0x...', '0x...']

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