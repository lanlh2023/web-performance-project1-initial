const globals = require("globals");

module.exports = {
  env: {
    browser: true,
    node: true,
    es2021: true,
    jest: true
  },
  extends: [
    "eslint:recommended"
  ],
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: "script"
  },
  globals: {
    ...globals.browser,
    ...globals.node,
    ...globals.jest
  },
  rules: {
    "no-unused-vars": "warn",
    "no-console": "off"
  },
  overrides: [
    {
      files: ["**/*.test.js", "**/*.spec.js", "**/setupTests.js"],
      env: {
        jest: true
      },
      plugins: ["jest"],
      extends: [
        "eslint:recommended",
        "plugin:jest/recommended"
      ]
    }
  ]
};
