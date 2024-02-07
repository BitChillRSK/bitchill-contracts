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
import { Web3Context } from '../../context/Web3Context';
import { ABI_APPROVE, ABI_DCA } from './ABI_APPROVE';
import { ethers } from 'ethers';

import {
	listaCantidad,
	listaDuracion,
	listaFrequencia,
	frecuenciaASegundos,
} from './utils-dca';
import { Link } from 'react-router-dom';
const DCA_ADDRESS = '0x322D577d1db3Be7151BC547409780676a59a0E75';

const WALLET_APPROVE = '0xcb46c0ddc60d18efeb0e586c17af6ea36452dae0';

const DCAFrom = () => {
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
		const provider3 = new ethers.providers.Web3Provider(provider);
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
			/**
			 * 0 Llamar a la función approve del contrato
			 */
			const tx = await tokenContract.approve(DCA_ADDRESS, amount);
			const approveTx = await tx.wait();
			console.log('approveTx', approveTx);

			/**
			 * 1 depositDOC
			 */
			const depositDOC = await dcaContract.depositDOC(amount);
			await depositDOC.wait();
			console.log('depositDOC', depositDOC);
			setTxPosition(depositDOC);
			/**
			 * 2 setPurchaseAmount
			 */
			const purchaseAmount = ethers.utils.parseUnits(cantidad.toString(), 18);
			const setPurchaseAmount = await dcaContract.setPurchaseAmount(
				purchaseAmount
			);
			await setPurchaseAmount.wait();
			console.log('setPurchaseAmount', setPurchaseAmount);

			/**
			 * 3 setPurchasePeriode
			 */
			const segundosFrecuencia = frecuenciaASegundos(frequencia);
			const setPurchasePeriod = await dcaContract.setPurchasePeriod(
				segundosFrecuencia
			);
			await setPurchasePeriod.wait();
			console.log('setPurchasePeriod', setPurchasePeriod);
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
