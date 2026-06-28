def deployPostgres = false
def deployKeycloak = false
def deployJenkins = false
def deployKafka = false
def deployMinikube = false

pipeline {
    agent any

    parameters {
        booleanParam(name: 'DEPLOY_POSTGRES', defaultValue: true, description: 'Deploy PostgreSQL Server')
        booleanParam(name: 'DEPLOY_KEYCLOAK', defaultValue: true, description: 'Deploy Keycloak Server')
        booleanParam(name: 'DEPLOY_JENKINS', defaultValue: true, description: 'Deploy Jenkins Server')
        booleanParam(name: 'DEPLOY_KAFKA', defaultValue: true, description: 'Deploy Kafka Server')
        booleanParam(name: 'DEPLOY_MINIKUBE', defaultValue: true, description: 'Deploy Minikube & Kubernetes configurations')
        string(name: 'DEPLOY_SERVERS_LIST', defaultValue: '', description: 'Comma-separated list of servers to deploy (e.g., postgres,kafka or all) when called by other jobs')
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    // Check if the build was triggered by an upstream project (another job)
                    def causes = currentBuild.getBuildCauses()
                    boolean isUpstream = causes.any { it._class == 'hudson.model.Cause$UpstreamCause' }

                    if (isUpstream) {
                        echo "Triggered by upstream job. Defaulting all servers to false, parsing DEPLOY_SERVERS_LIST: '${params.DEPLOY_SERVERS_LIST}'"
                        def list = (params.DEPLOY_SERVERS_LIST ?: "").toLowerCase()
                        deployPostgres = list.contains("postgres") || list.contains("all")
                        deployKeycloak = list.contains("keycloak") || list.contains("all")
                        deployJenkins = list.contains("jenkins") || list.contains("all")
                        deployKafka = list.contains("kafka") || list.contains("all")
                        deployMinikube = list.contains("minikube") || list.contains("all")
                    } else {
                        echo "Triggered manually or via SCM. Using parameter checkbox values."
                        deployPostgres = params.DEPLOY_POSTGRES
                        deployKeycloak = params.DEPLOY_KEYCLOAK
                        deployJenkins = params.DEPLOY_JENKINS
                        deployKafka = params.DEPLOY_KAFKA
                        deployMinikube = params.DEPLOY_MINIKUBE
                    }

                    echo "Target deployment states -> Postgres: ${deployPostgres}, Keycloak: ${deployKeycloak}, Jenkins: ${deployJenkins}, Kafka: ${deployKafka}, Minikube: ${deployMinikube}"
                }
            }
        }

        stage('Set env') {
            steps {
                // Fetch the .env file from Jenkins secret file credentials.
                // Replace 'apigw-env' with your actual Secret File credential ID.
                withCredentials([file(credentialsId: 'apigw-env', variable: 'SECRET_ENV_FILE')]) {
                    sh 'cp $SECRET_ENV_FILE .env'
                    sh 'cp $SECRET_ENV_FILE postgres/.env'
                    sh 'cp $SECRET_ENV_FILE keycloak/.env'
                    sh 'cp $SECRET_ENV_FILE jenkins/.env'
                    sh 'cp $SECRET_ENV_FILE kafka/.env'
                }
            }
        }

        stage('Deploy network') {
            steps {
                dir('network') {
                    // Run the network sh script
                    sh 'bash network-compose.sh'
                }
            }
        }

        stage('Deploy postgres') {
            when {
                expression { return deployPostgres }
            }
            steps {
                dir('postgres') {
                    sh 'docker compose up -d'
                    sh '''
                        # Disable command tracing to prevent printing secrets
                        set +x
                        if [ -f .env ]; then
                            export $(cat .env | grep -v '^#' | xargs)
                        fi
                        # Re-enable command tracing
                        set -x
                        
                        DB_USER="${POSTGRES_USER}"
                        echo "Waiting for PostgreSQL to be ready on homeserver-pg (timeout 60s)..."
                        TIMEOUT=60
                        COUNTER=0
                        until docker exec homeserver-pg pg_isready -U "$DB_USER" >/dev/null 2>&1; do
                            if [ $COUNTER -ge $TIMEOUT ]; then
                                echo "ERROR: Timeout of ${TIMEOUT}s reached waiting for PostgreSQL to start!"
                                exit 1
                            fi
                            sleep 2
                            COUNTER=$((COUNTER + 2))
                        done
                        echo "PostgreSQL is ready!"
                    '''
                }
            }
        }

        stage('Deploy keycloak') {
            when {
                expression { return deployKeycloak }
            }
            steps {
                dir('keycloak') {
                    sh '''
                        # Disable command tracing to prevent printing secrets
                        set +x
                        if [ -f .env ]; then
                            export $(cat .env | grep -v '^#' | xargs)
                        fi
                        # Re-enable command tracing
                        set -x
                        
                        DB_USER="${POSTGRES_USER}"
                        echo "Waiting for PostgreSQL to be ready on homeserver-pg (timeout 60s)..."
                        TIMEOUT=60
                        COUNTER=0
                        until docker exec homeserver-pg pg_isready -U "$DB_USER" >/dev/null 2>&1; do
                            if [ $COUNTER -ge $TIMEOUT ]; then
                                echo "ERROR: Timeout of ${TIMEOUT}s reached waiting for PostgreSQL to start!"
                                exit 1
                            fi
                            sleep 2
                            COUNTER=$((COUNTER + 2))
                        done
                        echo "PostgreSQL is ready! Executing SQL initialization scripts..."
                        
                        # Execute SQL initialization scripts
                        bash scripts/run-sql.sh
                    '''
                    sh 'docker compose up -d'
                }
            }
        }

        stage('Deploy jenkins') {
            when {
                expression { return deployJenkins }
            }
            steps {
                dir('jenkins') {
                    sh 'docker compose up -d'
                }
            }
        }

        stage('Deploy kafka') {
            when {
                expression { return deployKafka }
            }
            steps {
                dir('kafka') {
                    sh 'docker compose up -d'
                }
            }
        }

        stage('Deploy minikube') {
            when {
                expression { return deployMinikube }
            }
            steps {
                dir('minikube') {
                    sh 'chmod +x setup.sh'
                    sh 'bash setup.sh'
                }
            }
        }
    }
}
