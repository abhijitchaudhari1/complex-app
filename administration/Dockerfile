FROM node:6.0

RUN mkdir -p /usr/src/app
COPY . /usr/src/app
WORKDIR /usr/src/app
RUN npm install
CMD sed -i  "s/api/${api}/g" server.js && node server.js
EXPOSE 8080
