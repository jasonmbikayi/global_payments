# Use official Node.js 20 Alpine image
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json, then install dependencies
COPY package.json package-lock.json ./
#COPY ../ssl /app/ssl  # Copy SSL files

RUN npm install --production

# Copy the rest of the backend code
COPY . .

# Expose backend port
EXPOSE 3001

# Start the server
CMD ["node", "app.js"]

