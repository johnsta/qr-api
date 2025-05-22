import os
import uuid
import abc
import io
from datetime import datetime, timezone
from typing import Optional, BinaryIO, Union, Dict, Any

import qrcode
from fastapi import FastAPI, HTTPException, Header, Response, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, HttpUrl
from dotenv import load_dotenv

# Import storage provider dependencies
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings
from minio import Minio
from minio.commonconfig import Tags
from minio.error import S3Error

load_dotenv()

app = FastAPI(title="QR Code Generator API")

# Storage configuration
STORAGE_TYPE = os.getenv("STORAGE_TYPE", "minio").lower()  # "azure" or "minio"
CONTAINER_NAME = os.getenv("CONTAINER_NAME", "qrcodes")

# Abstract Storage Interface
class StorageProvider(abc.ABC):
    @abc.abstractmethod
    def initialize(self):
        """Initialize the storage provider"""
        pass
    
    @abc.abstractmethod
    def upload_blob(self, blob_name: str, data: Union[bytes, BinaryIO], content_type: str = None) -> str:
        """Upload a blob and return its URL"""
        pass
    
    @abc.abstractmethod
    def download_blob(self, blob_name: str):
        """Download a blob and return a stream"""
        pass
    
    @abc.abstractmethod
    def delete_blob(self, blob_name: str):
        """Delete a blob"""
        pass
    
    @abc.abstractmethod
    def blob_exists(self, blob_name: str) -> bool:
        """Check if a blob exists"""
        pass
    
    @abc.abstractmethod
    def get_blob_url(self, blob_name: str) -> str:
        """Get the URL to access a blob"""
        pass

# Azure Blob Storage Provider
class AzureBlobStorageProvider(StorageProvider):
    def __init__(self, container_name: str):
        self.container_name = container_name
        self.blob_service_client = None
        self.container_client = None
        
    def initialize(self):
        # Azure Storage configuration
        connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
        
        # Initialize Azure Storage client with connection pooling
        if connection_string:
            self.blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        else:
            # Use managed identity in production
            credential = DefaultAzureCredential()
            account_url = f"https://{os.getenv('AZURE_STORAGE_ACCOUNT_NAME')}.blob.core.windows.net"
            self.blob_service_client = BlobServiceClient(account_url, credential=credential)
        
        # Ensure container exists
        self.container_client = self.blob_service_client.get_container_client(self.container_name)
        try:
            self.container_client.create_container()
        except Exception:
            # Container might already exist, which is fine
            pass
    
    def upload_blob(self, blob_name: str, data: Union[bytes, BinaryIO], content_type: str = None) -> str:
        blob_client = self.container_client.get_blob_client(blob_name)
        content_settings = None
        if content_type:
            content_settings = ContentSettings(content_type=content_type)
        blob_client.upload_blob(data, content_settings=content_settings, overwrite=True)
        return self.get_blob_url(blob_name)
    
    def download_blob(self, blob_name: str):
        blob_client = self.container_client.get_blob_client(blob_name)
        return blob_client.download_blob().chunks()
    
    def delete_blob(self, blob_name: str):
        blob_client = self.container_client.get_blob_client(blob_name)
        blob_client.delete_blob()
    
    def blob_exists(self, blob_name: str) -> bool:
        blob_client = self.container_client.get_blob_client(blob_name)
        try:
            blob_client.get_blob_properties()
            return True
        except Exception:
            return False
    
    def get_blob_url(self, blob_name: str) -> str:
        blob_client = self.container_client.get_blob_client(blob_name)
        return blob_client.url

# MinIO Storage Provider
class MinioStorageProvider(StorageProvider):
    def __init__(self, container_name: str):
        self.bucket_name = container_name
        self.client = None
        self.endpoint = os.getenv("MINIO_ENDPOINT", "localhost:9000")
        self.access_key = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
        self.secret_key = os.getenv("MINIO_SECRET_KEY", "minioadmin")
        self.secure = os.getenv("MINIO_SECURE", "false").lower() == "true"
        
    def initialize(self):
        # Initialize MinIO client
        self.client = Minio(
            self.endpoint,
            access_key=self.access_key,
            secret_key=self.secret_key,
            secure=self.secure
        )
        
        # Ensure bucket exists
        try:
            if not self.client.bucket_exists(self.bucket_name):
                self.client.make_bucket(self.bucket_name)
        except S3Error as e:
            print(f"Error creating bucket: {e}")
    
    def upload_blob(self, blob_name: str, data: Union[bytes, BinaryIO], content_type: str = None) -> str:
        # Convert bytes to BytesIO if needed
        if isinstance(data, bytes):
            data_io = io.BytesIO(data)
            data_size = len(data)
        else:
            data_io = data
            data.seek(0, os.SEEK_END)
            data_size = data.tell()
            data.seek(0)
            
        content_type = content_type or "application/octet-stream"
        
        # Upload to MinIO
        self.client.put_object(
            bucket_name=self.bucket_name,
            object_name=blob_name,
            data=data_io,
            length=data_size,
            content_type=content_type
        )
        
        return self.get_blob_url(blob_name)
    
    def download_blob(self, blob_name: str):
        try:
            response = self.client.get_object(self.bucket_name, blob_name)
            return response
        except S3Error as e:
            print(f"Error downloading object: {e}")
            raise
    
    def delete_blob(self, blob_name: str):
        try:
            self.client.remove_object(self.bucket_name, blob_name)
        except S3Error as e:
            print(f"Error deleting object: {e}")
            raise
    
    def blob_exists(self, blob_name: str) -> bool:
        try:
            self.client.stat_object(self.bucket_name, blob_name)
            return True
        except S3Error:
            return False
    
    def get_blob_url(self, blob_name: str) -> str:
        # For MinIO, we generate a URL that works for both local development and production
        protocol = "https" if self.secure else "http"
        return f"{protocol}://{self.endpoint}/{self.bucket_name}/{blob_name}"

