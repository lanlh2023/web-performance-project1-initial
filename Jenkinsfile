pipeline {
    agent any

    triggers {
        // Poll SCM every minute for changes
        pollSCM('* * * * *')
        // GitHub hook trigger for GITScm polling
        githubPush()
    }

    parameters {
        choice(
            name: 'DEPLOY_ENVIRONMENT',
            choices: ['both', 'firebase', 'remote', 'local'],
            description: 'Choose deployment environment: both (Firebase + Remote), firebase (Hosting), remote (Server), or local (template2)'
        )
        string(
            name: 'YOUR_NAME',
            defaultValue: 'lanlh',
            description: 'Your name for creating personal deployment folder (e.g., lanlh)'
        )
        string(
            name: 'KEEP_DEPLOYMENTS',
            defaultValue: '5',
            description: 'Number of deployment folders to keep (older ones will be deleted)'
        )
    }

    environment {
        // Firebase credentials
        FIREBASE_TOKEN = credentials('firebase-token')
        FIREBASE_PROJECT = 'lanlh-workshop2'

        // Remote server credentials
        SSH_USER = 'newbie'              // SSH user for connection
        DEPLOY_SERVER = '118.69.34.46'   // SSH server
        SSH_PORT = '3334'                // SSH port
        WEB_SERVER = '10.1.1.195'        // Web server for HTTP access
        SSH_KEY = credentials('ssh-private-key')  // Should be newbie_id_rsa

        // Deployment paths
        REMOTE_BASE_PATH = "/usr/share/nginx/html/jenkins"
        DEPLOY_USER = "${params.YOUR_NAME}"      // Directory name based on YOUR_NAME parameter
        TIMESTAMP = sh(script: 'date +%Y%m%d%H%M%S', returnStdout: true).trim()
        KEEP_DEPLOYMENTS = "${params.KEEP_DEPLOYMENTS}"  // Number of deployments to keep

        // Slack notification
        SLACK_WEBHOOK_URL = credentials('slack-webhook-url')  // Slack webhook URL credential
    }

    stages {
        stage('Branch Check') {
            steps {
                script {
                    def currentBranch = env.GIT_BRANCH ?: sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    echo "🌿 Current branch: ${currentBranch}"
                    
                    // Remove origin/ prefix if present
                    currentBranch = currentBranch.replaceAll(/^origin\//, '')
                    
                    if (currentBranch != 'main') {
                        echo "⚠️ Skipping deployment - not on main branch (current: ${currentBranch})"
                        env.SKIP_DEPLOYMENT = 'true'
                    } else {
                        echo "✅ On main branch - proceeding with deployment"
                        env.SKIP_DEPLOYMENT = 'false'
                    }
                }
            }
        }

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
                allOf {
                    // Only deploy if tests pass
                    expression { currentBuild.currentResult == null || currentBuild.currentResult == 'SUCCESS' }
                    // Only deploy on main branch
                    expression { env.SKIP_DEPLOYMENT != 'true' }
                }
            }

            steps {
                script {
                    // Determine deployment target
                    def deployTarget = params.DEPLOY_ENVIRONMENT

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
                            echo "🔧 Running remote deployment script..."

                            # Make sure the script is executable
                            chmod +x deploy-remote.sh

                            echo "🚀 Executing deploy-remote.sh..."
                            ./deploy-remote.sh

                            echo "✅ Remote deployment completed"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                sendSlackNotification(true)
            }
        }

        failure {
            script {
                sendSlackNotification(false)
            }
        }

        always {
            // Clean up
            sh 'rm -rf deploy-staging'

            // Archive artifacts
            archiveArtifacts artifacts: 'index.html,404.html,css/**,js/**,images/**', allowEmptyArchive: true
        }
    }
}

