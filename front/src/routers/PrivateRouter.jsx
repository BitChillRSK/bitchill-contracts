import { useContext } from 'react';
import { Web3Context } from '../context/Web3Context';
import { Navigate } from 'react-router-dom';
import Layout from '../pages/Layout';

export default function PrivateRouter() {
	const { provider } = useContext(Web3Context);

	return <>{provider === null ? <Navigate to='/landing' /> : <Layout />}</>;
}
