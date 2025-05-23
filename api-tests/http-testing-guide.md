
# Testing Your QR Code API with httpYac

### Using httpYac from Command Line

```bash
# Run all requests in a file
httpyac api-tests.http

# Run a specific request
httpyac api-tests.http --name "healthCheck"

# Interactive mode (step through requests)
httpyac api-tests.http --interactive
```

### Environment Handling

```bash
# Default runs on local URL (http://localhost:8000)
httpyac api-tests.http

# Override host for production testing
httpyac api-tests.http --env-var "host=https://qrcode-api-app.azurewebsites.net"

# Or use the test script with environment parameter
./test-api.sh local     # Uses http://localhost:8000
./test-api.sh production  # Uses https://qrcode-api-app.azurewebsites.net
```



## Installation

### VS Code Extension
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X or Cmd+Shift+X)
3. Search for "httpYac" and install it

### Command Line Interface
```bash
npm install -g httpyac
```

## Testing Files

This project includes three options for API testing:

1. `api-tests.http` - Basic tests with detailed comments
2. `advanced-tests.http` - Enhanced tests with environments and variables
3. `test-api.sh` - Shell script for automated testing

## Using httpYac in VS Code

1. Open either `.http` file in VS Code
2. You'll see "Send Request" links above each request
3. Click these links to execute requests
4. For the basic file:
   - Run "Create a QR Code" first
   - Copy `code_id` from response
   - Paste it into the `@qrCodeId` variable
5. For the advanced file:
   - Requests automatically use response values from previous requests

## Using httpYac from Command Line

### Basic Usage

```bash
# Run all requests in a file
httpyac api-tests.http

# Run a specific request
httpyac api-tests.http --name "Health Check"

# Interactive mode (step through requests)
httpyac api-tests.http --interactive
```

### Advanced Features

```bash
# Set environment
httpyac advanced-tests.http --env local

# Set variables
httpyac api-tests.http --env-var qrCodeId=3fb1a262-4e40-4c53-8c55-1234abcd.png

# Save response to file
httpyac api-tests.http#"1. Create a QR Code" --output qr-response.json

# Verbose output
httpyac api-tests.http --verbose
```

### Using the Test Script

The included test script automates testing:

```bash
# Make it executable first (if needed)
chmod +x test-api.sh

# Run the script
./test-api.sh
```

The script will:
1. Create a QR code
2. Extract its ID
3. Test viewing the QR code
4. Test getting metadata
5. Test deletion
6. Test the deletion verification

## Testing Different Environments

The `advanced-tests.http` file includes environment configuration:

```bash
# Test against local environment (default)
httpyac advanced-tests.http --env local

# Test against production
httpyac advanced-tests.http --env production
```

## Additional httpYac Features

- **Request Chaining**: Use values from previous responses in subsequent requests
- **Environment Variables**: Define different environments for testing
- **Expected Status**: Verify responses match expected HTTP status codes
- **Authentication**: Supports various authentication methods
- **Scripting**: Add JavaScript for complex logic

For more information, visit the [httpYac documentation](https://httpyac.github.io/).
