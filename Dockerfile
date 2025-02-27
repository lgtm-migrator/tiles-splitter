FROM node:14.18.2 as build

WORKDIR /tmp/buildApp

COPY ./package*.json ./

RUN npm install
COPY . .
RUN npm run build

FROM osgeo/gdal:alpine-normal-3.4.1 as production
ENV CPL_VSIL_USE_TEMP_FILE_FOR_RANDOM_WRITE 'YES'
ENV GDAL_PAM_ENABLED 'NO'
RUN addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node

RUN mkdir /app
RUN mkdir /vsis3 && chmod -R 777 /vsis3
WORKDIR /app

RUN mkdir vrtOutputs && chmod -R 777 ./vrtOutputs

RUN apk update -q --no-cache \
    && apk add -q --no-cache python3 py3-pip \
    gcc git python3-dev musl-dev linux-headers \
    libc-dev  rsync \
    findutils wget util-linux grep libxml2-dev libxslt-dev


ARG VERSION=v14.18.2
ARG DISTRO=linux-x64
RUN wget "https://unofficial-builds.nodejs.org/download/release/$VERSION/node-$VERSION-$DISTRO-musl.tar.xz"
RUN tar -xJf node-$VERSION-$DISTRO-musl.tar.xz  -C /usr/local --strip-components=1 --no-same-owner \
    && ln -s "/usr/local/bin/node" /usr/local/bin/nodejs;


RUN apk add dumb-init

ENV NODE_ENV=production
ENV SERVER_PORT=8080

COPY --chown=node:node package*.json ./

RUN npm ci --only=production


COPY --chown=node:node --from=build /tmp/buildApp/dist .
COPY --chown=node:node ./config ./config

USER node
EXPOSE 8080
CMD ["dumb-init", "node", "--max_old_space_size=512", "./index.js"]
