# API-DOCUMENTATION

## Overview

The HeyCard Crypto Rates API provides real-time cryptocurrency exchange rates with intelligent caching, comprehensive monitoring, and enterprise-grade reliability.

**Base URL**: `http://<app-url>` or `https://<app-url>` (depending on deployment)  
**API Version**: v1.0.0  
**Data Source**: CoinGecko API  
**Update Frequency**: Every 5 minutes (with intelligent caching)

## Authentication

The API is publicly accessible for read operations. No authentication is required for standard endpoints.

## Endpoints

### 1. Health Check

**Endpoint**: `GET /health`  
**Description**: Application health status and system information  
**Cache**: No caching  
**Response Time**: < 100ms

**Response Example**:
```json
{
  "status": "healthy",
  "timestamp": "2025-09-04T22:06:28.971941Z",
  "version": "1.0.0",
  "uptime": "2h 15m 30s",
  "api_status": "connected"
}
```

**Response Codes**:
- `200 OK`: Application is healthy
- `503 Service Unavailable`: Application is unhealthy

### 2. Landing Page

**Endpoint**: `GET /`  
**Description**: Application information and navigation  
**Cache**: Static content (browser cache)  
**Response Type**: HTML

**Features**:
- Application overview
- API endpoint links
- Health status indicator
- Navigation menu

### 3. Exchange Rates API

**Endpoint**: `GET /api/rates`  
**Description**: Cryptocurrency exchange rates from Bitcoin to various currencies  
**Cache**: 5 minutes TTL with fallback  
**Response Time**: < 500ms (cached) / < 2s (fresh)

**Response Example**:
```json
{
  "last_updated": "2025-09-04T22:06:28.971941",
  "rates": {
    "aed": {
      "name": "United Arab Emirates Dirham",
      "type": "fiat",
      "unit": "DH",
      "value": 406058.307
    },
    "btc": {
      "name": "Bitcoin", 
      "type": "crypto",
      "unit": "BTC",
      "value": 1.0
    },
    "eth": {
      "name": "Ether",
      "type": "crypto", 
      "unit": "ETH",
      "value": 25.577
    },
    "usd": {
      "name": "US Dollar",
      "type": "fiat",
      "unit": "$",
      "value": 110567.272
    }
  },
  "total_currencies": 76,
  "data_source": "CoinGecko API",
  "cache_status": "cached"
}
```

**Response Fields**:
- `last_updated`: ISO 8601 timestamp of last data refresh
- `rates`: Object containing currency exchange rates
  - `name`: Full currency name
  - `type`: Currency type (`crypto`, `fiat`, `commodity`)
  - `unit`: Display unit symbol
  - `value`: Exchange rate relative to Bitcoin (BTC = 1.0)
- `total_currencies`: Total number of currencies returned
- `data_source`: External API source
- `cache_status`: Cache status (`cached`, `fresh`, `stale`)

**Currency Types**:
- **crypto**: Cryptocurrency (BTC, ETH, etc.)
- **fiat**: Government-issued currency (USD, EUR, etc.)
- **commodity**: Precious metals (Gold, Silver)

**Response Codes**:
- `200 OK`: Successful response with data
- `429 Too Many Requests`: Rate limiting active (returns cached data)
- `503 Service Unavailable`: External API unavailable (returns cached data if available)

### 4. Prometheus Metrics

**Endpoint**: `GET /metrics`  
**Description**: Application metrics in Prometheus format  
**Cache**: No caching  
**Response Type**: Plain text (Prometheus format)

**Available Metrics**:

#### Application Metrics
```prometheus
# HTTP request metrics
http_requests_total{method="GET", endpoint="/api/rates", status="200"} 1250
http_request_duration_seconds{method="GET", endpoint="/api/rates"} 0.245

# Cache metrics  
cache_hits_total{endpoint="/api/rates"} 892
cache_misses_total{endpoint="/api/rates"} 158
cache_size_bytes{cache="rates"} 15420

# API integration metrics
external_api_requests_total{provider="coingecko", status="success"} 145
external_api_requests_total{provider="coingecko", status="error"} 12
external_api_response_time_seconds{provider="coingecko"} 1.234
```

