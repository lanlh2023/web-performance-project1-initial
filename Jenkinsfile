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

// Function to send Slack notifications
def sendSlackNotification(boolean isSuccess) {
    try {
        // Check if SLACK_WEBHOOK_URL exists
        if (!env.SLACK_WEBHOOK_URL) {
            echo "⚠️ SLACK_WEBHOOK_URL not configured, skipping Slack notification"
            return
        }

        def gitAuthor = "Unknown"
        def gitCommit = "No commit message"
        def gitTimestamp = sh(script: 'date -u +"%Y-%m-%d %H:%M:%S UTC"', returnStdout: true).trim()
        
        // Safely get git information
        try {
            gitAuthor = sh(script: 'git log -1 --pretty=format:"%an" 2>/dev/null || echo "Unknown"', returnStdout: true).trim()
            gitCommit = sh(script: 'git log -1 --pretty=format:"%s" 2>/dev/null || echo "No commit message"', returnStdout: true).trim()
        } catch (Exception gitError) {
            echo "⚠️ Could not retrieve git information: ${gitError.getMessage()}"
        }
        
        def slackMessage = ""
        
        if (isSuccess) {
            def deployTarget = params.DEPLOY_ENVIRONMENT
            def releaseDate = sh(script: 'date +%Y%m%d', returnStdout: true).trim()

            // Build success message with new format
            slackMessage = ":white_check_mark: *SUCCESS*\n" +
                          ":bust_in_silhouette: User: ${gitAuthor}\n" +
                          ":gear: Job: ${env.JOB_NAME}\n" +
                          ":hash: Build: #${env.BUILD_NUMBER}\n" +
                          ":calendar: Release: ${releaseDate}"

            // Add deployment links based on environment
            if (deployTarget == 'firebase' || deployTarget == 'both') {
                slackMessage += "\n:fire: Firebase: https://${env.FIREBASE_PROJECT}.web.app"
            }
            if (deployTarget == 'remote' || deployTarget == 'both') {
                slackMessage += "\n:globe_with_meridians: Remote: http://${env.WEB_SERVER}/jenkins/${env.DEPLOY_USER}/current/"
            }
            if (deployTarget == 'local') {
                slackMessage += "\n:computer: Local: Deployment completed successfully"
            }
            
        } else {
            // Build failure message with consistent format
            slackMessage = ":x: *FAILURE*\n" +
                          ":bust_in_silhouette: User: ${gitAuthor}\n" +
                          ":gear: Job: ${env.JOB_NAME}\n" +
                          ":hash: Build: #${env.BUILD_NUMBER}\n" +
                          ":warning: Environment: ${params.DEPLOY_ENVIRONMENT}\n" +
                          ":page_with_curl: Build Log: ${env.BUILD_URL}console"
        }
        
        // Create payload
        def payload = [
            text: slackMessage,
            username: "Jenkins",
            icon_emoji: ":jenkins:"
        ]
        
        echo "📤 Sending Slack notification..."
        echo "Message preview: ${slackMessage}"
        
        def response = httpRequest(
            httpMode: 'POST',
            contentType: 'APPLICATION_JSON',
            requestBody: groovy.json.JsonOutput.toJson(payload),
            url: env.SLACK_WEBHOOK_URL,
            validResponseCodes: '200:299',
            quiet: true
        )
        
        echo "✅ Slack notification sent successfully (HTTP ${response.status})"
        
    } catch (Exception e) {
        echo "⚠️ Slack notification failed: ${e.getMessage()}"
        echo "⚠️ Stack trace: ${e.toString()}"
        // Don't fail the build because of notification failure
    }
}