module.exports = {
	env: {
		browser: true,
		es2021: true,
	},
	extends: [
		'standard',
		'plugin:react/recommended',
		'plugin:react/jsx-runtime',
		'eslint-config-prettier',
	],
	overrides: [
		{
			env: {
				node: true,
			},
			files: ['.eslintrc.{js,cjs}'],
			parserOptions: {
				sourceType: 'script',
			},
		},
	],
	settings: {
		react: {
			version: '18.2.0',
		},
	},
	parserOptions: {
		ecmaVersion: 'latest',
		sourceType: 'module',
	},
	plugins: ['react'],
	rules: {},
};
