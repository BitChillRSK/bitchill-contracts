import { useState, useEffect } from 'react';

import Web3 from 'web3';
import GREETINGS from './../../../../hardhat/artifacts/contracts/HelloWorld.sol/HelloWorld.json';
const NODE_ENDPOINT = import.meta.env.VITE_API_NODE_ENDPOINT;
const ADDRESS_SC_HELLO_WORLD = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

const ABI = GREETINGS.abi;

const { ethereum } = window;

const web3 = new Web3(NODE_ENDPOINT);
const helloWorld = new web3.eth.Contract(ABI, ADDRESS_SC_HELLO_WORLD);

export default function HelloWorld() {
	const [message, setMessage] = useState(null);
	const [txHash, setTxHash] = useState(null);
	const [isSending, setIsSending] = useState(false);
	const [account, setAccount] = useState(null);

	useEffect(() => {
		ethereum.request({ method: 'eth_requestAccounts' }).then(listOfAccount => {
			setAccount(listOfAccount[0]);
		});
	});

	useEffect(() => {
		const updateAccount = listOfAccount => {
			setAccount(listOfAccount[0]);
		};
		if (ethereum) {
			ethereum.on('accountsChanged', updateAccount);
		}

		return () => {
			if (ethereum) {
				ethereum.off('accountsChanged', updateAccount);
			}
		};
	}, []);

	const getMessage = () => {
		try {
			helloWorld.methods
				.getMessage()
				.call()
				.then(msg => {
					console.log('El msg es: ', msg);
					setMessage(msg);
				});
		} catch (err) {
			console.log('getMessage - err', err);
		}
	};

	const addMessage = event => {
		event.preventDefault();
		const formData = new FormData(event.target);
		const msgForm = formData.get('message');

		setIsSending(true);
		setTxHash(null);

		try {
			const helloWorld = new web3.eth.Contract(ABI, ADDRESS_SC_HELLO_WORLD);
			helloWorld.methods
				.setMessage(msgForm)
				.send({
					from: account,
					gas: '30000',
					gasPrice: '6000000000',
				})
				.on('transactionHash', transactionHash => setTxHash(transactionHash))
				.on('receipt', _ => setIsSending(false))
				.catch(console.log);
		} catch (error) {
			console.log('error', error);
		}
	};
	return (
		<>
			<h1 className='text-5xl font-bold'>Hello World</h1>
			<div>
				<form onSubmit={getMessage}>
					<label>message: {message}</label>
					<button type='submit' className='btn btn-primary'>
						Get Message
					</button>
				</form>
			</div>
			<div>
				<form onSubmit={addMessage}>
					<label className='label'>Add Message</label>
					<input
						type='text'
						placeholder='New Message'
						name='message'
						required
					/>
					<button type='submit'>Add</button>
				</form>
			</div>
			<div>
				<label>Transaction hash: {txHash}</label>
			</div>
		</>
	);
}