def sendSlackNotification(boolean isSuccess) {
    try {
        // Skip if webhook not configured
        if (!env.SLACK_WEBHOOK_URL) {
            echo "⚠️ SLACK_WEBHOOK_URL not configured, skipping notification"
            return
        }

        // Get git info safely
        def author = sh(script: 'git log -1 --pretty=format:"%an" 2>/dev/null || echo "Unknown"', returnStdout: true).trim()
        def releaseDate = sh(script: 'date +%Y%m%d', returnStdout: true).trim()

        // Build message
        def message = isSuccess ? 
            ":white_check_mark: *SUCCESS*\n:bust_in_silhouette: ${author}\n:gear: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n:calendar: Release: ${releaseDate}" +
            getDeploymentLinks() :
            ":x: *FAILURE*\n:bust_in_silhouette: ${author}\n:gear: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n:page_with_curl: ${env.BUILD_URL}console"

        // Send notification with improved error handling
        def payload = groovy.json.JsonOutput.toJson([text: message, username: "Jenkins", icon_emoji: ":jenkins:"])
        writeFile file: 'payload.json', text: payload

        withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_TOKEN')]) {
            echo "🔗 Attempting to send Slack notification..."
            echo "📝 Payload size: ${payload.length()} characters"
            
            // Build webhook URL from token if needed
            def WEBHOOK_URL = ""
            if (env.SLACK_TOKEN.startsWith("https://hooks.slack.com/")) {
                WEBHOOK_URL = env.SLACK_TOKEN
                echo "✅ Using full webhook URL"
            } else {
                // Assume it's just the token part and build full URL
                // Format: https://hooks.slack.com/services/T00000000/B00000000/TOKEN
                echo "🔧 Building webhook URL from token..."
                echo "⚠️ Note: You should provide the full webhook URL in credentials for security"
                // For now, skip sending if we don't have full URL
                echo "❌ Please update credential 'slack-webhook-url' with full webhook URL"
                echo "💡 Format: https://hooks.slack.com/services/T00000000/B00000000/YOUR_TOKEN"
                return
            }
            
            // Send with better error handling and timeout
            def curlResult = sh(
                script: '''
                    set +e
                    curl_output=$(curl -X POST \
                        -H "Content-type: application/json" \
                        --data @payload.json \
                        --connect-timeout 10 \
                        --max-time 30 \
                        -w "HTTPCODE:%{http_code}" \
                        -s \
                        "$WEBHOOK_URL" 2>&1)
                    curl_exit_code=$?
                    echo "EXIT_CODE:$curl_exit_code"
                    echo "$curl_output"
                ''',
                returnStdout: true
            ).trim()
            
            // Parse results
            def lines = curlResult.split('\n')
            def exitCode = lines.find { it.startsWith('EXIT_CODE:') }?.split(':')[1] ?: 'unknown'
            def httpCode = lines.find { it.contains('HTTPCODE:') }?.split('HTTPCODE:')[1] ?: 'unknown'
            
            echo "🔍 Curl exit code: ${exitCode}"
            echo "🔍 HTTP response code: ${httpCode}"
            
            if (exitCode == '0' && httpCode == '200') {
                echo "✅ Slack notification sent successfully"
            } else {
                echo "⚠️ Slack notification failed - Exit: ${exitCode}, HTTP: ${httpCode}"
                if (exitCode == '6') {
                    echo "💡 Exit code 6 usually means: Could not resolve host or invalid URL"
                } else if (exitCode == '7') {
                    echo "💡 Exit code 7 usually means: Failed to connect to host"
                }
            }
        }

        sh 'rm -f payload.json'

    } catch (Exception e) {
        echo "⚠️ Slack notification error: ${e.getMessage()}"
        echo "📋 Stack trace: ${e.getStackTrace()}"
    }
}

def getDeploymentLinks() {
    def target = params.DEPLOY_ENVIRONMENT
    def links = ""

    if (target == 'firebase' || target == 'both') {
        links += "\n:fire: Firebase: https://${env.FIREBASE_PROJECT}.web.app"
    }
    if (target == 'remote' || target == 'both') {
        links += "\n:globe_with_meridians: Remote: http://${env.WEB_SERVER}/jenkins/${env.DEPLOY_USER}/current/"
    }
    if (target == 'local') {
        links += "\n:computer: Local: Deployment completed"
    }

    return links
}
