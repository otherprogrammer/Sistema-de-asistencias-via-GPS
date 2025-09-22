module.exports = {
    root: true,
    parser: '@typescript-eslint/parser',
    parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        ecmaFeatures: { jsx: true }
    },
    settings: {
        react: { version: 'detect' }
    },
    plugins: [
        '@typescript-eslint',
        'react',
        'react-hooks',
        'jsx-a11y'
    ],
    extends: [
        'eslint:recommended',
        'plugin:@typescript-eslint/recommended',
        'plugin:@typescript-eslint/strict',
        'plugin:react/recommended',
        'plugin:react-hooks/recommended',
        'plugin:jsx-a11y/recommended',
        'plugin:prettier/recommended'
    ],
    rules: {
        '@typescript-eslint/no-explicit-any': 'error',
        '@typescript-eslint/explicit-function-return-type': 'warn',
        '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    }
};
