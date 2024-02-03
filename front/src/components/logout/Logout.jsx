import { Button, Typography } from '@mui/material';
import { useContext } from 'react';
import { Web3Context } from '../../context/Web3Context';
import { useNavigate } from 'react-router-dom';

export default function Logout() {
	const { setProvider, web3auth, setWeb3auth } = useContext(Web3Context);
	const navigateTo = useNavigate();
	const logout = async () => {
		if (!web3auth) {
			console.error('Error al desconectar');
		}
		try {
			await web3auth.logout();
			setProvider(null);
			setWeb3auth(null);
		} catch (err) {
			console.error(err);
		}

		navigateTo('/landing');
	};
	return (
		<Button onClick={logout} sx={{ color: 'black' }}>
			<Typography>Desconectar</Typography>
		</Button>
	);
}
