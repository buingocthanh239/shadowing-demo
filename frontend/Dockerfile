FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# Sub-path deploy, vd /project/shadowing. API gọi cùng domain: ${BASE_PATH}/api
ARG BASE_PATH=""
ENV BASE_PATH=$BASE_PATH VITE_API_URL=$BASE_PATH
RUN npm run build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
