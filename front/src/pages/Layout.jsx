import { Outlet } from 'react-router-dom';
import Header from './../components/header/Header';
import Menu from '../components/menu/Menu';

export default function Layout() {
	return (
		<div>
			<div className='flex justify-center items-center'>
				<div className='lg:container sm:container'>
					<Header />
					<div
						style={{
							display: 'flex',
							flexDirection: 'row',
							justifyContent: 'flex-start',
						}}
					>
						<Menu />
						<Outlet />
					</div>
				</div>
			</div>
		</div>
	);
}
