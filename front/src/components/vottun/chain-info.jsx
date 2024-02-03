import PropTypes from 'prop-types';

export default function ChainInfo({
	id,
	name,
	symbol,
	explorer,
	testnetFaucet,
	typeId,
	typeName,
}) {
	return (
		<div>
			<div>
				<h2>{name}</h2>
				<p>Id: {id}</p>
				<p>symbol: {symbol}</p>
				<p>explorer: {explorer}</p>
				<p>testnetFaucet: {testnetFaucet}</p>
				<p>typeId: {typeId}</p>
				<p>typeName: {typeName}</p>
			</div>
		</div>
	);
}

ChainInfo.propTypes = {
	id: PropTypes.number,
	name: PropTypes.string,
	symbol: PropTypes.string,
	explorer: PropTypes.string,
	testnetFaucet: PropTypes.string,
	typeId: PropTypes.number,
	typeName: PropTypes.string,
};
