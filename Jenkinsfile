#!groovy

node("maven") {
  def mvnCmd = "mvn"
  def devProject = "tasks-1"
  def prodProject = "tasks-2"
  def appName = "springboot-sample-app"
  // pom.xml 
  // <build>
  //  <finalName>springboot-sample-app</finalName>
  def ocpDockerRegistry = "docker-registry.default.svc:5000"
  def builderName = "openjdk18-openshift"
  def devTag  = "dev-" + currentBuild.number
  def prodTag = "prod"

  stage('Checkout Source') {
    checkout scm
  }

  stage('Build war') {
        echo "Building version ${devTag}"
        sh "${mvnCmd} clean package -DskipTests"
  }

  // The next two stages should run in parallel
  
  stage('Running tests') {
         echo "Running Unit Tests"
         sh "${mvnCmd} test" 
         sh "mkdir deployment && mv target/${appName}.jar deployment/"
  }
  

  // Publish the built war file to Nexus
  //stage('Publish to Nexus') {
  //  echo "Publish to Nexus"
  //  sh "${mvnCmd} deploy -DskipTests=true -DaltDeploymentRepository=nexus::default::${nexusUrl}/repository/releases"
  //}

  // Build the OpenShift Image in OpenShift and tag it.
  stage('Build and Tag OpenShift Image') {

    echo "Building OpenShift container image tasks:${devTag}"
    openshift.withCluster() {
        openshift.withProject("${devProject}") {
            def bcSelector = openshift.selector("bc", "${appName}-build")
            def bcExists = bcSelector.exists()
            if (!bcExists) {
              openshift.newBuild("--name=${appName}-build", "--image-stream=${builderName}", "--binary=true")
              sleep 2
            }
            openshift.selector("bc","${appName}-build").startBuild("--from-file=target/${appName}.jar")
            
            def buildConfig = openshift.selector("bc","${appName}").object()
            def buildVersion = buildConfig.status.lastVersion
            def build = openshift.selector("build", "${appName}-${buildVersion}").object()
            echo "Waiting for Build to complete"
            while (build.status.phase != "Complete"){
                if (build.status.phase == "Failed"){
                    error("Build failed")
                }
                sleep 5
                build = openshift.selector("build", "${appName}-${buildVersion}").object()
                echo "Current status: ${build.status.phase}"
            }
            openshift.tag("${appName}:latest","${appName}:${devTag}")
    	 }
      }
    }

  // Deploy the built image to the Development Environment.
  stage('Deploy to Dev') {
    echo "Deploying container image to Development Project"
    // Deploy to development Project
    //      Set Image, Set VERSION
    //      Make sure the application is running and ready before proceeding
    openshift.withCluster() {
        openshift.withProject("${devProject}") {
            openshift.set("image", "dc/${appName}", "${appName}=${ocpDockerRegistry}/${devProject}/${appName}:${devTag}")
            openshift.set("env", "dc/${appName}", "VERSION='${devTag} (tasks-dev)'")
            def dcDev = openshift.selector("dc","${appName}")
            dcDev.rollout().latest()
            def rcDevVersion = dcDev.object().status.latestVersion
            def rcDev = openshift.selector("rc","${appName}-${rcDevVersion}").object()
            echo "Waiting for DEV app to be ready"
            while (rcDev.status.readyReplicas != rcDev.spec.replicas) {
                sleep 10
                rcDev = openshift.selector("rc", "${appName}-${rcDevVersion}").object()
            }

      }
    }
  }

  // Blue/Green Deployment into Production
  // -------------------------------------
  def activeApp = ""
  def destApp   = ""

  stage('Blue/Green Production Deployment') {
    // Determine which application is active
    //      Set Image, Set VERSION
    //      Deploy into the other application
    //      Make sure the application is running and ready before proceeding
    openshift.withCluster() {
        openshift.withProject("${prodProject}") {
            activeApp = openshift.selector("route", "${appName}").object().spec.to.name
            if (activeApp == "${appName}-green") {
                destApp = "${appName}-blue"
                openshift.set("env", "dc/${appName}-blue", "VERSION='${prodTag} (tasks-blue)'")
            } else {
                destApp = "${appName}-green"
                openshift.set("env", "dc/${appName}-green", "VERSION='${prodTag} (tasks-green)'")
            }

            echo "Active app: " + activeApp
            echo "Dest app: " + destApp

            openshift.set("image", "dc/${destApp}", "${destApp}=${ocpDockerRegistry}/${devProject}/${appName}:${prodTag}")

            def dcProd = openshift.selector("dc","${destApp}")
            dcProd.rollout().latest()

            def rcProdVersion = dcProd.object().status.latestVersion
            def rcProd = openshift.selector("rc","${destApp}-${rcProdVersion}").object()
            echo "Waiting for ${destApp} to be ready"
            while (rcProd.status.readyReplicas != rcProd.spec.replicas) {
                sleep 10
                rcProd = openshift.selector("rc", "${destApp}-${rcProdVersion}").object()
            }
        }
    }
  }

  stage('Switch over to new Version') {
    echo "Switching Production application to ${destApp}."
    // Execute switch
    openshift.withCluster() {
        openshift.withProject("${prodProject}") {
            def prodRoute = openshift.selector("route", "${appName}").object()
            prodRoute.spec.to.name = "${destApp}"
            openshift.apply(prodRoute)
        }
    }
  }
}

// Convenience Functions to read version from the pom.xml
// Do not change anything below this line.
// --------------------------------------------------------
def getVersionFromPom(pom) {
  def matcher = readFile(pom) =~ '<version>(.+)</version>'
  matcher ? matcher[0][1] : null
}
