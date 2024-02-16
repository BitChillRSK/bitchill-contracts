import { Card, Stack, Typography } from '@mui/material';
import TableActividad from '../components/actividad/TableActividad';
import useEventsActividad from '../hooks/actividad/useEventsActividad';

export default function Actividad() {
	const { rows, isLoading, comprado, gastado } = useEventsActividad();

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
						<Typography variant='h6'>Comprado: {comprado} rBTC</Typography>
						<Typography variant='h6'>Gastado: {gastado} USD</Typography>
					</div>
					<TableActividad rows={rows} isLoading={isLoading} />
				</Stack>
			</Card>
		</div>
	);
}
