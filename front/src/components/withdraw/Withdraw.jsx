import { useContext, useState } from 'react';
import { ethers } from 'ethers';

import { Web3Context } from '../../context/Web3Context';
import { ABI_DCA } from '../dca/ABI_APPROVE';
import { TextField, Button } from '@mui/material';
import ExplorerLink from '../explorer/ExplorerLink';

const DCA_ADDRESS = import.meta.env.VITE_DCA_ADDRESS;

export default function Withdraw() {
	const [isLoading, setIsLoading] = useState(false);
	const [txWithdraw, setTxWithdraw] = useState(null);
	const { provider } = useContext(Web3Context);

	const withdrawDeposit = async event => {
		event.preventDefault();
		setIsLoading(true);
		setTxWithdraw(null);
		if (!provider) {
			console.error('web3auth not initialized yet');
			return;
		}

		const form = new FormData(event.target);
		const withdrawDoC = form.get('withdrwaDoC');

		const provider3 = new ethers.providers.Web3Provider(provider);
		const signer = provider3.getSigner();
		const dcaContract = new ethers.Contract(DCA_ADDRESS, ABI_DCA, signer);

		try {
			const withdrawAmount = ethers.utils.parseUnits(
				withdrawDoC.toString(),
				18
			);
			const withdraw = await dcaContract.withdrawDOC(withdrawAmount);
			setTxWithdraw(withdraw);
		} catch (error) {
			console.error('Error al realizar withdraw', error);
		} finally {
			setIsLoading(false);
		}
	};

	return (
		<>
			<form onSubmit={withdrawDeposit}>
				<TextField
					placeholder='DoC'
					type='number'
					name='withdrwaDoC'
					sx={{ marginTop: '5px', marginBottom: '5px' }}
				/>
				<Button
					type='submit'
					variant='contained'
					disabled={isLoading}
					sx={{
						backgroundColor: '#F7F7F7',
						color: 'black',
						borderRadius: '50px',
					}}
				>
					Retirar DoC
				</Button>
			</form>
			{!isLoading && txWithdraw && <ExplorerLink hash={txWithdraw.hash} />}
		</>
	);
}
