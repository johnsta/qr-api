module.exports = {
  testEnvironment: 'node',
  verbose: true,
  collectCoverage: true,
  collectCoverageFrom: [
    'app.js',
    '!**/node_modules/**',
    '!**/vendor/**'
  ],
  coverageReporters: ['text', 'lcov', 'clover', 'html'],
  testMatch: ['**/__tests__/**/*.test.js'],
};
