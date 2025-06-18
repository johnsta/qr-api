const express = require('express');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');
const qrcode = require('qrcode');
const sharp = require('sharp');
const { DefaultAzureCredential } = require('@azure/identity');
const { BlobServiceClient, StorageSharedKeyCredential } = require('@azure/storage-blob');
const Minio = require('minio');

// Initialize environment variables
dotenv.config();

const app = express();
const port = process.env.PORT || 8000;
const upload = multer({ storage: multer.memoryStorage() });

// Storage configuration
const STORAGE_TYPE = (process.env.STORAGE_TYPE || 'minio').toLowerCase();
const CONTAINER_NAME = process.env.CONTAINER_NAME || 'qrcodes';

// Abstract Storage Interface as a class
class StorageProvider {
  async initialize() {
    throw new Error('Method initialize() must be implemented');
  }
  
  async uploadBlob(blobName, data, contentType = null) {
    throw new Error('Method uploadBlob() must be implemented');
  }
  
  async downloadBlob(blobName) {
    throw new Error('Method downloadBlob() must be implemented');
  }
  
  async deleteBlob(blobName) {
    throw new Error('Method deleteBlob() must be implemented');
  }
  
  async blobExists(blobName) {
    throw new Error('Method blobExists() must be implemented');
  }
  
  getBlobUrl(blobName) {
    throw new Error('Method getBlobUrl() must be implemented');
  }
}

// Azure Blob Storage Provider
class AzureBlobStorageProvider extends StorageProvider {
  constructor(containerName) {
    super();
    this.containerName = containerName;
    this.blobServiceClient = null;
    this.containerClient = null;
  }
  
  async initialize() {
    // Azure Storage configuration
    const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;
    
    // Initialize Azure Storage client with connection pooling
    if (connectionString) {
      console.log('Using connection string for Azure Blob Storage');
      this.blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
    } else {
      // Use DefaultAzureCredential for passwordless authentication
      console.log('Using DefaultAzureCredential for passwordless authentication');
      try {
        let options = {};
        
        // Check if we're using managed identity
        if (process.env.AZURE_STORAGE_USE_MANAGED_IDENTITY === 'true') {
          console.log('Using managed identity for Azure Blob Storage');
          // For system-assigned identity, we don't need to specify the client ID
          // Just use DefaultAzureCredential which will automatically use the system-assigned identity
        }
        
        const credential = new DefaultAzureCredential(options);
        const accountName = process.env.AZURE_STORAGE_ACCOUNT_NAME;
        if (!accountName) {
          throw new Error('AZURE_STORAGE_ACCOUNT_NAME environment variable is required when using DefaultAzureCredential');
        }
        const accountUrl = `https://${accountName}.blob.core.windows.net`;
        this.blobServiceClient = new BlobServiceClient(accountUrl, credential);
      } catch (error) {
        console.warn(`Azure authentication warning: ${error.message}`);
        console.warn('Authentication issues will be handled gracefully if possible');
        // Don't throw error here, let's try to recover
      }
    }
    
    // Check if we have a valid blobServiceClient
    if (!this.blobServiceClient) {
      console.warn('BlobServiceClient not initialized correctly. Storage operations may fail.');
      // We'll continue execution - the app can still function with non-storage features
    } else {
      // Ensure container exists
      this.containerClient = this.blobServiceClient.getContainerClient(this.containerName);
      try {
        // Check if we can access the container before trying to create it
        await this.containerClient.create();
        console.log(`Container ${this.containerName} created or verified successfully.`);
      } catch (error) {
        // Container might already exist, which is fine
        if (error.statusCode === 409) {
          console.log(`Container ${this.containerName} already exists.`);
        } else {
          console.warn(`Warning accessing container: ${error.message}`);
          console.log('App will continue running but storage operations may fail.');
        }
      }
    }
  }
  
  async uploadBlob(blobName, data, contentType = null) {
    try {
      if (!this.containerClient) {
        throw new Error('Storage provider not initialized');
      }
      const blobClient = this.containerClient.getBlockBlobClient(blobName);
      const options = contentType ? { blobHTTPHeaders: { blobContentType: contentType } } : {};
      await blobClient.upload(data, data.length, options);
      return this.getBlobUrl(blobName);
    } catch (error) {
      console.error(`Error uploading blob: ${error.message}`);
      // Create a local URL instead as a fallback when storage fails
      return `/qrcode/${blobName}`; 
    }
  }
  
