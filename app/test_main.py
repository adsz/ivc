#!/usr/bin/env python3
"""
Unit tests for HeyCard Cryptocurrency Exchange Rates Application
"""

import json
import pytest
import requests
from unittest.mock import patch
from main import app, CryptoRatesAPI


class TestCryptoRatesAPI:
    """Test cases for CryptoRatesAPI class."""

    def setup_method(self):
        """Set up test fixtures."""
        self.api = CryptoRatesAPI()
        self.sample_api_response = {
            "rates": {
                "btc": {
                    "name": "Bitcoin",
                    "unit": "BTC",
                    "value": 1.0,
                    "type": "crypto"
                },
                "eth": {
                    "name": "Ether",
                    "unit": "ETH",
                    "value": 0.066,
                    "type": "crypto"
                },
                "usd": {
                    "name": "US Dollar",
                    "unit": "$",
                    "value": 43000.0,
                    "type": "fiat"
                }
            }
        }

    def test_api_initialization(self):
        """Test API client initialization."""
        assert self.api.base_url == "https://api.coingecko.com/api/v3"
        assert self.api.timeout == 10
        assert self.api.cache_duration == 300
        assert self.api.cached_data is None
        assert self.api.last_fetch == 0

    def test_successful_api_call(self, requests_mock):
        """Test successful API call and data processing."""
        requests_mock.get(
            f"{self.api.base_url}/exchange_rates",
            json=self.sample_api_response,
            status_code=200
        )

        result = self.api.get_exchange_rates()

        assert "rates" in result
        assert "last_updated" in result
        assert "total_currencies" in result
        assert result["total_currencies"] == 3
        assert "btc" in result["rates"]
        assert "eth" in result["rates"]
        assert "usd" in result["rates"]

    def test_api_timeout(self, requests_mock):
        """Test API timeout handling."""
        requests_mock.get(
            f"{self.api.base_url}/exchange_rates",
            exc=requests.exceptions.ConnectTimeout
        )

        result = self.api.get_exchange_rates()
        assert "error" in result
        assert "timeout" in result["error"].lower(
        ) or "unable to fetch" in result["error"].lower()

    def test_api_error_response(self, requests_mock):
        """Test API error response handling."""
        requests_mock.get(
            f"{self.api.base_url}/exchange_rates",
            status_code=500,
            text="Internal Server Error"
        )

        result = self.api.get_exchange_rates()
        assert "error" in result

    def test_caching_mechanism(self, requests_mock):
        """Test data caching functionality."""
        # Mock the HTTP request
        requests_mock.get(
            f"{self.api.base_url}/exchange_rates",
            json=self.sample_api_response
        )

        # First call should fetch fresh data
        result1 = self.api.get_exchange_rates()
        assert requests_mock.call_count == 1

        # Second immediate call should use cache
        result2 = self.api.get_exchange_rates()
        assert requests_mock.call_count == 1  # Still 1, not called again
        assert result1 == result2

    def test_data_processing(self):
        """Test data processing and sorting."""
        processed = self.api.process_rates_data(self.sample_api_response)

        assert "rates" in processed
        assert "last_updated" in processed
        assert "total_currencies" in processed

        # Check sorting (by value, descending)
        rates_list = list(processed["rates"].keys())
        values = [processed["rates"][key]["value"] for key in rates_list]
        assert values == sorted(values, reverse=True)

    def test_invalid_api_response(self):
        """Test handling of invalid API response."""
        invalid_response = {"invalid": "response"}

        with pytest.raises(ValueError):
            self.api.process_rates_data(invalid_response)


