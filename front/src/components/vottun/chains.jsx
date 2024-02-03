import { useFetchVottunTestnet } from '../../hooks/vottun/useFetchVottunTest';
import ChainInfo from './chain-info';

export default function Chain() {
	/**
	 * data from vottun
	 */

	const { testNet, isLoading, error } = useFetchVottunTestnet();
	return (
		<article>
			<h1>Networks in Vottun</h1>
			<div>
				<h2>Testnet</h2>
				<div>
					{!isLoading &&
						testNet?.map(chain => <ChainInfo key={chain.id} {...chain} />)}
				</div>
			</div>
			<div>{error && <p>Ha habido un error: {JSON.stringify(error)}</p>}</div>
		</article>
	);
}