  async downloadBlob(blobName) {
    try {
      if (!this.containerClient) {
        throw new Error('Storage provider not initialized');
      }
      const blobClient = this.containerClient.getBlockBlobClient(blobName);
      return await blobClient.download();
    } catch (error) {
      console.error(`Error downloading blob: ${error.message}`);
      throw error;
    }
  }
  
  async deleteBlob(blobName) {
    try {
      if (!this.containerClient) {
        throw new Error('Storage provider not initialized');
      }
      const blobClient = this.containerClient.getBlockBlobClient(blobName);
      await blobClient.delete();
    } catch (error) {
      console.error(`Error deleting blob: ${error.message}`);
      // We'll consider this non-critical and continue
    }
  }
  
  async blobExists(blobName) {
    try {
      if (!this.containerClient) {
        return false; // Can't check if storage is not initialized
      }
      const blobClient = this.containerClient.getBlockBlobClient(blobName);
      await blobClient.getProperties();
      return true;
    } catch (error) {
      return false;
    }
  }
  
  getBlobUrl(blobName) {
    try {
      if (!this.containerClient) {
        return `/qrcode/${blobName}`; // Fallback for local URL
      }
      const blobClient = this.containerClient.getBlockBlobClient(blobName);
      return blobClient.url;
    } catch (error) {
      console.error(`Error getting blob URL: ${error.message}`);
      return `/qrcode/${blobName}`; // Fallback URL
    }
  }
}

// MinIO Storage Provider
class MinioStorageProvider extends StorageProvider {
  constructor(bucketName) {
    super();
    this.bucketName = bucketName;
    this.client = null;
    this.endpoint = process.env.MINIO_ENDPOINT || 'localhost:9000';
    this.accessKey = process.env.MINIO_ACCESS_KEY || 'minioadmin';
    this.secretKey = process.env.MINIO_SECRET_KEY || 'minioadmin';
    this.secure = (process.env.MINIO_SECURE || 'false').toLowerCase() === 'true';
  }
  
