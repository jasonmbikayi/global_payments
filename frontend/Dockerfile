FROM node:20

# Set working directory
WORKDIR /app

# Install dependencies first (better for caching)
COPY package*.json ./
RUN npm install

# Copy all source files (index.html, vite.config.js, src/, public/, etc.)
COPY . .

# Expose Vite dev server port
EXPOSE 5173

# Run Vite dev server binding to 0.0.0.0 (so host can access it)
CMD ["npm", "run", "dev"]
# CMD ["npm", "run", "dev", "--", "--host"]
# CMD ["npm", "run", "dev", "--", "--host="172.22.0.4"]
##To rebuild in Prod and start
# CMD ["npm", "run", "build"]
# CMD ["npx", "serve", "-s", "dist"]
# CMD ["npx", "serve", "-s", "dist", "-l", "3001"]
# CMD ["npx", "serve", "-s", "dist", "-l", "80"]
# CMD ["npx", "serve", "-s", "dist", "-l", "5173"]
# CMD ["npx", "serve", "-s", "dist", "-l", "5432"]
# CMD ["npx", "serve", "-s", "dist", "-l", "8080"]