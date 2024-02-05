import './App.css';
import AppRouter from './routers/AppRouter';
import { ThemeProvider, createTheme } from '@mui/material/styles';
const theme = createTheme({
	palette: {
		primary: {
			main: '#fb8c00',
		},
	},
});
function App() {
	return (
		<div style={{ minHeight: '100vh' }}>
			<ThemeProvider theme={theme}>
				<AppRouter />
			</ThemeProvider>
		</div>
	);
}

export default App;
