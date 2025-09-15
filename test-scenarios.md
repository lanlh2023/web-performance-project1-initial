# Test Scenarios for Jenkins Pipeline

## 📋 Overview
This document describes how to test different scenarios with the Jenkins pipeline.

## 🧪 Test Scenarios

### 1. ✅ Success Case (All tests pass)
**Current state**: Pipeline should pass with current code

### 2. ❌ Lint Error Case
**To create lint error**: Uncomment the performance-heavy code in `js/products.js`

```javascript
// In js/products.js, find and uncomment these lines:
// Simulate heavy operation. It could be a complex price calculation.
for (let i = 0; i < 10000000; i++) {
    const temp = Math.sqrt(i) * Math.sqrt(i);
}
```

**Steps to test**:
1. Edit `js/products.js`
2. Uncomment the heavy operation loop
3. Commit and push: `git add . && git commit -m "Add performance heavy operation" && git push`
4. Run Jenkins pipeline - should fail at Lint/Test stage

**To fix**: Comment out the code again and commit

### 3. ❌ Unit Test Failure Case
**To create test failure**: Change VAT value in `js/main.js`

```javascript
// In js/main.js, find and change:
let country = "France";
// let vat = 20;
let vat = 200;  // Change from 20 to 200
```

**Steps to test**:
1. Edit `js/main.js`
2. Change `let vat = 20` to `let vat = 200`
3. Commit and push: `git add . && git commit -m "Change VAT to 200 for testing" && git push`
4. Run Jenkins pipeline - should fail at Lint/Test stage with unit test failures

**To fix**: Change back to `let vat = 20` and commit

## 🚀 Deployment Testing

### Local Deployment (Firebase)
- Set parameter `DEPLOY_ENVIRONMENT` = `local`
- Should deploy to Firebase project

### Remote Deployment (Server)
- Set parameter `DEPLOY_ENVIRONMENT` = `remote`
- Set parameter `YOUR_NAME` = `your-name` (e.g., `lanlh`)
- Should create folder structure on remote server:
  ```
  /usr/share/nginx/html/jenkins/lanlh2/
  ├── web-performance-project1-initial/
  │   ├── index.html
  │   ├── 404.html
  │   ├── css/
  │   ├── js/
  │   └── images/
  └── deploy/
      ├── 20240915/  (YYYYMMDD format)
      │   ├── index.html
      │   ├── 404.html
      │   ├── css/
      │   ├── js/
      │   └── images/
      └── current -> 20240915/
  ```

### Both Deployments
- Set parameter `DEPLOY_ENVIRONMENT` = `both`
- Should deploy to both Firebase and remote server

## 📁 File Structure Explanation

**Why only copy specific files?**
The pipeline only copies essential runtime files (`index.html`, `404.html`, `css/`, `js/`, `images/`) because:

1. **Security**: Avoid exposing development files (`.git`, `node_modules`, config files)
2. **Performance**: Smaller deployment package, faster transfer
3. **Clean deployment**: Only production-ready files on the server
4. **Best practice**: Separation of development and production environments

**Files NOT copied**:
- `node_modules/` - Development dependencies
- `.git/` - Version control data
- `package.json`, `eslint.config.js` - Development configuration
- `Jenkinsfile` - CI/CD configuration
- Test files and coverage reports

## 🔧 Quick Commands

```bash
# Create lint error
sed -i '' 's|// for (let i = 0|for (let i = 0|' js/products.js
sed -i '' 's|//     const temp|    const temp|' js/products.js
sed -i '' 's|// }|}|' js/products.js

# Fix lint error
sed -i '' 's|for (let i = 0|// for (let i = 0|' js/products.js
sed -i '' 's|    const temp|//     const temp|' js/products.js
sed -i '' 's|^}|// }|' js/products.js

# Create test error
sed -i '' 's|let vat = 20|let vat = 200|' js/main.js

# Fix test error
sed -i '' 's|let vat = 200|let vat = 20|' js/main.js
```
