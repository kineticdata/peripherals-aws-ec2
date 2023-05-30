plugins {
  java
  `maven-publish`
}

repositories {
  mavenLocal()
  maven {
    url = uri("https://s3.amazonaws.com/maven-repo-public-kineticdata.com/releases")
  }

  maven {
    url = uri("s3://maven-repo-private-kineticdata.com/releases")
    authentication {
      create<AwsImAuthentication>("awsIm")
    }

  }

  maven {
    url = uri("https://s3.amazonaws.com/maven-repo-public-kineticdata.com/snapshots")
  }

  maven {
    url = uri("s3://maven-repo-private-kineticdata.com/snapshots")
    authentication {
      create<AwsImAuthentication>("awsIm")
    }
  }

  maven {
    url = uri("https://repo.maven.apache.org/maven2/")
  }

  maven {
    url = uri("https://repo.springsource.org/release/")
  }

  maven {
    url = uri("https://build.shibboleth.net/nexus/content/repositories/releases/")
  }
}

dependencies {
  implementation("com.kineticdata.agent:kinetic-agent-adapter:1.1.0")
  implementation("org.apache.httpcomponents:httpclient:4.5.1")
  implementation("org.slf4j:slf4j-api:1.7.10")
  implementation("org.json:json:20140107")
  implementation("com.fasterxml.jackson.core:jackson-databind:2.5.0")
  testImplementation("junit:junit:4.13.1")
}

group = "com.kineticdata.bridges.adapter"
version = "2.0.1"
description = "kinetic-bridgehub-adapter-amazonec2"
java.sourceCompatibility = JavaVersion.VERSION_1_8

publishing {
  publications.create<MavenPublication>("maven") {
    from(components["java"])
  }
  repositories {
    maven {
      val releasesUrl = uri("s3://maven-repo-private-kineticdata.com/releases")
      val snapshotsUrl = uri("s3://maven-repo-private-kineticdata.com/snapshots")
      url = if (version.toString().endsWith("SNAPSHOT")) snapshotsUrl else releasesUrl
      authentication {
        create<AwsImAuthentication>("awsIm")
      }
    }
  }
}

tasks.withType<JavaCompile>() {
  options.encoding = "UTF-8"
}