#### System Metrics
```prometheus
# Process metrics
process_cpu_seconds_total 45.23
process_resident_memory_bytes 157286400
process_open_fds 15

# Application info
app_info{version="1.0.0", python_version="3.11.0"} 1
```

## Rate Limiting and Caching

### Intelligent Caching Strategy

The application implements a sophisticated caching mechanism to optimize performance and handle rate limiting:

```python
# Cache Configuration
CACHE_DURATION = 300  # 5 minutes TTL
FALLBACK_DURATION = 3600  # 1 hour stale data retention
REFRESH_THRESHOLD = 60  # Refresh if cache age > 1 minute on miss
```

**Cache Behavior**:
1. **Fresh Data** (< 5 minutes old): Served directly from cache
2. **Stale Data** (5-60 minutes old): Attempt refresh, serve cached on failure  
3. **Expired Data** (> 60 minutes old): Force refresh, serve stale data on failure
4. **No Cache**: Fetch fresh data, handle rate limiting gracefully

### Rate Limiting Handling

**CoinGecko API Limits**:
- **Free Tier**: 10-30 requests per minute
- **Status Code**: 429 Too Many Requests
- **Response**: Rate limit information in headers

**Application Response to Rate Limiting**:
```json
{
  "last_updated": "2025-09-04T22:01:28.971941",
  "rates": { ... },
  "total_currencies": 76,
  "data_source": "CoinGecko API (cached)",
  "cache_status": "stale",
  "message": "Using cached data due to rate limiting"
}
```

## Error Handling

### Error Response Format

All error responses follow a consistent format:

```json
{
  "error": "Error description",
  "code": "ERROR_CODE",
  "timestamp": "2025-09-04T22:06:28.971941Z",
  "request_id": "req_123456789"
}
```

### Common Error Scenarios

#### 1. External API Unavailable
**Status Code**: `503 Service Unavailable`
```json
{
  "error": "External API temporarily unavailable",
  "code": "EXTERNAL_API_DOWN", 
  "fallback_data": true,
  "cache_age": "15 minutes"
}
```

#### 2. Rate Limiting Active
**Status Code**: `200 OK` (with cached data)
```json
{
  "message": "Rate limit exceeded, serving cached data",
  "cache_status": "stale",
  "retry_after": "45 seconds"
}
```

#### 3. Internal Server Error
**Status Code**: `500 Internal Server Error`
```json
{
  "error": "Internal server error",
  "code": "INTERNAL_ERROR",
  "request_id": "req_987654321"
}
```

#### 4. Service Unavailable
**Status Code**: `503 Service Unavailable`
```json
{
  "error": "Service temporarily unavailable",
  "code": "SERVICE_UNAVAILABLE", 
  "retry_after": "30 seconds"
}
```

## Performance Characteristics

### Response Times (95th percentile)
- **Health Check**: < 50ms
- **Cached Rates**: < 200ms  
- **Fresh Rates**: < 2000ms
- **Metrics**: < 100ms

### Throughput
- **Concurrent Requests**: Up to 100 RPS
- **Cache Hit Ratio**: > 80% under normal load
- **Memory Usage**: ~150MB per worker process

### Scalability
- **Horizontal Scaling**: 2-10 replicas via HPA
- **CPU-based Scaling**: Target 70% utilization  
- **Memory Limits**: 512Mi per pod
- **Connection Pooling**: HTTP/1.1 keep-alive enabled

## Usage Examples

### cURL Examples

#### Basic Health Check
```bash
curl -X GET http://localhost:8080/health \
  -H "Accept: application/json"
```

#### Get Exchange Rates
```bash
curl -X GET http://localhost:8080/api/rates \
  -H "Accept: application/json" \
  -H "User-Agent: HeyCard-Client/1.0"
```

#### Get Prometheus Metrics
```bash
curl -X GET http://localhost:8080/metrics \
  -H "Accept: text/plain"
```

