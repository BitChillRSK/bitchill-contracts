import {
	Paper,
	Table,
	TableBody,
	TableCell,
	TableContainer,
	TableHead,
	TableRow,
} from '@mui/material';

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
export default function TableActividad() {
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
