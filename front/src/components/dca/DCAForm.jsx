import {
	Button,
	Card,
	CircularProgress,
	Divider,
	FormControl,
	InputAdornment,
	OutlinedInput,
	Stack,
	Typography,
} from '@mui/material';
import DCAToggleGroup from './DCAToggleGroup';
import { useContext, useState } from 'react';
import Web3 from 'web3';
import { Web3Context } from '../../context/Web3Context';
import useGetAccount from './../../hooks/web3/useGetAccount';
import { ABI_APPROVE, ABI_DCA } from './ABI_APPROVE';
import { ethers } from 'ethers';

import { listaCantidad, listaDuracion, listaFrequencia } from './utils-dca';
import { Link } from 'react-router-dom';
const DCA_ADDRESS = '0xa62e8b6c4cdfae3d9c580a7d53e079f37daccff9';
const WALLET_APPROVE = '0xcb46c0ddc60d18efeb0e586c17af6ea36452dae0';
const DCAFrom = () => {
	const { account } = useGetAccount();
	const [cantidad, setCantidad] = useState(0);
	const [frequencia, setFrequencia] = useState(0);
	const [duracion, setDuracion] = useState(0);

	const { provider } = useContext(Web3Context);

	const [isLoading, setIsLoading] = useState(false);
	const [txPosition, setTxPosition] = useState(null);

	const deposit = async () => {
		setIsLoading(true);
		setTxPosition(null);

		/**
		 * use ethers to sign...
		 */
		// await window.ethereum.request({ method: 'eth_requestAccounts' });
		const provider3 = new ethers.providers.Web3Provider(provider);
		// debugger;
		const signer = provider3.getSigner();

		// Direcciones del contrato del token y del contrato al que se le dará la aprobación
		const tokenContract = new ethers.Contract(
			WALLET_APPROVE,
			ABI_APPROVE,
			signer
		);
		const dcaContract = new ethers.Contract(DCA_ADDRESS, ABI_DCA, signer);
		const cantidadTotal = cantidad * frequencia * duracion;

		const amount = ethers.utils.parseUnits(cantidadTotal.toString(), 18); // Asegúrate de usar la cantidad correcta de decimales
		try {
			// Llamar a la función approve del contrato
			const tx = await tokenContract.approve(DCA_ADDRESS, amount);
			const approveTx = await tx.wait();

			console.log(
				`Approved ${ethers.utils.formatUnits(
					amount,
					18
				)} tokens for the spender contract`
			);
			const txCreatePosition = await dcaContract.createPosition(
				WALLET_APPROVE,
				amount,
				cantidad,
				frequencia
			);
			await txCreatePosition.wait();
			console.log(txCreatePosition);
			setTxPosition(txCreatePosition);

			/**
			 * Con web3 no funcionaba la lectur
			 */
			// paso 1 - APPROVE

			/* const web3 = new Web3(provider);
			debugger;
			const approve = new web3.eth.Contract(ABI_APPROVE, WALLET_APPROVE);
			const cantidadTotal = cantidad * frequencia * duracion;
			const amount = web3.utils.toWei(cantidadTotal, 'ether');
			/*const tx = await approve.methods.approve(DCA_ADDRESS, amount).send({
				from: account,
				gas: '65164',
				gasPrice: '65164',
			}); */
			/* const gasPrice = await approve.methods
				.approve(DCA_ADDRESS, amount)
				.estimateGas();
			const tx = await approve.methods.approve(DCA_ADDRESS, amount).send({
				from: account,
				gasPrice,
			});
			console.log(tx); */
		} catch (error) {
			console.error('Error sending transaction:', error);
		} finally {
			setIsLoading(false);
		}
	};
	return (
		<div
			style={{
				display: 'flex',
				flexDirection: 'column',
				alignItems: 'center',
				width: '100%',
			}}
		>
			<Typography variant='h5' sx={{ margin: '14px' }}>
				Configura tu ahorro periódico
			</Typography>
			<Card
				sx={{
					padding: '50px',
					width: '610px',
					borderRadius: '50px',
					flexShrink: 0,
					backgroundColor: '#F7F7F7',
				}}
			>
				<Typography variant='h6'>Cantidad periódica (DOC)</Typography>

				<Stack direction={'column'} spacing={3}>
					<FormControl fullWidth sx={{ m: 1 }}>
						<OutlinedInput
							id='outlined-adornment-amount'
							startAdornment={
								<InputAdornment position='start'>$</InputAdornment>
							}
							onChange={e => setCantidad(e.target.value)}
							value={cantidad || ''}
						/>
					</FormControl>
					<DCAToggleGroup
						listOfTogles={listaCantidad}
						handlerSelect={setCantidad}
						initValue={0}
					/>
					<div>
						<Typography variant='h6'>Frecuencia</Typography>
						<DCAToggleGroup
							listOfTogles={listaFrequencia}
							handlerSelect={setFrequencia}
							initValue={0}
						/>
					</div>
					<div>
						<Typography variant='h6'>Duración</Typography>
						<DCAToggleGroup
							listOfTogles={listaDuracion}
							handlerSelect={setDuracion}
							initValue={0}
						/>
					</div>
					<Divider />
					<div>
						<Typography variant='h5'>
							DOC a despositar: {cantidad * frequencia * duracion} $
						</Typography>
					</div>
					<div>
						{!isLoading && txPosition && (
							<Link
								to={`https://explorer.testnet.rsk.co/tx/${txPosition.hash}`}
								target={'_blank'}
								rel={'noopener noreferrer'}
							>
								Revisa la transacción
							</Link>
						)}
					</div>
				</Stack>
			</Card>
			<div style={{ marginTop: '34px' }}>
				{isLoading ? (
					<CircularProgress />
				) : (
					<Button
						variant='contained'
						sx={{ width: '281px', height: '61px' }}
						onClick={deposit}
					>
						Depositar
					</Button>
				)}
			</div>
		</div>
	);
};

export default DCAFrom;
