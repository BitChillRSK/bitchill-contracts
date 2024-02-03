import { ToggleButton, ToggleButtonGroup } from '@mui/material';
import PropTypes from 'prop-types';

export default function DCAToggleButton({
	value,
	handleToggleButton,
	isSelected,
	label,
}) {
	return (
		<ToggleButtonGroup
			value={value}
			exclusive
			sx={{
				backgroundColor: isSelected ? '#FB8C00' : '#FFB04B',
				height: '44px',
			}}
			onChange={handleToggleButton}
			aria-label='text alignment'
		>
			<ToggleButton
				value={value}
				aria-label='left aligned'
				sx={{ width: '120px', height: '44px', color: 'white' }}
			>
				{label}
			</ToggleButton>
		</ToggleButtonGroup>
	);
}

DCAToggleButton.propTypes = {
	value: PropTypes.number,
	handleToggleButton: PropTypes.func,
	isSelected: PropTypes.bool,
	label: PropTypes.string,
};
