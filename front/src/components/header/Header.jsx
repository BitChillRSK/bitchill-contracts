import { Card, Stack, Typography } from '@mui/material';

import useGetAccount from '../../hooks/web3/useGetAccount';
import useGetBalance from '../../hooks/web3/useGetBalance';
import Logo from '../logo/Logo';
export default function Header() {
	const { account, accountReduce } = useGetAccount();
	const { balance } = useGetBalance(account);
	return (
		<Stack
			direction={'row'}
			justifyContent={'space-between'}
			style={{ marginBottom: '50px', marginTop: '25px' }}
		>
			<Logo />
			<Card
				sx={{
					width: '330px',
					height: '80px',
					borderRadius: '20px',
					backgroundColor: 'rgba(247, 247, 247, 0.20)',
				}}
			>
				<Stack
					direction={'row'}
					alignItems={'center'}
					justifyContent={'space-around'}
					style={{ height: '100%' }}
				>
					<Stack direction={'column'}>
						<Typography variant='body-1'>Saldo DOC</Typography>
						<Typography variant='h6'>{Number(balance).toFixed(2)}</Typography>
					</Stack>
					<Stack direction={'column'}>
						<Typography variant='body-1'>Billetera</Typography>
						<Typography variant='h6'>
							{accountReduce ?? 'Loading...'}
						</Typography>
					</Stack>
				</Stack>
			</Card>
		</Stack>
	);
}
