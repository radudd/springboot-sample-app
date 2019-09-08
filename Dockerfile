FROM maven

RUN mkdir /work
WORKDIR /work
COPY pom.xml /work/
COPY src /work/src

RUN mvn clean package -DskipTests

FROM quay.io/sshaaf/rhel7-jre8-mpdemo:latest
WORKDIR /
COPY --from=0 /work/target/springboot-sample-app.jar  /app/
CMD [ "/app/run-java.sh" ]
