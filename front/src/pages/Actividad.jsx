import { Card, Stack, Typography } from '@mui/material';
import TableActividad from '../components/actividad/TableActividad';

export default function Actividad() {
	return (
		<div
			style={{
				display: 'flex',
				flexDirection: 'column',
				alignItems: 'center',
				width: '100%',
			}}
		>
			<Card
				sx={{
					padding: '50px',
					width: '610px',
					borderRadius: '50px',
					flexShrink: 0,
					backgroundColor: '#F7F7F7',
				}}
			>
				<Stack direction={'column'} spacing={4}>
					<div>
						<Typography variant='h5'>Estrategia DCA 1</Typography>
						<Typography variant='h6' color={'primary'}>
							12.000 USD - 24 compras - 2años
						</Typography>
					</div>
					<div>
						<Typography variant='h6'>
							Comprado: 0.050 rBTC (2100 USD)
						</Typography>
						<Typography variant='h6'>Gastado: 2000 USD</Typography>
					</div>
					<TableActividad />
				</Stack>
			</Card>
		</div>
	);
}
