// poz 앱 린트 — 웹(site/)과 같은 엄격함을 유지한다: any 금지, 미사용 변수 차단, 타입 임포트 분리.
// https://docs.expo.dev/guides/using-eslint/
const { defineConfig } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');

module.exports = defineConfig([
  expoConfig,
  {
    ignores: ['dist/*', 'node_modules/*', '.expo/*'],
  },
  {
    files: ['**/*.ts', '**/*.tsx'],
    rules: {
      // 실수로 남은 코드·값을 빌드까지 끌고 가지 않는다 (_ 로 시작하면 의도적 무시)
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      // 타입 안전성 — site/ 와 동일 기준
      '@typescript-eslint/no-explicit-any': 'error',
      // 디버그 흔적 방지: 경고·에러 로그만 허용
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      eqeqeq: ['error', 'smart'],
    },
  },
]);
