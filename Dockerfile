FROM maven
RUN mkdir /work
WORKDIR /work
COPY pom.xml /work/
COPY src /work/src
RUN mvn clean package -DskipTests
