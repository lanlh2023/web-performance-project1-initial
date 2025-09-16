let js, globals;

try {
    js = require("@eslint/js");
    globals = require("globals");
} catch (error) {
    try {
        js = require("/usr/lib/node_modules/@eslint/js");
        globals = require("/usr/lib/node_modules/globals");
    } catch (globalError) {
        console.error("Cannot load required modules:", error.message);
        process.exit(1);
    }
}
module.exports = [
  {
    files: ["**/*.{js,mjs,cjs}"],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "script",
      globals: {
        ...globals.browser,
        ...globals.node
      }
    },
    rules: {
      ...js.configs.recommended.rules,
      "no-unused-vars": "warn",
      "no-console": "off"
    }
  },
  {
    files: ["**/*.test.js", "**/*.spec.js", "**/setupTests.js"],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "script",
      globals: {
        ...globals.browser,
        ...globals.node,
        ...globals.jest
      }
    },
    rules: {
      ...js.configs.recommended.rules,
      "no-unused-vars": "warn",
      "no-console": "off"
    }
  }
];

