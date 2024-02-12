import { Link } from 'react-router-dom';
import PropTypes from 'prop-types';

const EXPLORER_ULR = import.meta.env.VITE_EXPLORER_URL;
export default function ExplorerLink({ hash }) {
	return (
		<Link
			to={`${EXPLORER_ULR}${hash}`}
			target={'_blank'}
			rel={'noopener noreferrer'}
		>
			Revisa la transacción
		</Link>
	);
}

ExplorerLink.propTypes = {
	hash: PropTypes.string,
};
