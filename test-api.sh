# filepath: /Users/johnsta/repos/qr-api/test-api.sh.new
#!/bin/zsh

# Test QR Code API script with enhanced features (Node.js version)

echo "🧪 Testing QR Code API with httpYac..."
echo "⚙️  Environment: ${1:-local}"

# Set environment
ENV=${1:-local}

# Set the base URL based on environment
if [[ "$ENV" == "production" ]]; then
  BASE_URL="https://your-production-url.azurewebsites.net"
else
  BASE_URL="http://localhost:8000"
fi

# Run basic test flow
echo "\n📝 Running basic QR code flow..."
httpyac api-tests.http#"1. Create a QR Code" \
  --env-var "baseUrl=$BASE_URL" \
  --continue api-tests.http#"3. Get the created QR Code Image" \
  --continue api-tests.http#"4. Get QR Code Metadata" \
  --continue api-tests.http#"5. Check if QR Code Exists (HEAD request)"

# Save a QR code to file
echo "\n💾 Saving QR code to file..."
mkdir -p test-output
httpyac api-tests.http#"3. Get the created QR Code Image" --env-var "baseUrl=$BASE_URL" --output test-output/qrcode.png

# Test different QR code types
echo "\n🔤 Testing different QR code types..."
httpyac api-tests.http#"9. Create a QR Code with Text" --env-var "baseUrl=$BASE_URL"
httpyac api-tests.http#"10. Create a QR Code with vCard contact information" --env-var "baseUrl=$BASE_URL"
httpyac api-tests.http#"11. Create a QR Code with WiFi information" --env-var "baseUrl=$BASE_URL"

# View the different QR code types
echo "\n👁️  Viewing different QR code types..."
httpyac api-tests.http#"14. View Different QR Codes" --env-var "baseUrl=$BASE_URL"

# Clean up all created QR codes
echo "\n🧹 Cleaning up all created QR codes..."
httpyac api-tests.http#"15. Clean Up All Created QR Codes" --env-var "baseUrl=$BASE_URL"

echo "\n✅ Testing completed!"
