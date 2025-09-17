# Login and capture response
response=$(curl -s --location 'http://0.0.0.0:3001/api/auth/login' \
--header 'Content-Type: application/json' \
--data '{
    "email": "alice@example.com",
    "password": "alice123"
}')

# Extract token (assuming JSON response with token field)
token=$(echo $response | grep -o '"token":"[^"]*' | grep -o '[^"]*$')

# Use token to access protected endpoint
curl --location 'http://0.0.0.0:3001/api/me' \
--header "Authorization: Bearer $token"