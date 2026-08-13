// Jenkinsfile
// Runs entirely as ephemeral pods inside the Kubernetes cluster where Jenkins
// itself lives. Requires the "Kubernetes" Jenkins plugin (bundled with the
// official Jenkins Helm chart) and the RBAC in k8s/jenkins-rbac.yaml applied.

def REGISTRY   = "registry.registry.svc.cluster.local:5000"
def REGISTRY_EXTERN = "localhost:30500"
def IMAGE_NAME = "myapp"
def APP_NS     = "default"

pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-deployer
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command: ["/busybox/cat"]
      tty: true
    - name: kubectl
      image: bitnami/kubectl:latest
      command: ["cat"]
      tty: true
"""
        }
    }

    triggers {
        // Requires the "Generic Webhook Trigger" or GitHub/GitLab plugin
        // configured to POST to Jenkins on push. See README for webhook setup.
        githubPush()
    }

    environment {
        IMAGE_TAG = "${env.GIT_COMMIT.take(7)}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // --- Optional: language-specific build/test step -------------------
        // Since the project mixes languages/build tools, the actual
        // compile/test step is expected to happen either:
        //   (a) inside the Dockerfile itself (recommended, multi-stage build), or
        //   (b) here, in an extra container in the pod spec above
        //       (e.g. add a "maven" or "node" container and `sh` into it).
        // Leaving this stage as a placeholder / hook.
        stage('Build & Test (pre-Docker)') {
            steps {
                echo 'Add language-specific build/test commands here if not handled inside the Dockerfile.'
            }
        }

        stage('Build & Push Image (Kaniko)') {
            steps {
                container('kaniko') {
                    sh """
                        /kaniko/executor \
                          --context=`pwd` \
                          --dockerfile=`pwd`/Dockerfile \
                          --destination=${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \
                          --destination=${REGISTRY}/${IMAGE_NAME}:latest \
                          --insecure \
                          --insecure-pull \
                          --skip-tls-verify
                    """
                    // --insecure/--skip-tls-verify are needed only because the
                    // in-cluster registry from k8s/registry-deployment.yaml
                    // serves plain HTTP. Remove these flags once you put TLS
                    // in front of the registry.
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh """
                        kubectl set image deployment/${IMAGE_NAME} \
                          ${IMAGE_NAME}=${REGISTRY_EXTERN}/${IMAGE_NAME}:${IMAGE_TAG} \
                          -n ${APP_NS} --record

                        kubectl rollout status deployment/${IMAGE_NAME} -n ${APP_NS} --timeout=120s
                    """
                }
            }
        }
    }

    post {
        failure {
            echo "Pipeline failed — deployment was not updated."
        }
        success {
            echo "Deployed ${IMAGE_NAME}:${IMAGE_TAG} to namespace ${APP_NS}"
        }
    }
}
