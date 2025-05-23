import os
import uuid
import logging
from locust import HttpUser, task, between
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class ApiUser(HttpUser):
    wait_time = between(1, 3)
    host = os.getenv("HOST", "https://qrcode-api-app.azurewebsites.net")
    timeout_duration = 90
    qr_code_id = None
    DEBUG_MODE = os.getenv('DEBUG_MODE', 'True') == 'True'

    @task
    def run_scenario(self):
        self.check_api_health()
        self.create_qr_code()
        self.get_qr_code_image()
        self.get_qr_code_metadata()
        self.delete_qr_code()
        self.verify_qr_code_deleted()

    def check_api_health(self):
        """Check API health."""
        with self.client.get(
            "/health",
            name="Check API Health",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed with status {response.status_code}")
                if self.DEBUG_MODE:
                    logging.error(f"Health check response: {response.text}")

    def create_qr_code(self):
        """Create a new QR code."""
        payload = {
            "data": "https://github.com",
            "size": 300
        }
        headers = {"Content-Type": "application/json"}

        with self.client.post(
            "/api/qrcodes",
            json=payload,
            headers=headers,
            name="Create QR Code",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    self.qr_code_id = response.json().get("code_id")
                    if not self.qr_code_id:
                        raise ValueError("QR Code ID not found in response")
                    response.success()
                except Exception as e:
                    response.failure(f"Failed to parse QR Code ID: {str(e)}")
                    if self.DEBUG_MODE:
                        logging.error(f"Create QR Code response: {response.text}")
            else:
                response.failure(f"Create QR Code failed with status {response.status_code}")
                if self.DEBUG_MODE:
                    logging.error(f"Create QR Code response: {response.text}")

    def get_qr_code_image(self):
        """Retrieve the QR code image."""
        if not self.qr_code_id:
            logging.error("QR Code ID is not set. Skipping Get QR Code Image.")
            return

        with self.client.get(
            f"/api/qrcodes/{self.qr_code_id}",
            name="Get QR Code Image",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Get QR Code Image failed with status {response.status_code}")
                if self.DEBUG_MODE:
                    logging.error(f"Get QR Code Image response: {response.text}")

    def get_qr_code_metadata(self):
        """Retrieve metadata about the QR code."""
        if not self.qr_code_id:
            logging.error("QR Code ID is not set. Skipping Get QR Code Metadata.")
            return

        metadata_id = self.qr_code_id.replace(".png", "")
        with self.client.get(
            f"/api/qrcodes/{metadata_id}/metadata",
            name="Get QR Code Metadata",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Get QR Code Metadata failed with status {response.status_code}")
                if self.DEBUG_MODE:
                    logging.error(f"Get QR Code Metadata response: {response.text}")

    def delete_qr_code(self):
        """Delete the QR code."""
        if not self.qr_code_id:
            logging.error("QR Code ID is not set. Skipping Delete QR Code.")
            return

        with self.client.delete(
            f"/api/qrcodes/{self.qr_code_id}",
            name="Delete QR Code",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code in [200, 204]:
                response.success()
            else:
                response.failure(f"Delete QR Code failed with status {response.status_code}")
                if self.DEBUG_MODE:
                    logging.error(f"Delete QR Code response: {response.text}")

    def verify_qr_code_deleted(self):
        """Verify the QR code is deleted."""
        if not self.qr_code_id:
            logging.error("QR Code ID is not set. Skipping Verify QR Code Deleted.")
            return

        with self.client.get(
            f"/api/qrcodes/{self.qr_code_id}",
            name="Verify QR Code Deleted",
            catch_response=True,
            timeout=self.timeout_duration
        ) as response:
            if response.status_code == 404:
                response.success()
            else:
                response.failure(f"Verify QR Code Deleted failed with status {response.status_code}")
                if self.DEBUG_MODE:
                    logging.error(f"Verify QR Code Deleted response: {response.text}")

    def on_stop(self):
        """Clean up resources if necessary."""
        if self.qr_code_id:
            self.delete_qr_code()