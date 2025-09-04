#!/usr/bin/env python3
"""
Cryptocurrency Exchange Rates Display Application
Fetches real-time exchange rates from CoinGecko API and displays them
in a presentable web interface.
"""

import os
import requests
import time
from datetime import datetime
from flask import Flask, render_template, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('crypto_app_requests_total',
                        'Total app requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('crypto_app_request_duration_seconds', 'Request latency')
API_CALLS = Counter('coingecko_api_calls_total',
                    'Total CoinGecko API calls', ['status'])

app = Flask(__name__)


class CryptoRatesAPI:
    """CoinGecko API client for fetching cryptocurrency exchange rates."""

    def __init__(self):
        self.base_url = "https://api.coingecko.com/api/v3"
        self.timeout = int(os.getenv('API_TIMEOUT', 10))
        self.cache_duration = int(os.getenv('CACHE_DURATION', 300))  # 5 minutes
        self.last_fetch = 0
        self.cached_data = None

    def get_exchange_rates(self):
        """Fetch exchange rates from CoinGecko API with caching."""
        current_time = time.time()

        # Return cached data if still valid
        if (self.cached_data and
                current_time - self.last_fetch < self.cache_duration):
            logger.info("Returning cached exchange rates data")
            return self.cached_data

        try:
            logger.info("Fetching fresh exchange rates from CoinGecko API")
            response = requests.get(
                f"{self.base_url}/exchange_rates",
                timeout=self.timeout
            )
            response.raise_for_status()

            data = response.json()
            self.cached_data = self.process_rates_data(data)
            self.last_fetch = current_time

            API_CALLS.labels(status='success').inc()
            logger.info(
                f"Successfully fetched {len(self.cached_data['rates'])} exchange rates")

            return self.cached_data

        except requests.exceptions.RequestException as e:
            API_CALLS.labels(status='error').inc()
            logger.error(f"Error fetching exchange rates: {e}")

            # Return cached data if available, otherwise return error
            if self.cached_data:
                logger.info("API error - returning cached data")
                return self.cached_data

            return {"error": f"Unable to fetch exchange rates: {str(e)}"}

    def process_rates_data(self, raw_data):
        """Process and structure the exchange rates data."""
        if 'rates' not in raw_data:
            raise ValueError("Invalid API response: missing 'rates' field")

        rates = {}
        for currency, data in raw_data['rates'].items():
            rates[currency] = {
                'name': data.get('name', currency),
                'unit': data.get('unit', 'N/A'),
                'value': data.get('value', 0),
                'type': data.get('type', 'unknown')
            }

        # Sort by value (descending)
        sorted_rates = dict(sorted(rates.items(),
                                   key=lambda x: x[1]['value'],
                                   reverse=True))

        return {
            'rates': sorted_rates,
            'last_updated': datetime.now().isoformat(),
            'total_currencies': len(sorted_rates)
        }


# Initialize API client
crypto_api = CryptoRatesAPI()


@app.route('/')
def index():
    """Main page displaying cryptocurrency exchange rates."""
    REQUEST_COUNT.labels(method='GET', endpoint='/').inc()

    with REQUEST_LATENCY.time():
        data = crypto_api.get_exchange_rates()

        if 'error' in data:
            return render_template('error.html', error=data['error']), 500

        return render_template('index.html', data=data)


@app.route('/api/rates')
def api_rates():
    """API endpoint returning JSON exchange rates data."""
    REQUEST_COUNT.labels(method='GET', endpoint='/api/rates').inc()

    with REQUEST_LATENCY.time():
        data = crypto_api.get_exchange_rates()
        return jsonify(data)


@app.route('/health')
def health_check():
    """Health check endpoint for monitoring and load balancers."""
    REQUEST_COUNT.labels(method='GET', endpoint='/health').inc()

    try:
        # Quick API test
        test_data = crypto_api.get_exchange_rates()
        status = "healthy" if 'error' not in test_data else "degraded"

        return jsonify({
            'status': status,
            'timestamp': datetime.now().isoformat(),
            'version': os.getenv('APP_VERSION', '1.0.0')
        })
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint."""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return render_template('error.html', error="Page not found"), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    logger.error(f"Internal server error: {error}")
    return render_template('error.html', error="Internal server error"), 500


def main():
    """Main entry point for the application."""
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'

    logger.info(f"Starting Crypto Exchange Rates application on port {port}")
    logger.info(f"Debug mode: {debug}")

    app.run(
        host='0.0.0.0',
        port=port,
        debug=debug
    )


if __name__ == '__main__':
    main()
