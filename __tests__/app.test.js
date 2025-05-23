const request = require('supertest');
const app = require('../app');
const qrcode = require('qrcode');

// Mock the storage provider
jest.mock('../app', () => {
  const originalModule = jest.requireActual('../app');
  
  // Create a mock storage provider
  const mockStorage = {
    initialize: jest.fn().mockResolvedValue(true),
    uploadBlob: jest.fn().mockResolvedValue('http://test-url/qrcodes/test-id.png'),
    downloadBlob: jest.fn().mockResolvedValue({
      readableStreamBody: {
        pipe: jest.fn()
      },
      on: jest.fn()
    }),
    deleteBlob: jest.fn().mockResolvedValue(true),
    blobExists: jest.fn().mockResolvedValue(true),
    getBlobUrl: jest.fn().mockReturnValue('http://test-url/qrcodes/test-id.png')
  };
  
  // Replace the storage provider
  originalModule.storage = mockStorage;
  
  return originalModule;
});

// Mock qrcode module
jest.mock('qrcode', () => ({
  toBuffer: jest.fn().mockResolvedValue(Buffer.from('fake-qr-code')),
}));

describe('QR Code API', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  test('GET /health returns healthy status', async () => {
    const response = await request(app).get('/health');
    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('status', 'healthy');
    expect(response.body).toHaveProperty('storage_type');
    expect(response.body).toHaveProperty('timestamp');
    expect(response.body).toHaveProperty('version', '1.0.0');
  });

  test('POST /api/qrcodes creates a new QR code', async () => {
    const response = await request(app)
      .post('/api/qrcodes')
      .send({ data: 'https://example.com', size: 300 });

    expect(response.statusCode).toBe(201);
    expect(response.body).toHaveProperty('code_id');
    expect(response.body).toHaveProperty('url');
    expect(qrcode.toBuffer).toHaveBeenCalledWith('https://example.com', expect.any(Object));
  });

  test('GET /api/qrcodes/:code_id returns a QR code image', async () => {
    const response = await request(app).get('/api/qrcodes/test-id.png');
    
    expect(response.statusCode).toBe(200);
    expect(response.headers['content-type']).toBe('image/png');
  });

  test('DELETE /api/qrcodes/:code_id deletes a QR code', async () => {
    const response = await request(app).delete('/api/qrcodes/test-id.png');
    
    expect(response.statusCode).toBe(204);
  });
});