### Python Examples

#### Using requests library
```python
import requests
import json

# Get exchange rates
response = requests.get('http://localhost:8080/api/rates')
data = response.json()

print(f"Last updated: {data['last_updated']}")
print(f"Bitcoin to USD: ${data['rates']['usd']['value']:,.2f}")
print(f"Total currencies: {data['total_currencies']}")

# Handle rate limiting
if data.get('cache_status') == 'stale':
    print("Warning: Using cached data due to rate limiting")
```

#### With error handling
```python
import requests
from requests.exceptions import RequestException

def get_crypto_rates():
    try:
        response = requests.get(
            'http://localhost:8080/api/rates',
            timeout=10,
            headers={'User-Agent': 'HeyCard-Client/1.0'}
        )
        response.raise_for_status()
        return response.json()
        
    except requests.exceptions.Timeout:
        print("Request timed out")
        return None
    except requests.exceptions.HTTPError as e:
        print(f"HTTP error: {e}")
        return None
    except RequestException as e:
        print(f"Request failed: {e}")
        return None

# Usage
rates_data = get_crypto_rates()
if rates_data:
    print(f"Retrieved {rates_data['total_currencies']} exchange rates")
```

### JavaScript Examples

#### Fetch API
```javascript
// Get exchange rates
async function getCryptoRates() {
  try {
    const response = await fetch('/api/rates', {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'HeyCard-WebClient/1.0'
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    
    // Display rates
    console.log(`Last updated: ${data.last_updated}`);
    console.log(`Bitcoin to USD: $${data.rates.usd.value.toLocaleString()}`);
    
    // Check cache status
    if (data.cache_status === 'stale') {
      console.warn('Using cached data due to rate limiting');
    }
    
    return data;
    
  } catch (error) {
    console.error('Failed to fetch rates:', error);
    return null;
  }
}

// Usage
getCryptoRates().then(data => {
  if (data) {
    displayRates(data.rates);
  }
});
```

## Monitoring and Observability

### Application Logs

**Log Format**: Structured JSON logging
```json
{
  "timestamp": "2025-09-04T22:06:28.971941Z",
  "level": "INFO",
  "logger": "main",
  "message": "Successfully fetched 76 exchange rates",
  "request_id": "req_123456789",
  "response_time_ms": 234,
  "cache_hit": true
}
```

**Log Levels**:
- `DEBUG`: Detailed debugging information
- `INFO`: General application flow
- `WARNING`: Potential issues or degraded performance  
- `ERROR`: Error conditions that don't stop the application
- `CRITICAL`: Serious errors that may cause the application to abort

### Health Monitoring

**Kubernetes Probes**:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health  
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Custom Health Checks**:
- Database connectivity (if applicable)
- External API reachability
- Memory usage thresholds
- Cache system health

## Security Considerations

### Input Validation
- All endpoint parameters are validated
- SQL injection prevention (if database used)
- XSS protection for HTML responses
- Rate limiting per IP address

### Security Headers
```http
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=63072000; includeSubDomains
```

### CORS Configuration
```python
# CORS settings for browser access
CORS_ORIGINS = [
    'https://heycard.com',
    'https://*.heycard.com',
    'http://localhost:3000'  # Development only
]
```

## API Versioning

**Current Version**: v1.0.0  
**Versioning Strategy**: URL-based versioning (future)

**Future Versioning**:
- `/api/v1/rates` - Current API
- `/api/v2/rates` - Future enhancements
- Backward compatibility maintained for 2 major versions

## Support and SLA

**Service Level Agreement**:
- **Uptime**: 99.9% availability target
- **Response Time**: < 2s for 95% of requests
- **Recovery Time**: < 5 minutes for service restoration

**Support Channels**:
- Technical Documentation: [docs/](./README.md)
- Issue Tracking: Project repository issues
- Emergency Contact: DevOps team

---

**📖 API Documentation Complete**

This API provides reliable, cached cryptocurrency exchange rates with enterprise-grade monitoring and error handling.