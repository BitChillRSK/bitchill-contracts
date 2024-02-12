import {
	Paper,
	Table,
	TableBody,
	TableCell,
	TableContainer,
	TableHead,
	TableRow,
} from '@mui/material';
import { Web3Context } from '../../context/Web3Context';
import { useContext, useEffect } from 'react';
import { ethers } from 'ethers';
import Web3 from 'web3';

import { ABI_DCA, ABI_APPROVE } from './../dca/ABI_APPROVE';

const rows = [
	{
		fecha: '01/10/2023',
		rbtc: '0.012527',
		estado: 'Comprado',
	},
	{
		fecha: '01/11/2023',
		rbtc: '0.012602',
		estado: 'Comprado',
	},
	{
		fecha: '01/12/2023',
		rbtc: '0.012419',
		estado: 'Comprado',
	},
	{
		fecha: '01/01/2024',
		rbtc: '0.012501',
		estado: 'Comprado',
	},
	{
		fecha: '01/02/2024',
		rbtc: '0.012521',
		estado: 'Pendiente',
	},
];

const DCA_ADDRESS = '0x322D577d1db3Be7151BC547409780676a59a0E75';
const DOC_ADDRESS = '0xCb46C0DdC60d18eFEB0e586c17AF6Ea36452DaE0';

const EVENT_NAME_BUY = 'PurchasePeriodSet';

export default function TableActividad() {
	const { provider } = useContext(Web3Context);

	useEffect(() => {
		const getEventsDCAEthers = async () => {
			const provider3 = new ethers.providers.Web3Provider(provider);
			const dcaContract = new ethers.Contract(DCA_ADDRESS, ABI_DCA, provider3);
			const rbtcBoughtListener = (user, docAmount, rbtcAmount, event) => {
				const data = {
					user,
					docAmount: docAmount.toString(),
					rbtcAmount: rbtcAmount.toString(),
				};
				console.log(`event ${EVENT_NAME_BUY}`, data);
			};

			dcaContract.on('EVENT_NAME_BUY', rbtcBoughtListener);

			return () => {
				dcaContract.off(EVENT_NAME_BUY, rbtcBoughtListener);
			};
		};

		/**
		 * web3
		 */
		// getEventsDCAEthers();
		const getPastEventsDCAWeb3 = async () => {
			const web3 = new Web3(provider);
			const dcaContract = new web3.eth.Contract(ABI_DCA, DCA_ADDRESS);
			web3.eth.getBlockNumber().then(n => {
				dcaContract
					.getPastEvents(EVENT_NAME_BUY, {
						fromBlock: 0,
						toBlock: n,
					})
					.then(event => console.log(`Eventos ${EVENT_NAME_BUY}`, event));
			});
		};
		// getPastEventsDCAWeb3();

		const getEventsDoC = async () => {
			try {
				const web3 = new Web3(provider);
				const dcaContract = new web3.eth.Contract(ABI_APPROVE, DOC_ADDRESS);
				web3.eth.getBlockNumber().then(n => {
					dcaContract
						.getPastEvents('Transfer', {
							fromBlock: 0,
							toBlock: n,
						})
						.then(event => console.log(`Eventos Transfer`, event))
						.catch(() => console.log('yep'));
				});
			} catch (err) {
				console.log('hay errores');
			}
		};

		getEventsDoC();
	}, []);

	return (
		<TableContainer component={Paper}>
			<Table aria-label='simple table'>
				<TableHead>
					<TableRow>
						<TableCell>Fecha</TableCell>
						<TableCell>Cantidad (rBTC)</TableCell>
						<TableCell>Estado</TableCell>
					</TableRow>
				</TableHead>
				<TableBody>
					{rows.map((row, index) => (
						<TableRow
							key={index}
							sx={{ '&:last-child td, &:last-child th': { border: 0 } }}
						>
							<TableCell component='th' scope='row'>
								{row.fecha}
							</TableCell>
							<TableCell>{row.rbtc}</TableCell>
							<TableCell>{row.estado}</TableCell>
						</TableRow>
					))}
				</TableBody>
			</Table>
		</TableContainer>
	);
}
