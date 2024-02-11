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

import { ABI_DCA } from './../dca/ABI_APPROVE';

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

export default function TableActividad() {
	const { provider, web3auth } = useContext(Web3Context);

	useEffect(() => {
		const getEventsDCA = async () => {
			console.log('provider', provider);
			console.log('web3auth', web3auth);
			const provider3 = new ethers.providers.Web3Provider(provider);
			const signer = provider3.getSigner();
			const dcaContract = new ethers.Contract(DCA_ADDRESS, ABI_DCA, signer);

			dcaContract.on('RbtcBought', (user, docAmount, rbtcAmount, event) => {
				const data = {
					user,
					docAmount: docAmount.toString(),
					rbtcAmount: rbtcAmount.toString(),
				};
				console.log('event RbtcBought', data);
			});
		};

		getEventsDCA();
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
