module.exports = function (api) {
  const babelEnv = api.env();

  api.cache(true);

  const plugins = [
    [
      'module-resolver',
      {
        root: ['./'],
        alias: {
          '@': './src',
        },
        extensions: ['.tsx', '.ts', '.js'],
      },
    ],
  ];

  if (babelEnv === 'production') {
    plugins.push(['babel-plugin-transform-remove-console', {exclude: ['error', 'warn']}]);
  }

  return {
    presets: ['module:@react-native/babel-preset'],
    plugins,
  };
};