# Initialize the appropriate storage provider
if STORAGE_TYPE == "azure":
    storage = AzureBlobStorageProvider(CONTAINER_NAME)
else:  # Default to MinIO
    storage = MinioStorageProvider(CONTAINER_NAME)

# Initialize the storage
storage.initialize()

class QRCodeRequest(BaseModel):
    data: str
    size: int = 300

class QRCodeResponse(BaseModel):
    code_id: str
    url: str

class QRCodeMetadata(BaseModel):
    code_id: str
    data: str
    size: int
    created_at: datetime
    last_accessed: datetime
    access_count: int

# Utility functions
def generate_qr_code(data: str, size: int) -> bytes:
    """Generate a QR code image"""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    img = img.resize((size, size))
    
    # Save to bytes
    from io import BytesIO
    img_byte_arr = BytesIO()
    img.save(img_byte_arr, format='PNG')
    return img_byte_arr.getvalue()

def update_metadata(code_id: str, data: str, size: int, is_access: bool = False):
    """Update metadata for a QR code"""
    metadata_blob_name = f"{code_id}.metadata"
    now = datetime.now(timezone.utc)
    
    try:
        if storage.blob_exists(metadata_blob_name):
            # Read existing metadata
            metadata_content = b''
            for chunk in storage.download_blob(metadata_blob_name):
                if isinstance(chunk, bytes):
                    metadata_content += chunk
                else:
                    metadata_content += chunk.read()
            
            metadata = eval(metadata_content.decode())
            if is_access:
                metadata["access_count"] += 1
                metadata["last_accessed"] = now.isoformat()
        else:
            raise Exception("Metadata doesn't exist")
    except Exception:
        metadata = {
            "code_id": code_id,
            "data": data,
            "size": size,
            "created_at": now.isoformat(),
            "last_accessed": now.isoformat(),
            "access_count": 1
        }
    
    # Upload the updated metadata
    storage.upload_blob(metadata_blob_name, str(metadata).encode(), content_type="application/json")
    return metadata

@app.post("/api/qrcodes", response_model=QRCodeResponse, status_code=201)
async def create_qr_code(request: QRCodeRequest):
    """Generate and store a new QR code"""
    code_id = f"{uuid.uuid4()}.png"
    qr_data = generate_qr_code(request.data, request.size)
    
    # Upload QR code with appropriate content type
    storage.upload_blob(code_id, qr_data, content_type="image/png")
    
    # Store metadata
    update_metadata(code_id.replace(".png", ""), request.data, request.size)
    
    return QRCodeResponse(
        code_id=code_id,
        url=f"{app.root_path}/api/qrcodes/{code_id}"
    )

@app.put("/api/qrcodes/{code_id}", response_model=QRCodeResponse, status_code=201)
async def upload_qr_code(
    code_id: str,
    file: UploadFile,
    x_qr_data: str = Header(None),
    x_qr_size: int = Header(300)
):
    """Upload a pre-generated QR code"""
    if not file.content_type == "image/png":
        raise HTTPException(status_code=400, detail="Only PNG images are supported")
    
    storage.upload_blob(code_id, file.file, content_type="image/png")
    
    # Store metadata
    update_metadata(code_id.replace(".png", ""), x_qr_data, x_qr_size)
    
    return QRCodeResponse(
        code_id=code_id,
        url=f"{app.root_path}/api/qrcodes/{code_id}"
    )

@app.get("/api/qrcodes/{code_id}")
async def get_qr_code(code_id: str):
    """Retrieve a QR code image"""
    try:
        if not storage.blob_exists(code_id):
            raise HTTPException(status_code=404, detail="QR code not found")
        
        # Update access metadata
        update_metadata(code_id.replace(".png", ""), "", 0, is_access=True)
        
        # Stream the response
        return StreamingResponse(
            storage.download_blob(code_id),
            media_type="image/png"
        )
    except Exception as e:
        raise HTTPException(status_code=404, detail="QR code not found")

@app.get("/api/qrcodes/{code_id}/metadata", response_model=QRCodeMetadata)
async def get_qr_code_metadata(code_id: str):
    """Get metadata for a QR code"""
    try:
        metadata_blob_name = f"{code_id}.metadata"
        if not storage.blob_exists(metadata_blob_name):
            raise HTTPException(status_code=404, detail="QR code metadata not found")
            
        # Read metadata
        metadata_content = b''
        for chunk in storage.download_blob(metadata_blob_name):
            if isinstance(chunk, bytes):
                metadata_content += chunk
            else:
                metadata_content += chunk.read()
        
        metadata = eval(metadata_content.decode())
        return QRCodeMetadata(**metadata)
    except Exception as e:
        raise HTTPException(status_code=404, detail="QR code metadata not found")

@app.head("/api/qrcodes/{code_id}")
async def check_qr_code(code_id: str):
    """Check if a QR code exists"""
    try:
        if storage.blob_exists(code_id):
            return Response(status_code=200)
        else:
            raise HTTPException(status_code=404, detail="QR code not found")
    except Exception:
        raise HTTPException(status_code=404, detail="QR code not found")

@app.delete("/api/qrcodes/{code_id}", status_code=204)
async def delete_qr_code(code_id: str):
    """Delete a QR code"""
    try:
        # Delete image
        storage.delete_blob(code_id)
        
        # Delete metadata
        metadata_blob_name = f"{code_id.replace('.png', '')}.metadata"
        if storage.blob_exists(metadata_blob_name):
            storage.delete_blob(metadata_blob_name)
    except Exception:
        raise HTTPException(status_code=404, detail="QR code not found")
