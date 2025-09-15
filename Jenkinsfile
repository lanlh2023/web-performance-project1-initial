pipeline {
    agent any

    // TRIGGERS COMMENTED OUT - Manual trigger only for now
    // triggers {
    //     // Poll SCM every minute for changes
    //     pollSCM('* * * * *')
    //     // Alternative: Use webhook trigger if configured
    //     // githubPush()
    // }

    parameters {
        choice(
            name: 'DEPLOY_ENVIRONMENT',
            choices: ['both', 'firebase', 'remote', 'local'],
            description: 'Choose deployment environment: both (Firebase + Remote), firebase (Hosting), remote (Server), or local (template2)'
        )
        string(
            name: 'YOUR_NAME',
            defaultValue: 'lanlh',
            description: 'Your name for creating personal deployment folder (e.g., lanlh2)'
        )
        booleanParam(
            name: 'AUTO_DEPLOY',
            defaultValue: true,
            description: 'Automatically deploy to both Firebase and remote server (used for SCM-triggered builds)'
        )
    }

    environment {
        // Firebase credentials
        FIREBASE_TOKEN = credentials('firebase-token')
        FIREBASE_PROJECT = 'lanlh-workshop2'

        // Remote server credentials
        DEPLOY_USER = 'lanlee'
        DEPLOY_SERVER = '10.1.1.195'
        SSH_KEY = credentials('ssh-private-key')

        // Deployment paths
        REMOTE_BASE_PATH = "/usr/share/nginx/html/jenkins"
        PERSONAL_FOLDER = "${params.YOUR_NAME}2"
        TIMESTAMP = sh(script: 'date +%Y%m%d', returnStdout: true).trim()
    }

    stages {
        stage('Environment Check') {
            steps {
                echo "🔍 Verifying build environment..."

                sh '''
                    echo "📋 Node.js and npm versions:"
                    node --version
                    npm --version

                    # Check Node.js version compatibility (must be >= 20.0.0 for Firebase CLI)
                    NODE_VERSION=$(node --version | cut -d'v' -f2)
                    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)

                    if [ "$NODE_MAJOR" -lt 20 ]; then
                        echo "❌ ERROR: Node.js version $NODE_VERSION is not compatible with Firebase CLI"
                        echo "❌ Required: Node.js >= 20.0.0"
                        exit 1
                    else
                        echo "✅ Node.js version $NODE_VERSION is compatible with Firebase CLI"
                    fi
                    # Check if firebase CLI is available (pre-installed in container)
                    echo "🔍 Checking Firebase CLI availability..."
                    if command -v firebase >/dev/null 2>&1; then
                        echo "✅ Firebase CLI already available: $(firebase --version)"
                    else
                        echo "❌ Firebase CLI not found - should be pre-installed in container"
                    fi
                '''
            }
        }

        stage('Checkout(scm)') {
            steps {
                echo "🔍 Checking out source code..."
                checkout scm

                sh '''
                    echo "📋 Verifying workspace structure:"
                    pwd
                    ls -la

                    echo "✅ Critical files check:"
                    [ -f "package.json" ] && echo "✅ package.json found" || { echo "❌ package.json MISSING!"; exit 1; }
                    [ -f "index.html" ] && echo "✅ index.html found" || { echo "❌ index.html MISSING!"; exit 1; }
                    [ -d "js/" ] && echo "✅ js/ directory found" || { echo "❌ js/ directory MISSING!"; exit 1; }
                    [ -d "css/" ] && echo "✅ css/ directory found" || { echo "❌ css/ directory MISSING!"; exit 1; }
                    [ -d "images/" ] && echo "✅ images/ directory found" || { echo "❌ images/ directory MISSING!"; exit 1; }
                '''
            }
        }

        stage('Build') {
            steps {
                echo "📦 Building project..."

                sh '''
                    echo "🧹 Cleaning previous installations..."
                    rm -rf node_modules package-lock.json

                    echo "📦 Installing dependencies..."
                    npm install

                    echo "🔍 Verifying Firebase CLI installation..."
                    firebase --version

                    # Verify Node.js compatibility with Firebase CLI
                    echo "✅ Node.js version: $(node --version)"
                    echo "✅ Firebase CLI version: $(firebase --version)"

                    echo "✅ Build completed!"
                '''
            }
        }

        // stage('Lint/Test') {
        //     steps {
        //         echo "🧪 Running linting and tests..."

        //         sh '''
        //             echo "🔍 Running test:ci (lint + test)..."
        //             npm run test:ci

        //             echo "✅ All tests and linting passed!"
        //         '''
        //     }

        //     post {
        //         always {
        //             // Archive test results if available
        //             script {
        //                 if (fileExists('coverage/')) {
        //                     echo "📊 Archiving test coverage results..."
        //                     publishHTML([
        //                         allowMissing: false,
        //                         alwaysLinkToLastBuild: true,
        //                         keepAll: true,
        //                         reportDir: 'coverage/lcov-report',
        //                         reportFiles: 'index.html',
        //                         reportName: 'Test Coverage Report'
        //                     ])
        //                 }
        //             }
        //         }
        //     }
        // }

        stage('Deploy') {
            when {
                // Only deploy if tests pass
                expression { currentBuild.currentResult == null || currentBuild.currentResult == 'SUCCESS' }
            }

            steps {
                script {
                    // Determine deployment target
                    def deployTarget = params.DEPLOY_ENVIRONMENT

                    // For SCM-triggered builds (automatic), default to 'both'
                    if (env.BUILD_CAUSE == 'SCMTRIGGER' || params.AUTO_DEPLOY) {
                        deployTarget = 'both'
                        echo "🤖 SCM-triggered build detected - deploying to both Firebase and remote server"
                    }

                    echo "🚀 Starting deployment to: ${deployTarget}"

                    // Prepare deployment files
                    sh '''
                        echo "📦 Preparing deployment package..."

                        # Create deployment staging area
                        rm -rf deploy-staging
                        mkdir -p deploy-staging

                        # Copy only necessary files for deployment
                        echo "📋 Copying deployment files:"
                        cp index.html deploy-staging/
                        cp 404.html deploy-staging/
                        cp -r css deploy-staging/
                        cp -r js deploy-staging/
                        cp -r images deploy-staging/

                        # Optional: copy firebase config if exists
                        [ -f firebase.json ] && cp firebase.json deploy-staging/
                        [ -f .firebaserc ] && cp .firebaserc deploy-staging/

                        echo "✅ Deployment package prepared:"
                        ls -la deploy-staging/
                    '''

                    // Deploy to local using deploy-local.sh script
                    if (deployTarget == 'local' || deployTarget == 'both') {
                        echo "📱 Deploying to Local (jenkins-ws/template2)..."

                        sh '''
                            echo "🔧 Running local deployment script..."

                            # Make sure the script is executable
                            chmod +x deploy-local.sh

                            echo "🚀 Executing deploy-local.sh..."
                            ./deploy-local.sh

                            echo "✅ Local deployment completed!"
                        '''
                    }

                    // Deploy to Firebase Hosting
                    if (deployTarget == 'firebase' || deployTarget == 'both') {
                        echo "🔥 Deploying to Firebase Hosting..."

                        withCredentials([string(credentialsId: 'firebase-service-account-key', variable: 'FIREBASE_SERVICE_ACCOUNT_KEY')]) {
                            sh '''
                                echo "🔧 Running Firebase deployment script..."

                                # Make sure the script is executable
                                chmod +x deploy-firebase.sh

                                echo "🚀 Executing deploy-firebase.sh..."
                                ./deploy-firebase.sh

                                echo "✅ Firebase deployment completed!"
                            '''
                        }
                    }

                    // Deploy to remote server
                    if (deployTarget == 'remote' || deployTarget == 'both') {
                        echo "🌐 Deploying to Remote Server..."

                        sh '''
                            echo "🔧 Remote server deployment..."
                            echo "Target server: $DEPLOY_USER@$DEPLOY_SERVER"
                            echo "Personal folder: $PERSONAL_FOLDER"
                            echo "Timestamp: $TIMESTAMP"

                            # Create remote directory structure
                            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$DEPLOY_USER@$DEPLOY_SERVER" "
                                echo 'Creating directory structure...'
                                mkdir -p $REMOTE_BASE_PATH/$PERSONAL_FOLDER/web-performance-project1-initial
                                mkdir -p $REMOTE_BASE_PATH/$PERSONAL_FOLDER/deploy/$TIMESTAMP

                                echo 'Directory structure created:'
                                ls -la $REMOTE_BASE_PATH/$PERSONAL_FOLDER/
                            "

                            # Upload deployment files to timestamped directory
                            echo "📤 Uploading files to remote server..."
                            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r deploy-staging/* "$DEPLOY_USER@$DEPLOY_SERVER:$REMOTE_BASE_PATH/$PERSONAL_FOLDER/deploy/$TIMESTAMP/"

                            # Also copy to main project directory
                            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r deploy-staging/* "$DEPLOY_USER@$DEPLOY_SERVER:$REMOTE_BASE_PATH/$PERSONAL_FOLDER/web-performance-project1-initial/"

                            # Create/update symlink to current deployment
                            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$DEPLOY_USER@$DEPLOY_SERVER" "
                                cd $REMOTE_BASE_PATH/$PERSONAL_FOLDER/deploy

                                echo 'Updating current symlink...'
                                rm -f current
                                ln -sf $TIMESTAMP current

                                echo 'Current deployment:'
                                ls -la current/

                                echo 'Cleaning up old deployments (keeping last 5)...'
                                ls -1t | grep -E '^[0-9]{8}$' | tail -n +6 | xargs -r rm -rf

                                echo 'Remaining deployments:'
                                ls -la | grep -E '^d.*[0-9]{8}$' || echo 'No dated directories found'
                            "

                            echo "✅ Remote server deployment completed!"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                // Determine actual deployment target (same logic as in Deploy stage)
                def actualDeployTarget = params.DEPLOY_ENVIRONMENT
                if (env.BUILD_CAUSE == 'SCMTRIGGER' || params.AUTO_DEPLOY) {
                    actualDeployTarget = 'both'
                }
                
                def message = "✅ Build #${env.BUILD_NUMBER} completed successfully! 🚀\\n"
                message += "📋 Project: web-performance-project1-initial\\n"
                message += "🎯 Environment: ${actualDeployTarget}\\n"
                message += "👤 Personal folder: ${env.PERSONAL_FOLDER}\\n"
                message += "📅 Deployment: ${env.TIMESTAMP}\\n"
                
                if (env.BUILD_CAUSE == 'SCMTRIGGER') {
                    message += "🤖 Trigger: Automatic (SCM change detected)\\n"
                } else {
                    message += "👤 Trigger: Manual\\n"
                }
                message += "\\n"

                if (actualDeployTarget == 'local' || actualDeployTarget == 'both') {
                    message += "📱 Local: jenkins-ws/template2/current/\\n"
                    message += "🔗 Access: file://jenkins-ws/template2/current/index.html\\n"
                }

                if (actualDeployTarget == 'firebase' || actualDeployTarget == 'both') {
                    message += "🔥 Firebase: https://lanlh-workshop2.web.app/\\n"
                    message += "🔗 Alternative: https://lanlh-workshop2.firebaseapp.com/\\n"
                }

                if (actualDeployTarget == 'remote' || actualDeployTarget == 'both') {
                    message += "🌐 Remote: http://${env.DEPLOY_SERVER}/jenkins/${env.PERSONAL_FOLDER}/deploy/current/\\n"
                    message += "🔗 Project: http://${env.DEPLOY_SERVER}/jenkins/${env.PERSONAL_FOLDER}/web-performance-project1-initial/\\n"
                }

                echo message
            }
        }

        failure {
            echo "❌ Build #${env.BUILD_NUMBER} failed! 😞"
            echo "📋 Check the logs above for details"
            echo "🔗 Build URL: ${env.BUILD_URL}"
        }

        always {
            // Clean up
            sh '''
                echo "🧹 Cleaning up workspace..."
                rm -rf deploy-staging
                # Keep node_modules for potential next build speed
            '''

            // Archive artifacts
            archiveArtifacts artifacts: 'index.html,404.html,css/**,js/**,images/**', allowEmptyArchive: true

            echo "🏁 Pipeline completed"
        }
    }
}