class TestFlaskApp:
    """Test cases for Flask application endpoints."""

    def setup_method(self):
        """Set up test fixtures."""
        self.app = app.test_client()
        self.app.testing = True

        # Mock CryptoRatesAPI
        self.mock_api_response = {
            "rates": {
                "btc": {
                    "name": "Bitcoin",
                    "unit": "BTC",
                    "value": 1.0,
                    "type": "crypto"
                },
                "usd": {
                    "name": "US Dollar",
                    "unit": "$",
                    "value": 43000.0,
                    "type": "fiat"
                }
            },
            "last_updated": "2024-01-01T12:00:00",
            "total_currencies": 2
        }

    @patch('main.crypto_api.get_exchange_rates')
    def test_index_route_success(self, mock_get_rates):
        """Test successful index route."""
        mock_get_rates.return_value = self.mock_api_response

        response = self.app.get('/')
        assert response.status_code == 200
        assert b"HeyCard eCommerce" in response.data
        assert b"Bitcoin" in response.data

    @patch('main.crypto_api.get_exchange_rates')
    def test_index_route_api_error(self, mock_get_rates):
        """Test index route with API error."""
        mock_get_rates.return_value = {"error": "API Error"}

        response = self.app.get('/')
        assert response.status_code == 500
        assert (b"error" in response.data.lower() or
                b"something went wrong" in response.data.lower())

    @patch('main.crypto_api.get_exchange_rates')
    def test_api_rates_endpoint_success(self, mock_get_rates):
        """Test successful API rates endpoint."""
        mock_get_rates.return_value = self.mock_api_response

        response = self.app.get('/api/rates')
        assert response.status_code == 200
        assert response.content_type == 'application/json'

        data = json.loads(response.data)
        assert "rates" in data
        assert "total_currencies" in data
        assert data["total_currencies"] == 2

    @patch('main.crypto_api.get_exchange_rates')
    def test_api_rates_endpoint_error(self, mock_get_rates):
        """Test API rates endpoint with error."""
        mock_get_rates.return_value = {"error": "API Error"}

        response = self.app.get('/api/rates')
        assert response.status_code == 200  # Still returns JSON with error

        data = json.loads(response.data)
        assert "error" in data

    @patch('main.crypto_api.get_exchange_rates')
    def test_health_check_healthy(self, mock_get_rates):
        """Test healthy health check."""
        mock_get_rates.return_value = self.mock_api_response

        response = self.app.get('/health')
        assert response.status_code == 200
        assert response.content_type == 'application/json'

        data = json.loads(response.data)
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "version" in data

    @patch('main.crypto_api.get_exchange_rates')
    def test_health_check_degraded(self, mock_get_rates):
        """Test degraded health check."""
        mock_get_rates.return_value = {"error": "API Error"}

        response = self.app.get('/health')
        assert response.status_code == 200

        data = json.loads(response.data)
        assert data["status"] == "degraded"

    @patch('main.crypto_api.get_exchange_rates')
    def test_health_check_exception(self, mock_get_rates):
        """Test health check with exception."""
        mock_get_rates.side_effect = Exception("Test exception")

        response = self.app.get('/health')
        assert response.status_code == 500

        data = json.loads(response.data)
        assert data["status"] == "unhealthy"
        assert "error" in data

    def test_metrics_endpoint(self):
        """Test Prometheus metrics endpoint."""
        response = self.app.get('/metrics')
        assert response.status_code == 200
        assert response.headers['Content-Type'].startswith('text/plain')

        # Check for expected metrics
        data = response.data.decode('utf-8')
        assert 'crypto_app_requests_total' in data
        assert 'crypto_app_request_duration_seconds' in data
        assert 'coingecko_api_calls_total' in data

    def test_404_error_handling(self):
        """Test 404 error handling."""
        response = self.app.get('/nonexistent')
        assert response.status_code == 404
        assert b"not found" in response.data.lower() or b"404" in response.data

    def test_metrics_increment(self):
        """Test that metrics are properly incremented."""
        # Make a request to increment metrics
        response = self.app.get('/health')
        assert response.status_code == 200

        # Check metrics endpoint
        metrics_response = self.app.get('/metrics')
        data = metrics_response.data.decode('utf-8')

        # Should contain request count metrics
        assert 'crypto_app_requests_total{endpoint="/health",method="GET"}' in data


class TestIntegration:
    """Integration tests for the complete application."""

    def setup_method(self):
        """Set up test fixtures."""
        self.app = app.test_client()
        self.app.testing = True

    def test_full_application_flow(self):
        """Test complete application flow."""
        # Test health check first
        health_response = self.app.get('/health')
        assert health_response.status_code in [200, 500]  # May fail if API is down

        # Test metrics are generated
        metrics_response = self.app.get('/metrics')
        assert metrics_response.status_code == 200

        # Check that metrics contain our custom metrics
        metrics_data = metrics_response.data.decode('utf-8')
        assert 'crypto_app_requests_total' in metrics_data

    def test_error_handling_chain(self):
        """Test error handling throughout the application."""
        with patch('main.crypto_api.get_exchange_rates') as mock_api:
            # Simulate various error conditions
            mock_api.side_effect = [
                {"error": "Network error"},
                {"error": "API rate limit"},
                Exception("Unexpected error")
            ]

            # Test API endpoint error handling
            response1 = self.app.get('/api/rates')
            data1 = json.loads(response1.data)
            assert "error" in data1

            # Test index page error handling
            response2 = self.app.get('/')
            assert response2.status_code == 500

            # Test health check error handling
            response3 = self.app.get('/health')
            assert response3.status_code == 500


# Test configuration
@pytest.fixture
def mock_env():
    """Mock environment variables for testing."""
    with patch.dict('os.environ', {
        'PORT': '5000',
        'API_TIMEOUT': '10',
        'CACHE_DURATION': '300',
        'APP_VERSION': '1.0.0-test'
    }):
        yield


def test_environment_configuration(mock_env):
    """Test environment variable configuration."""
    import os
    assert os.getenv('PORT') == '5000'
    assert os.getenv('API_TIMEOUT') == '10'
    assert os.getenv('CACHE_DURATION') == '300'
    assert os.getenv('APP_VERSION') == '1.0.0-test'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
