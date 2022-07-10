docker network create kafka-net
docker-compose down &&\
  docker-compose build &&\
  docker-compose up -d
