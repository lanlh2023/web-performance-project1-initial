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
                    # Check Node.js version compatibility (must be >= 20.0.0 for Firebase CLI)
                    NODE_VERSION=$(node --version | cut -d'v' -f2)
                    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)

                    if [ "$NODE_MAJOR" -lt 20 ]; then
                        echo "❌ ERROR: Node.js version $NODE_VERSION incompatible with Firebase CLI (required: >= 20.0.0)"
                        exit 1
                    fi

                    # Check Firebase CLI availability
                    if ! command -v firebase >/dev/null 2>&1; then
                        echo "❌ Firebase CLI not found"
                        exit 1
                    fi

                    echo "✅ Environment check passed"
                '''
            }
        }

        stage('Checkout(scm)') {
            steps {
                echo "🔍 Checking out source code..."
                checkout scm

                sh '''
                    # Verify critical files exist
                    for file in package.json index.html js css images; do
                        [ -e "$file" ] || { echo "❌ Critical file/directory missing: $file"; exit 1; }
                    done
                    echo "✅ Critical files verified"
                '''
            }
        }

        stage('Build') {
            steps {
                echo "📦 Building project..."

                sh '''
                    # Clean and install dependencies
                    rm -rf node_modules package-lock.json
                    npm install --silent

                    # Verify Firebase CLI
                    firebase --version >/dev/null 2>&1 || { echo "❌ Firebase CLI verification failed"; exit 1; }

                    echo "✅ Build completed"
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
                        # Create deployment staging area
                        rm -rf deploy-staging
                        mkdir -p deploy-staging

                        # Copy deployment files
                        cp index.html 404.html deploy-staging/
                        cp -r css js images deploy-staging/
                        [ -f firebase.json ] && cp firebase.json deploy-staging/
                        [ -f .firebaserc ] && cp .firebaserc deploy-staging/

                        echo "✅ Deployment package prepared"
                    '''

                    // Deploy to local using deploy-local.sh script
                    if (deployTarget == 'local' || deployTarget == 'both') {
                        echo "📱 Deploying to Local..."

                        sh '''
                            chmod +x deploy-local.sh
                            ./deploy-local.sh
                            echo "✅ Local deployment completed"
                        '''
                    }

                    // Deploy to Firebase Hosting
                    if (deployTarget == 'firebase' || deployTarget == 'both') {
                        echo "🔥 Deploying to Firebase..."

                        withCredentials([string(credentialsId: 'firebase-service-account-key', variable: 'FIREBASE_SERVICE_ACCOUNT_KEY')]) {
                            sh '''
                                chmod +x deploy-firebase.sh
                                ./deploy-firebase.sh
                                echo "✅ Firebase deployment completed"
                            '''
                        }
                    }

                    // Deploy to remote server
                    if (deployTarget == 'remote' || deployTarget == 'both') {
                        echo "🌐 Deploying to Remote Server..."

                        sh '''
                            # Create remote directory structure
                            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$DEPLOY_USER@$DEPLOY_SERVER" "
                                mkdir -p $REMOTE_BASE_PATH/$PERSONAL_FOLDER/web-performance-project1-initial
                                mkdir -p $REMOTE_BASE_PATH/$PERSONAL_FOLDER/deploy/$TIMESTAMP
                            " >/dev/null 2>&1

                            # Upload deployment files
                            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r deploy-staging/* "$DEPLOY_USER@$DEPLOY_SERVER:$REMOTE_BASE_PATH/$PERSONAL_FOLDER/deploy/$TIMESTAMP/" >/dev/null 2>&1
                            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r deploy-staging/* "$DEPLOY_USER@$DEPLOY_SERVER:$REMOTE_BASE_PATH/$PERSONAL_FOLDER/web-performance-project1-initial/" >/dev/null 2>&1

                            # Update symlink and cleanup
                            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$DEPLOY_USER@$DEPLOY_SERVER" "
                                cd $REMOTE_BASE_PATH/$PERSONAL_FOLDER/deploy
                                rm -f current
                                ln -sf $TIMESTAMP current
                                ls -1t | grep -E '^[0-9]{8}$' | tail -n +6 | xargs -r rm -rf
                            " >/dev/null 2>&1

                            echo "✅ Remote server deployment completed"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                def actualDeployTarget = params.DEPLOY_ENVIRONMENT
                if (env.BUILD_CAUSE == 'SCMTRIGGER' || params.AUTO_DEPLOY) {
                    actualDeployTarget = 'both'
                }

                def message = "✅ Build #${env.BUILD_NUMBER} completed successfully!\\n"
                message += "🎯 Environment: ${actualDeployTarget} | 📅 ${env.TIMESTAMP}\\n"

                if (actualDeployTarget == 'firebase' || actualDeployTarget == 'both') {
                    message += "🔥 Firebase: https://lanlh-workshop2.web.app/\\n"
                }
                if (actualDeployTarget == 'remote' || actualDeployTarget == 'both') {
                    message += "🌐 Remote: http://${env.DEPLOY_SERVER}/jenkins/${env.PERSONAL_FOLDER}/deploy/current/\\n"
                }
                if (actualDeployTarget == 'local' || actualDeployTarget == 'both') {
                    message += "📱 Local: jenkins-ws/template2/current/\\n"
                }

                echo message
            }
        }

        failure {
            echo "❌ Build #${env.BUILD_NUMBER} failed! Check logs for details."
        }

        always {
            // Clean up
            sh 'rm -rf deploy-staging'

            // Archive artifacts
            archiveArtifacts artifacts: 'index.html,404.html,css/**,js/**,images/**', allowEmptyArchive: true
        }
    }
}