  async initialize() {
    // Initialize MinIO client
    this.client = new Minio.Client({
      endPoint: this.endpoint.split(':')[0],
      port: parseInt(this.endpoint.split(':')[1] || '9000'),
      useSSL: this.secure,
      accessKey: this.accessKey,
      secretKey: this.secretKey
    });
    
    // Ensure bucket exists with retries
    let retries = 5;
    let success = false;
    while (retries > 0 && !success) {
      try {
        console.log(`Checking if bucket ${this.bucketName} exists (retries left: ${retries})...`);
        const bucketExists = await this.client.bucketExists(this.bucketName);
        if (!bucketExists) {
          console.log(`Creating bucket ${this.bucketName}...`);
          await this.client.makeBucket(this.bucketName);
          console.log(`Bucket ${this.bucketName} created successfully.`);
        } else {
          console.log(`Bucket ${this.bucketName} already exists.`);
        }
        success = true;
      } catch (error) {
        retries--;
        console.error(`Error accessing MinIO (retries left: ${retries}): ${error.message}`);
        if (retries > 0) {
          console.log(`Retrying in 2 seconds...`);
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      }
    }
    
    if (!success) {
      console.error(`Failed to initialize MinIO bucket after multiple attempts`);
    }
  }
  
  async uploadBlob(blobName, data, contentType = null) {
    try {
      // Check if bucket exists first
      const bucketExists = await this.client.bucketExists(this.bucketName);
      if (!bucketExists) {
        console.log(`Bucket ${this.bucketName} doesn't exist, creating it...`);
        await this.client.makeBucket(this.bucketName);
      }

      // Handle different data types
      const dataBuffer = Buffer.isBuffer(data) ? data : Buffer.from(data);
      
      // Upload to MinIO
      await this.client.putObject(
        this.bucketName,
        blobName,
        dataBuffer,
        {
          'Content-Type': contentType || 'application/octet-stream'
        }
      );
      
      return this.getBlobUrl(blobName);
    } catch (error) {
      console.error(`Error uploading to MinIO: ${error.message}`);
      throw error;
    }
  }
  
  async downloadBlob(blobName) {
    try {
      return await this.client.getObject(this.bucketName, blobName);
    } catch (error) {
      console.error(`Error downloading object: ${error.message}`);
      throw error;
    }
  }
  
  async deleteBlob(blobName) {
    try {
      await this.client.removeObject(this.bucketName, blobName);
    } catch (error) {
      console.error(`Error deleting object: ${error.message}`);
      throw error;
    }
  }
  
  async blobExists(blobName) {
    try {
      await this.client.statObject(this.bucketName, blobName);
      return true;
    } catch (error) {
      return false;
    }
  }
  
  getBlobUrl(blobName) {
    // For MinIO, we generate a URL that works for both local development and production
    const protocol = this.secure ? 'https' : 'http';
    return `${protocol}://${this.endpoint}/${this.bucketName}/${blobName}`;
  }
}

// Initialize the appropriate storage provider
let storage;
if (STORAGE_TYPE === 'azure') {
  storage = new AzureBlobStorageProvider(CONTAINER_NAME);
} else { // Default to MinIO
  storage = new MinioStorageProvider(CONTAINER_NAME);
}

// Initialize the storage
(async () => {
  try {
    await storage.initialize();
    console.log(`Storage provider ${STORAGE_TYPE} initialized successfully.`);
  } catch (error) {
    console.error(`Error initializing storage: ${error.message}`);
  }
})();

// Utility functions
async function generateQrCode(data, size = 300) {
  // Generate QR code
  const qrBuffer = await qrcode.toBuffer(data, {
    errorCorrectionLevel: 'L',
    width: size,
    margin: 4,
  });
  
  // Resize with Sharp if necessary
  if (size !== 300) {
    return await sharp(qrBuffer)
      .resize(size, size)
      .toBuffer();
  }
  
  return qrBuffer;
}

async function updateMetadata(codeId, data, size, isAccess = false) {
  const metadataBlobName = `${codeId}.metadata`;
  const now = new Date().toISOString();
  
  try {
    let metadata;
    
    if (await storage.blobExists(metadataBlobName)) {
      // Read existing metadata
      const downloadResponse = await storage.downloadBlob(metadataBlobName);
      let metadataContent = '';
      
      // Handle Azure response
      if (downloadResponse.readableStreamBody) {
        const chunks = [];
        for await (const chunk of downloadResponse.readableStreamBody) {
          chunks.push(chunk);
        }
        metadataContent = Buffer.concat(chunks).toString();
      } else {
        // Handle MinIO response
        const chunks = [];
        downloadResponse.on('data', (chunk) => chunks.push(chunk));
        await new Promise((resolve, reject) => {
          downloadResponse.on('end', resolve);
          downloadResponse.on('error', reject);
        });
        metadataContent = Buffer.concat(chunks).toString();
      }
      
      metadata = JSON.parse(metadataContent);
      
      if (isAccess) {
        metadata.access_count += 1;
        metadata.last_accessed = now;
      }
    } else {
      throw new Error("Metadata doesn't exist");
    }
  } catch (error) {
    // Create new metadata if it doesn't exist or there was an error
    metadata = {
      code_id: codeId,
      data: data,
      size: size,
      created_at: now,
      last_accessed: now,
      access_count: 1
    };
  }
  
  // Upload the updated metadata
  await storage.uploadBlob(metadataBlobName, JSON.stringify(metadata), 'application/json');
  return metadata;
}

// Middleware to parse JSON requests
app.use(express.json());

// Routes
app.post('/api/qrcodes', async (req, res) => {
  try {
    const { data, size = 300 } = req.body;
    
    if (!data) {
      return res.status(400).json({ error: 'Missing required field: data' });
    }
    
    console.log(`Creating QR code for data: ${data.substring(0, 30)}${data.length > 30 ? '...' : ''}, size: ${size}`);
    
    const codeId = `${uuidv4()}.png`;
    const qrData = await generateQrCode(data, size);
    
    console.log(`QR code generated, uploading to storage as ${codeId}...`);
    
    // Upload QR code with appropriate content type
    try {
      await storage.uploadBlob(codeId, qrData, 'image/png');
      console.log(`QR code uploaded successfully`);
    } catch (uploadError) {
      console.error(`Storage upload failed: ${uploadError.message}`);
      return res.status(500).json({ error: `Storage error: ${uploadError.message}` });
    }
    
    // Store metadata
    try {
      await updateMetadata(codeId.replace('.png', ''), data, size);
      console.log(`Metadata stored successfully`);
    } catch (metadataError) {
      console.error(`Metadata update failed: ${metadataError.message}`);
      // Continue even if metadata fails
    }
    
    return res.status(201).json({
      code_id: codeId,
      url: `${req.protocol}://${req.get('host')}/api/qrcodes/${codeId}`
    });
  } catch (error) {
    console.error(`Error creating QR code: ${error.message}`);
    return res.status(500).json({ error: 'Internal server error', details: error.message });
  }
});

app.put('/api/qrcodes/:code_id', upload.single('file'), async (req, res) => {
  try {
    const { code_id } = req.params;
    const file = req.file;
    const xQrData = req.headers['x-qr-data'];
    const xQrSize = parseInt(req.headers['x-qr-size'] || '300');
    
    if (!file) {
      return res.status(400).json({ error: 'Missing file' });
    }
    
    if (file.mimetype !== 'image/png') {
      return res.status(400).json({ error: 'Only PNG images are supported' });
    }
    
    // Upload to storage
    await storage.uploadBlob(code_id, file.buffer, 'image/png');
    
    // Store metadata
    await updateMetadata(code_id.replace('.png', ''), xQrData, xQrSize);
    
    return res.status(201).json({
      code_id: code_id,
      url: `${req.protocol}://${req.get('host')}/api/qrcodes/${code_id}`
    });
  } catch (error) {
    console.error(`Error uploading QR code: ${error.message}`);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/qrcodes/:code_id', async (req, res) => {
  try {
    const { code_id } = req.params;
    
    if (!(await storage.blobExists(code_id))) {
      return res.status(404).json({ error: 'QR code not found' });
    }
    
    // Update access metadata
    await updateMetadata(code_id.replace('.png', ''), '', 0, true);
    
    // Stream the response
    const downloadResponse = await storage.downloadBlob(code_id);
    
    // Handle Azure response
    if (downloadResponse.readableStreamBody) {
      res.setHeader('Content-Type', 'image/png');
      downloadResponse.readableStreamBody.pipe(res);
    } else {
      // Handle MinIO response
      res.setHeader('Content-Type', 'image/png');
      downloadResponse.pipe(res);
    }
  } catch (error) {
    console.error(`Error retrieving QR code: ${error.message}`);
    return res.status(404).json({ error: 'QR code not found' });
  }
});

app.get('/api/qrcodes/:code_id/metadata', async (req, res) => {
  try {
    const { code_id } = req.params;
    const metadataBlobName = `${code_id}.metadata`;
    
    if (!(await storage.blobExists(metadataBlobName))) {
      return res.status(404).json({ error: 'QR code metadata not found' });
    }
    
    // Read metadata
    const downloadResponse = await storage.downloadBlob(metadataBlobName);
    let metadataContent = '';
    
    // Handle Azure response
    if (downloadResponse.readableStreamBody) {
      const chunks = [];
      for await (const chunk of downloadResponse.readableStreamBody) {
        chunks.push(chunk);
      }
      metadataContent = Buffer.concat(chunks).toString();
    } else {
      // Handle MinIO response
      const chunks = [];
      downloadResponse.on('data', (chunk) => chunks.push(chunk));
      await new Promise((resolve, reject) => {
        downloadResponse.on('end', resolve);
        downloadResponse.on('error', reject);
      });
      metadataContent = Buffer.concat(chunks).toString();
    }
    
    const metadata = JSON.parse(metadataContent);
    return res.json(metadata);
  } catch (error) {
    console.error(`Error retrieving QR code metadata: ${error.message}`);
    return res.status(404).json({ error: 'QR code metadata not found' });
  }
});

app.head('/api/qrcodes/:code_id', async (req, res) => {
  try {
    const { code_id } = req.params;
    
    if (await storage.blobExists(code_id)) {
      return res.status(200).end();
    } else {
      return res.status(404).end();
    }
  } catch (error) {
    console.error(`Error checking QR code: ${error.message}`);
    return res.status(404).end();
  }
});

app.delete('/api/qrcodes/:code_id', async (req, res) => {
  try {
    const { code_id } = req.params;
    
    // Delete image
    await storage.deleteBlob(code_id);
    
    // Delete metadata
    const metadataBlobName = `${code_id.replace('.png', '')}.metadata`;
    if (await storage.blobExists(metadataBlobName)) {
      await storage.deleteBlob(metadataBlobName);
    }
    
    return res.status(204).end();
  } catch (error) {
    console.error(`Error deleting QR code: ${error.message}`);
    return res.status(404).json({ error: 'QR code not found' });
  }
});

app.get('/health', (req, res) => {
  return res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    storage_type: STORAGE_TYPE,
    version: '1.1.0'
  });
});

// Start the server
app.listen(port, () => {
  console.log(`QR Code Generator API listening on port ${port}`);
});

module.exports = app; // Export for testing
