import { createContext, useState } from 'react';
import PropTypes from 'prop-types';

// Crear el Context
export const Web3Context = createContext();

// Crear el Provider
export const Web3Provider = ({ children }) => {
	const [provider, setProvider] = useState(null);
	const [web3auth, setWeb3auth] = useState(null);

	return (
		<Web3Context.Provider
			value={{ provider, setProvider, web3auth, setWeb3auth }}
		>
			{children}
		</Web3Context.Provider>
	);
};

Web3Provider.propTypes = {
	children: PropTypes.oneOfType([
		PropTypes.arrayOf(PropTypes.node),
		PropTypes.node,
	]).isRequired,
};
