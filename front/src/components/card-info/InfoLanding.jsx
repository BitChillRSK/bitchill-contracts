import { Stack } from '@mui/material';
import CardInfo from './CardInfo';
import dca from './../../assets/DCA.svg';
import rendimiendo from './../../assets/rendimientos.svg';
import prestamos from './../../assets/Prestamos.svg';

const infoLanding = [
	{
		title: '¿Qué es DCA?',
		description: `DCA (Dollar Cost Average) es una herramienta que un inversionista
    puede utilizar para generar ahorros durante un largo período mientras
    neutraliza la volatilidad a corto plazo en el mercado.Las compras se
    producen independientemente del precio del activo y a intervalos
    regulares.`,
		logo: dca,
	},
	{
		title: 'Rendimientos en Dollar on Chain (DOC)',
		description:
			'Dollar con Chain (DOC) es una stablecoin respaldada por Bitcoin. En Nombre se deposita en Tropykus la cantidad total de DOC definida por el usuario para las compras de DCA para que de rendimientos al 6% anual mientras se hacen las compras con la frecuencia definida.',
		logo: rendimiendo,
	},
	{
		title: 'Préstamos para la vida real',
		description:
			'Al hacer la estrategia de DCA el usuario acumula Bitcoin cada semana o mes, y esto le abre la oportunidad de pedir préstamos usando su Bitcoin como garantía. El usuario podrá pedir préstamos hasta un 30% del Bitcoin que tenga acumulado.',
		logo: prestamos,
	},
];
export default function InfoLanding() {
	return (
		<Stack spacing={3}>
			{infoLanding.map(({ title, description, logo }, index) => (
				<CardInfo
					key={index}
					title={title}
					description={description}
					logo={logo}
				/>
			))}
		</Stack>
	);
}
