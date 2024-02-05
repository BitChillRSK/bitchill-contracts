import { Stack } from '@mui/material';
import { useState } from 'react';
import PropTypes from 'prop-types';
import DCAToggleButton from './ToggleButton';

export default function DCAToggleGroup({
	listOfTogles,
	handlerSelect,
	initValue,
}) {
	const [valueSelected, setValueSelected] = useState(initValue);

	const handleAlignment = event => {
		setValueSelected(event.target.value);
		handlerSelect(event.target.value);
	};
	return (
		<>
			<Stack direction='row' spacing={4} justifyContent={'space-between'}>
				{listOfTogles.map(({ value, label }, index) => (
					<DCAToggleButton
						key={index}
						value={value}
						label={label}
						handleToggleButton={handleAlignment}
						isSelected={Number(value) === Number(valueSelected)}
					/>
				))}
			</Stack>
		</>
	);
}
DCAToggleGroup.propTypes = {
	listOfTogles: PropTypes.array,
	handlerSelect: PropTypes.func,
	initValue: PropTypes.number,
};
