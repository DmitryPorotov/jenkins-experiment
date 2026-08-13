FROM nginx:alpine

# Remove default nginx welcome page (optional but common)
RUN rm -rf /usr/share/nginx/html/*

# Copy your site's index.html into nginx's default web root
COPY ./index.html /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]